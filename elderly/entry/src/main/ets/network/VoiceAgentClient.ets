import { audio } from '@kit.AudioKit';
import { util } from '@kit.ArkTS';
import { webSocket } from '@kit.NetworkKit';
import Logger from '../util/Logger';

/** AsLive /ws 普通聊天事件（服务端 JSON 事件 + 本地合成事件）。 */
export interface VoiceAgentEvent {
  type: string;
  /** asr 增量文本 / audio 分段对应文本。 */
  text?: string;
  /** text 流式回复增量。 */
  content?: string;
  /** base64 编码的 Float32 PCM 音频。 */
  audio_data?: string;
  sample_rate?: number;
  /** end 事件携带的完整回复。 */
  full_response?: string;
  turn_id?: string;
  message?: string;
}

/**
 * 老人端全双工语音聊天桥：16 kHz 单声道 PCM 持续上传，服务端负责 VAD、
 * 打断与 ASR；TTS 返回 Float32 PCM 分段排队播放。与医师端评估客户端的
 * 关键差异：无需评估握手（await_playback / capture_ready），且支持随时
 * 插话——收到 interrupt 时立即丢弃未播队列并冲刷渲染器。
 */
export class VoiceAgentClient {
  private socket: webSocket.WebSocket | null = null;
  private capturer: audio.AudioCapturer | null = null;
  private renderer: audio.AudioRenderer | null = null;
  private rendererRate: audio.AudioSamplingRate = audio.AudioSamplingRate.SAMPLE_RATE_24000;
  private eventHandler: ((event: VoiceAgentEvent) => void) | null = null;
  private closeHandler: (() => void) | null = null;
  private listening: boolean = false;
  private released: boolean = false;
  private playQueue: ArrayBuffer[] = [];
  private playing: boolean = false;
  /** 打断代际计数：interrupt 冲刷后旧写入循环全部作废。 */
  private playEpoch: number = 0;
  private readonly base64: util.Base64Helper = new util.Base64Helper();

  public connect(url: string, onEvent: (event: VoiceAgentEvent) => void, onClose: () => void): Promise<void> {
    this.eventHandler = onEvent;
    this.closeHandler = onClose;
    this.released = false;
    this.socket = webSocket.createWebSocket();
    this.socket.on('message', (err: BusinessError, data: string | ArrayBuffer): void => {
      if (err || typeof data !== 'string') { return; }
      try {
        const event: VoiceAgentEvent = JSON.parse(data) as VoiceAgentEvent;
        if (event.type === 'audio' && event.audio_data !== undefined) {
          this.enqueueAudio(event.audio_data, event.sample_rate);
        } else if (event.type === 'interrupt') {
          this.flushPlayback();
        }
        this.eventHandler?.(event);
      } catch (_error) {
        Logger.warn('[VoiceAgent]', 'ignored malformed event');
      }
    });
    this.socket.on('close', (): void => { this.closeHandler?.(); });
    this.socket.on('error', (err: BusinessError): void => {
      Logger.error('[VoiceAgent]', `websocket error: ${JSON.stringify(err)}`);
    });
    return this.socket.connect(url, {}).then((): void => {});
  }

