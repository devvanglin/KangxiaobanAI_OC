import { webSocket } from '@kit.NetworkKit';
import AuthStore from './AuthStore';
import { ApiConfig } from './ApiConfig';

/** WebSocket 实时推送客户端。 */
export class WsClient {
  private ws: webSocket.WebSocket | null = null;
  private onEvent: ((payload: string) => void) | null = null;

  public connect(onEvent: (payload: string) => void): void {
    this.onEvent = onEvent;
    const url: string = `${ApiConfig.WS_URL}?token=${encodeURIComponent(AuthStore.getToken())}`;
    this.ws = webSocket.createWebSocket();
    this.ws.on('open', (_err: BusinessError, _data: Object) => {});
    this.ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (err || !this.onEvent || typeof data !== 'string') {
        return;
      }
      this.onEvent(data);
    });
    this.ws.connect(url, (_err: BusinessError) => {});
  }

  public close(): void {
    if (this.ws) {
      this.ws.close((_err: BusinessError) => {});
      this.ws = null;
    }
  }
}