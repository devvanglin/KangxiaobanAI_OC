import { audio } from '@kit.AudioKit';
import { util } from '@kit.ArkTS';
import { webSocket } from '@kit.NetworkKit';
import AuthStore from './AuthStore';
import { ApiConfig } from './ApiConfig';
import Logger from '../util/Logger';

export interface AssessmentAgentEvent {
  type: string;
  index?: number;
  total?: number;
  topic?: string;
  question?: string;
  text?: string;
  content?: string;
  status?: string;
  audio_data?: string;
  sample_rate?: number;
  report?: string;
  record_id?: string;
  answered?: number;
  message?: string;
  turn_id?: string;
}

/**
 * Native bridge for one isolated assessment session. It streams 16 kHz mono
 * PCM to the authenticated Kangxiaoban proxy and plays the Float32 PCM chunks
 * returned by AsLive. Text input remains usable when microphone permission is
 * denied.
 */
export class AssessmentAgentClient {
  private socket: webSocket.WebSocket | null = null;
  private capturer: audio.AudioCapturer | null = null;
  private renderer: audio.AudioRenderer | null = null;
  private eventHandler: ((event: AssessmentAgentEvent) => void) | null = null;
  private closeHandler: (() => void) | null = null;
  private listening: boolean = false;
  private released: boolean = false;
  private playQueue: ArrayBuffer[] = [];
  private queueHeadOffset: number = 0;
  private playbackBytesQueued: number = 0;
  private playbackBytesDelivered: number = 0;
  private pendingDrainCycles: number = 0;
  private playbackDrainAckFired: boolean = false;
  private pendingPlaybackTurnId: string = '';
  private playbackAckInFlight: boolean = false;
  private readonly base64: util.Base64Helper = new util.Base64Helper();

  public connect(sessionKey: string, onEvent: (event: AssessmentAgentEvent) => void,
    onClose: () => void): Promise<void> {
    this.eventHandler = onEvent;
    this.closeHandler = onClose;
    this.released = false;
    this.socket = webSocket.createWebSocket();
    this.socket.on('message', (err: BusinessError, data: string | ArrayBuffer): void => {
      if (err || typeof data !== 'string') { return; }
      try {
        const event: AssessmentAgentEvent = JSON.parse(data) as AssessmentAgentEvent;
        if (event.type === 'audio' && event.audio_data !== undefined) {
          this.enqueueAudio(event.audio_data);
        } else if (event.type === 'await_playback' && event.turn_id !== undefined) {
          this.pendingPlaybackTurnId = event.turn_id;
          void this.acknowledgePlaybackWhenDrained();
        }
        this.eventHandler?.(event);
      } catch (_error) {
        Logger.warn('[AssessmentAgent]', 'ignored malformed event');
      }
    });
    this.socket.on('close', (): void => { this.closeHandler?.(); });
    this.socket.on('error', (err: BusinessError): void => {
      Logger.error('[AssessmentAgent]', `websocket error: ${JSON.stringify(err)}`);
    });
    const url: string = `${ApiConfig.ASSESSMENT_WS_BASE}/${encodeURIComponent(sessionKey)}/ws`;
    try {
      return this.socket.connect(url, { header: { Authorization: `Bearer ${AuthStore.getToken()}` } })
        .then((): void => {});
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      Logger.error('[AssessmentAgent]', `websocket connect failed: ${err.code} ${err.message}`);
      return Promise.reject(error);
    }
  }

