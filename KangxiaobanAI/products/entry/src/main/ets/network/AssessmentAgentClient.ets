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
  private playing: boolean = false;
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
    return this.socket.connect(url, { header: { Authorization: `Bearer ${AuthStore.getToken()}` } })
      .then((): void => {});
  }

  public sendText(text: string): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    return this.socket.send(JSON.stringify({ type: 'assessment_answer', text: text }));
  }

  public stopAssessment(): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    return this.socket.send(JSON.stringify({ type: 'assessment_stop' }));
  }

  private sendPlaybackComplete(turnId: string): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    return this.socket.send(JSON.stringify({ type: 'playback_complete', turn_id: turnId }));
  }

  public resumeMicrophone(): boolean {
    if (this.capturer === null || this.released) { return false; }
    this.listening = true;
    return true;
  }

  public async confirmCaptureReady(turnId: string): Promise<void> {
    if (this.socket !== null) {
      await this.socket.send(JSON.stringify({ type: 'capture_ready', turn_id: turnId }));
    }
  }

  public async prepareMicrophone(): Promise<void> {
    if (this.capturer !== null || this.released) { return; }
    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };
    this.capturer = await audio.createAudioCapturer({
      streamInfo: streamInfo,
      capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION, capturerFlags: 0 }
    });
    this.capturer.on('readData', (buffer: ArrayBuffer): void => {
      if (this.listening && this.socket !== null && buffer.byteLength > 0) {
        void this.socket.send(buffer);
      }
    });
    await this.capturer.start();
    this.listening = false;
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
      this.playQueue.push(decoded.buffer.slice(decoded.byteOffset, decoded.byteOffset + decoded.byteLength));
      if (!this.playing) { void this.playNext(); }
    } catch (_error) {
      Logger.warn('[AssessmentAgent]', 'audio decode failed');
    }
  }

  private async ensureRenderer(): Promise<audio.AudioRenderer> {
    if (this.renderer !== null) { return this.renderer; }
    this.renderer = await audio.createAudioRenderer({
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_F32LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION, rendererFlags: 0 }
    });
    await this.renderer.start();
    return this.renderer;
  }

  private async playNext(): Promise<void> {
    if (this.playQueue.length === 0 || this.released) {
      this.playing = false;
      await this.acknowledgePlaybackWhenDrained();
      return;
    }
    this.playing = true;
    const renderer: audio.AudioRenderer = await this.ensureRenderer();
    const buffer: ArrayBuffer | undefined = this.playQueue.shift();
    if (buffer !== undefined) {
      let offset: number = 0;
      while (offset < buffer.byteLength) {
        const written: number = await renderer.write(buffer.slice(offset));
        if (written <= 0) {
          throw new Error('音频播放缓冲写入失败');
        }
        offset += written;
      }
    }
    await this.playNext();
  }

  private async acknowledgePlaybackWhenDrained(): Promise<void> {
    if (this.playbackAckInFlight || this.pendingPlaybackTurnId.length === 0 ||
      this.playing || this.playQueue.length > 0 || this.released) {
      return;
    }
    this.playbackAckInFlight = true;
    const turnId: string = this.pendingPlaybackTurnId;
    try {
      if (this.renderer !== null) {
        await this.renderer.drain();
      }
      if (turnId === this.pendingPlaybackTurnId && !this.playing && this.playQueue.length === 0) {
        this.pendingPlaybackTurnId = '';
        await this.sendPlaybackComplete(turnId);
      }
    } catch (_error) {
      Logger.error('[AssessmentAgent]', 'failed to drain TTS playback');
    } finally {
      this.playbackAckInFlight = false;
    }
  }

  public async close(): Promise<void> {
    this.released = true;
    this.playQueue = [];
    this.pendingPlaybackTurnId = '';
    await this.stopMicrophone();
    if (this.renderer !== null) {
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
