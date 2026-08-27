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

  /** 建立连接；onEvent 收到服务端下行事件。 */
  public connect(onEvent: (payload: string) => void): void {
    this.onEvent = onEvent;
    const url: string = `${ApiConfig.WS_URL}?token=${encodeURIComponent(AuthStore.getToken())}`;
    this.ws = webSocket.createWebSocket();
    this.ws.on('open', (err: BusinessError, data: Object) => {
      if (err) {
        Logger.error('[WS]', `open fail: ${JSON.stringify(err)}`);
        return;
      }
      Logger.info('[WS]', 'connected');
    });
    this.ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (err) {
        Logger.error('[WS]', `message error: ${JSON.stringify(err)}`);
        return;
      }
      if (this.onEvent && typeof data === 'string') {
        this.onEvent(data);
      }
    });
    this.ws.on('error', (err: BusinessError) => {
      Logger.error('[WS]', `error: ${JSON.stringify(err)}`);
    });
    this.ws.on('close', (err: BusinessError, data: Object) => {
      Logger.warn('[WS]', 'closed');
    });
    this.ws.connect(url, (err: BusinessError) => {
      if (err) {
        Logger.error('[WS]', `connect fail: ${JSON.stringify(err)}`);
      }
    });
  }

  /** 关闭连接并释放资源。 */
  public close(): void {
    if (this.ws) {
      this.ws.close((err: BusinessError) => {
        if (err) {
          Logger.warn('[WS]', `close fail: ${JSON.stringify(err)}`);
        }
      });
      this.ws = null;
    }
  }
}