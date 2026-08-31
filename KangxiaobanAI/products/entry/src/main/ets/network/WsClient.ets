/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { webSocket } from '@kit.NetworkKit';
import AuthStore from './AuthStore';
import { ApiConfig } from './ApiConfig';
import Logger from '../util/Logger';

/**
 * WebSocket 实时推送客户端。
 * 连接地址 /api/v1/ws?token=<jwt>，收到 {type,data} 事件后交给 onEvent 回调。
 */
export class WsClient {
  private ws: webSocket.WebSocket | null = null;
  private onEvent: ((payload: string) => void) | null = null;
  private reconnectTimerId: number = -1;
  private reconnectAttempt: number = 0;
  private socketGeneration: number = 0;
  private manuallyClosed: boolean = true;

  /** 建立连接；onEvent 收到服务端下行事件。 */
  public connect(onEvent: (payload: string) => void): void {
    this.close();
    this.onEvent = onEvent;
    this.manuallyClosed = false;
    this.reconnectAttempt = 0;
    try {
      this.openSocket();
    } catch (error) {
      // Keep a platform-specific synchronous failure from escaping the
      // page lifecycle (for example a malformed token or unavailable stack).
      Logger.error('[WS]', `open exception: ${error instanceof Error ? error.message : 'unknown'}`);
      this.safeScheduleReconnect();
    }
  }

  /** 关闭连接并释放资源。 */
  public close(): void {
    this.manuallyClosed = true;
    this.socketGeneration += 1;
    this.reconnectAttempt = 0;
    if (this.reconnectTimerId !== -1) {
      try {
        clearTimeout(this.reconnectTimerId);
      } catch (_error) {
        // Timer cleanup can fail while a page is being torn down.
      }
      this.reconnectTimerId = -1;
    }
    const socket: webSocket.WebSocket | null = this.ws;
    this.ws = null;
    if (socket) {
      try {
        socket.close((err: BusinessError) => {
          if (err) {
            Logger.warn('[WS]', `close fail: ${JSON.stringify(err)}`);
          }
        });
      } catch (error) {
        // close() can throw when the platform has already released the socket.
        Logger.warn('[WS]', `close exception: ${error instanceof Error ? error.message : 'unknown'}`);
      }
    }
  }

  private openSocket(): void {
    if (this.manuallyClosed || AuthStore.getToken().length === 0) {
      return;
    }
    const generation: number = ++this.socketGeneration;
    let socket: webSocket.WebSocket;
    try {
      socket = webSocket.createWebSocket();
    } catch (error) {
      Logger.error('[WS]', `create exception: ${error instanceof Error ? error.message : 'unknown'}`);
      this.safeScheduleReconnect();
      return;
    }
    this.ws = socket;
    const isCurrentSocket = (): boolean => this.socketGeneration === generation && this.ws === socket;
    const reconnectAfterFailure = (): void => {
      if (!isCurrentSocket()) {
        return;
      }
      this.ws = null;
      try {
        socket.close(() => {});
      } catch (_error) {
        // The socket may already be closed by the platform.
      }
      this.safeScheduleReconnect();
    };
    try {
      socket.on('open', (err: BusinessError, _data: Object) => {
        if (!isCurrentSocket()) {
          return;
        }
        if (err) {
          Logger.error('[WS]', `open fail: ${JSON.stringify(err)}`);
          reconnectAfterFailure();
          return;
        }
        this.reconnectAttempt = 0;
        Logger.info('[WS]', 'connected');
      });
      socket.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
        if (!isCurrentSocket()) {
          return;
        }
        if (err) {
          Logger.error('[WS]', `message error: ${JSON.stringify(err)}`);
          return;
        }
        if (this.onEvent && typeof data === 'string') {
          try {
            this.onEvent(data);
          } catch (error) {
            Logger.error('[WS]', `event handler exception: ${error instanceof Error ? error.message : 'unknown'}`);
          }
        }
      });
      socket.on('error', (err: BusinessError) => {
        if (!isCurrentSocket()) {
          return;
        }
        Logger.error('[WS]', `error: ${JSON.stringify(err)}`);
        reconnectAfterFailure();
      });
      socket.on('close', (_err: BusinessError, _data: Object) => {
        if (!isCurrentSocket()) {
          return;
        }
        this.ws = null;
        Logger.warn('[WS]', 'closed');
        this.safeScheduleReconnect();
      });
      const url: string = `${ApiConfig.WS_URL}?token=${encodeURIComponent(AuthStore.getToken())}`;
      socket.connect(url, (err: BusinessError) => {
        if (!isCurrentSocket()) {
          return;
        }
        if (err) {
          Logger.error('[WS]', `connect fail: ${JSON.stringify(err)}`);
          reconnectAfterFailure();
        }
      });
    } catch (error) {
      Logger.error('[WS]', `connect exception: ${error instanceof Error ? error.message : 'unknown'}`);
      reconnectAfterFailure();
    }
  }

  private scheduleReconnect(): void {
    if (this.manuallyClosed || this.reconnectTimerId !== -1 || AuthStore.getToken().length === 0) {
      return;
    }
    const exponent: number = Math.min(this.reconnectAttempt, 5);
    const delayMs: number = Math.min(30000, 1000 * Math.pow(2, exponent));
    this.reconnectAttempt += 1;
    this.reconnectTimerId = setTimeout((): void => {
      this.reconnectTimerId = -1;
      try {
        this.openSocket();
      } catch (error) {
        // Keep a failed reconnect attempt inside the retry state machine.
        Logger.error('[WS]', `reconnect exception: ${error instanceof Error ? error.message : 'unknown'}`);
        this.safeScheduleReconnect();
      }
    }, delayMs);
  }

  private safeScheduleReconnect(): void {
    try {
      this.scheduleReconnect();
    } catch (error) {
      // A timer/token failure must not escape an asynchronous socket callback.
      Logger.error('[WS]', `schedule reconnect exception: ${error instanceof Error ? error.message : 'unknown'}`);
    }
  }
}