  public sendText(text: string): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    try {
      return this.socket.send(JSON.stringify({ type: 'assessment_answer', text: text }));
    } catch (_error) {
      return Promise.resolve(false);
    }
  }

  public stopAssessment(): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    try {
      return this.socket.send(JSON.stringify({ type: 'assessment_stop' }));
    } catch (_error) {
      return Promise.resolve(false);
    }
  }

  private sendPlaybackComplete(turnId: string): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    try {
      return this.socket.send(JSON.stringify({ type: 'playback_complete', turn_id: turnId }));
    } catch (_error) {
      return Promise.resolve(false);
    }
  }

  public resumeMicrophone(): boolean {
    if (this.capturer === null || this.released) { return false; }
    this.listening = true;
    return true;
  }

  public async confirmCaptureReady(turnId: string): Promise<void> {
    if (this.socket === null) { return; }
    try {
      await this.socket.send(JSON.stringify({ type: 'capture_ready', turn_id: turnId }));
    } catch (_error) {
      Logger.warn('[AssessmentAgent]', 'send capture_ready failed');
    }
  }

  public async prepareMicrophone(): Promise<void> {
    if (this.capturer !== null || this.released) { return; }
    if (canIUse('SystemCapability.Multimedia.Audio.Capturer')) {
      if (canIUse('SystemCapability.Multimedia.Audio.Core')) {
        // @SuppressWarnings syscap 命名空间枚举访问按设备集检查，守卫字符串无法匹配成员解析
        const streamInfo: audio.AudioStreamInfo = {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        };
        // @SuppressWarnings syscap createAudioCapturer 命名空间站点
        this.capturer = await audio.createAudioCapturer({
          streamInfo: streamInfo,
          capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION, capturerFlags: 0 }
        });
        try {
          this.capturer.on('readData', (buffer: ArrayBuffer): void => {
            if (this.listening && this.socket !== null && buffer.byteLength > 0) {
              void this.socket.send(buffer);
            }
          });
        } catch (_error) {
          Logger.warn('[AssessmentAgent]', 'register readData failed');
        }
        await this.capturer.start();
        this.listening = false;
      }
    }
  }

  /** Keep the capturer warm between turns, but never upload PCM during TTS. */
  public pauseMicrophone(): void {
    this.listening = false;
  }

  public async stopMicrophone(): Promise<void> {
    this.listening = false;
    if (this.capturer === null) { return; }
    try { this.capturer.off('readData'); } catch (_error) {}
    try { await this.capturer.stop(); } catch (_error) {}
    try { await this.capturer.release(); } catch (_error) {}
    this.capturer = null;
  }

  private enqueueAudio(encoded: string): void {
    try {
      const decoded: Uint8Array = this.base64.decodeSync(encoded);
      const buffer: ArrayBuffer = decoded.buffer.slice(decoded.byteOffset, decoded.byteOffset + decoded.byteLength);
      this.playQueue.push(buffer);
      this.playbackBytesQueued += buffer.byteLength;
      this.playbackDrainAckFired = false;
      this.pendingDrainCycles = 0;
      void this.ensureRenderer().catch((_error: BusinessError): void => {
        Logger.warn('[AssessmentAgent]', 'audio renderer unavailable');
      });
    } catch (_error) {
      Logger.warn('[AssessmentAgent]', 'audio decode failed');
    }
  }

  private async ensureRenderer(): Promise<audio.AudioRenderer> {
    if (this.renderer !== null) { return this.renderer; }
    if (canIUse('SystemCapability.Multimedia.Audio.Renderer')) {
      if (canIUse('SystemCapability.Multimedia.Audio.Core')) {
        // @SuppressWarnings syscap createAudioRenderer 与流参数命名空间站点
        const renderer: audio.AudioRenderer = await audio.createAudioRenderer({
          streamInfo: {
            samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000,
            channels: audio.AudioChannel.CHANNEL_1,
            sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_F32LE,
            encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
          },
          rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION, rendererFlags: 0 }
        });
        try {
          // writeData 推送模式下渲染器持续运行：队列空时补静音，跨回合无缝衔接。
          renderer.on('writeData', (buffer: ArrayBuffer): void => {
            this.fillPlaybackBuffer(buffer);
          });
        } catch (_error) {
          try { await renderer.release(); } catch (_releaseError) {}
          throw new Error('注册音频回调失败');
        }
        this.renderer = renderer;
        await renderer.start();
        return renderer;
      }
    }
    throw new Error('当前设备不支持音频播放');
  }

  private fillPlaybackBuffer(buffer: ArrayBuffer): void {
    const view: Uint8Array = new Uint8Array(buffer);
    let filled: number = 0;
    while (filled < view.length && this.playQueue.length > 0) {
      const head: ArrayBuffer = this.playQueue[0];
      const copyLength: number = Math.min(head.byteLength - this.queueHeadOffset, view.length - filled);
      view.set(new Uint8Array(head, this.queueHeadOffset, copyLength), filled);
      filled += copyLength;
      this.queueHeadOffset += copyLength;
      this.playbackBytesDelivered += copyLength;
      if (this.queueHeadOffset >= head.byteLength) {
        this.playQueue.shift();
        this.queueHeadOffset = 0;
      }
    }
    if (filled < view.length) {
      view.fill(0, filled);
    }
    const allDelivered: boolean = this.playbackBytesQueued > 0 &&
      this.playbackBytesDelivered >= this.playbackBytesQueued && this.playQueue.length === 0;
    if (!allDelivered || this.playbackDrainAckFired) {
      return;
    }
    if (this.pendingDrainCycles > 0) {
      this.pendingDrainCycles -= 1;
      if (this.pendingDrainCycles === 0) {
        // 多等一个缓冲周期让已交给系统的数据播完；writeData 回调内禁止调用 AudioRenderer API。
        this.playbackDrainAckFired = true;
        setTimeout((): void => { void this.acknowledgePlaybackWhenDrained(); }, 0);
      }
    } else {
      this.pendingDrainCycles = 1;
    }
  }

  private async acknowledgePlaybackWhenDrained(): Promise<void> {
    if (this.playbackAckInFlight || this.pendingPlaybackTurnId.length === 0 ||
      this.playQueue.length > 0 || this.released ||
      this.playbackBytesDelivered < this.playbackBytesQueued) {
      return;
    }
    this.playbackAckInFlight = true;
    const turnId: string = this.pendingPlaybackTurnId;
    try {
      if (this.renderer !== null) {
        // writeData 模式下仍需 drain：等待已提交字节全部播完再确认，保持服务端半双工时序。
        await this.renderer.drain();
      }
      this.pendingPlaybackTurnId = '';
      await this.sendPlaybackComplete(turnId);
    } catch (_error) {
      Logger.error('[AssessmentAgent]', 'failed to drain/ack TTS playback');
    } finally {
      this.playbackAckInFlight = false;
    }
  }

  public async close(): Promise<void> {
    this.released = true;
    this.playQueue = [];
    this.queueHeadOffset = 0;
    this.playbackBytesQueued = 0;
    this.playbackBytesDelivered = 0;
    this.pendingDrainCycles = 0;
    this.playbackDrainAckFired = false;
    this.pendingPlaybackTurnId = '';
    await this.stopMicrophone();
    if (this.renderer !== null) {
      try { this.renderer.off('writeData'); } catch (_error) {}
      try { await this.renderer.stop(); } catch (_error) {}
      try { await this.renderer.release(); } catch (_error) {}
      this.renderer = null;
    }
    if (this.socket !== null) {
      try { await this.socket.close(); } catch (_error) {}
      this.socket = null;
    }
  }
}