  /** 重置服务端会话状态（进入页面或手动重连时调用）。 */
  public sendReset(): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    return this.socket.send(JSON.stringify({ type: 'control', action: 'start' }));
  }

  /** 文字兜底聊天（麦克风不可用或补录时）。 */
  public sendChat(text: string): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    return this.socket.send(JSON.stringify({ type: 'chat', text: text }));
  }

  /** 告知服务端当前陪伴对象的姓名/性别/年龄，由服务端生成称呼并注入人设。 */
  public sendSetElder(name: string, gender: string, age: number): Promise<boolean> {
    if (this.socket === null) { return Promise.resolve(false); }
    return this.socket.send(JSON.stringify({ type: 'set_elder', name: name, gender: gender, age: age }));
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
    // 保持 capturer 预热但不上传，由页面按对话阶段 resume/pause：
    // 播报与思考期间必须静默，否则扬声器声音被回采触发服务端打断。
    this.listening = false;
  }

  public pauseMicrophone(): void {
    this.listening = false;
  }

  /** 是否仍有音频在播放或排队（页面判断播报是否真正结束）。 */
  public isPlaying(): boolean {
    return this.playing || this.playQueue.length > 0;
  }

  public resumeMicrophone(): boolean {
    if (this.capturer === null || this.released) { return false; }
    this.listening = true;
    return true;
  }

  public async stopMicrophone(): Promise<void> {
    this.listening = false;
    if (this.capturer === null) { return; }
    try { this.capturer.off('readData'); } catch (_error) {}
    try { await this.capturer.stop(); } catch (_error) {}
    try { await this.capturer.release(); } catch (_error) {}
    this.capturer = null;
  }

  /** 立即静音：清空未播队列并作废正在进行的写入循环。 */
  private flushPlayback(): void {
    this.playQueue = [];
    this.playing = false;
    this.playEpoch++;
    const stale: audio.AudioRenderer | null = this.renderer;
    this.renderer = null;
    if (stale !== null) {
      stale.stop().then(async (): Promise<void> => {
        await stale.release();
      }).catch((): void => {});
    }
  }

  private enqueueAudio(encoded: string, sampleRate: number | undefined): void {
    try {
      const decoded: Uint8Array = this.base64.decodeSync(encoded);
      this.playQueue.push(decoded.buffer.slice(decoded.byteOffset, decoded.byteOffset + decoded.byteLength));
      this.pendingRate(sampleRate);
      if (!this.playing) { this.playNext(this.playEpoch).catch((): void => {}); }
    } catch (_error) {
      Logger.warn('[VoiceAgent]', 'audio decode failed');
    }
  }

  private pendingRate(sampleRate: number | undefined): void {
    if (sampleRate === undefined) { return; }
    const rate: audio.AudioSamplingRate = VoiceAgentClient.mapRate(sampleRate);
    if (this.renderer !== null && this.rendererRate !== rate) {
      // 采样率变化：丢弃旧渲染器，按新采样率重建。
      const stale: audio.AudioRenderer = this.renderer;
      this.renderer = null;
      stale.stop().then(async (): Promise<void> => {
        await stale.release();
      }).catch((): void => {});
    }
    this.rendererRate = rate;
  }

  private static mapRate(sampleRate: number): audio.AudioSamplingRate {
    if (sampleRate === 16000) { return audio.AudioSamplingRate.SAMPLE_RATE_16000; }
    if (sampleRate === 48000) { return audio.AudioSamplingRate.SAMPLE_RATE_48000; }
    if (sampleRate === 32000) { return audio.AudioSamplingRate.SAMPLE_RATE_32000; }
    if (sampleRate === 22050) { return audio.AudioSamplingRate.SAMPLE_RATE_22050; }
    return audio.AudioSamplingRate.SAMPLE_RATE_24000;
  }

  private async ensureRenderer(): Promise<audio.AudioRenderer> {
    if (this.renderer !== null) { return this.renderer; }
    this.renderer = await audio.createAudioRenderer({
      streamInfo: {
        samplingRate: this.rendererRate,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_F32LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION, rendererFlags: 0 }
    });
    await this.renderer.start();
    return this.renderer;
  }

  private async playNext(epoch: number): Promise<void> {
    if (epoch !== this.playEpoch) { return; }
    if (this.playQueue.length === 0 || this.released) {
      this.playing = false;
      if (epoch === this.playEpoch && !this.released) {
        // 本地合成事件：一段回复的音频已全部播完，页面据此回到聆听态。
        this.eventHandler?.({ type: 'playback_drained' });
      }
      return;
    }
    this.playing = true;
    const renderer: audio.AudioRenderer = await this.ensureRenderer();
    const buffer: ArrayBuffer | undefined = this.playQueue.shift();
    if (buffer !== undefined) {
      let offset: number = 0;
      while (offset < buffer.byteLength) {
        if (epoch !== this.playEpoch || this.released) { return; }
        const written: number = await renderer.write(buffer.slice(offset));
        if (written <= 0) {
          Logger.error('[VoiceAgent]', 'audio renderer write failed');
          return;
        }
        offset += written;
      }
    }
    await this.playNext(epoch);
  }

  public async close(): Promise<void> {
    this.released = true;
    this.playQueue = [];
    await this.stopMicrophone();
    this.flushPlayback();
    if (this.socket !== null) {
      try { await this.socket.close(); } catch (_error) {}
      this.socket = null;
    }
  }
}
