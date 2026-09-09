/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import AuthStore from './AuthStore';
import { ApiResp, Paged } from './Dto';
import { ApiConfig } from './ApiConfig';
import Logger from '../util/Logger';

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

function toRequestMethod(method: HttpMethod): http.RequestMethod {
  switch (method) {
    case 'POST':
      return http.RequestMethod.POST;
    case 'PUT':
      return http.RequestMethod.PUT;
    case 'PATCH':
      return http.RequestMethod.POST;
    case 'DELETE':
      return http.RequestMethod.DELETE;
    default:
      return http.RequestMethod.GET;
  }
}

interface SseFrame {
  event: string;
  text: string;
}

/**
 * REST 请求封装。
 * 自动携带 Authorization: Bearer <token>；code==401 时清除本地会话。
 */
export class ApiClient {
  // The NetworkKit timeout is not sufficient on every device/API build: a
  // request callback can remain pending after the transport has stalled.
  // Keep an application watchdog so a page can leave its loading state.
  private static readonly CONNECT_TIMEOUT_MS: number = 8000;
  private static readonly READ_TIMEOUT_MS: number = 10000;
  private static readonly REQUEST_TIMEOUT_MS: number = 12000;
  private static readonly MAX_NETWORK_RETRIES: number = 1;
  private static readonly RETRY_DELAYS_MS: number[] = [500];
  private static readonly MAX_PAGES: number = 50;
  private static readonly GET_ALL_TIMEOUT_MS: number = 30000;
  private static readonly DOWNLOAD_CONNECT_TIMEOUT_MS: number = 8000;
  private static readonly DOWNLOAD_READ_TIMEOUT_MS: number = 60000;
  private static readonly DOWNLOAD_WATCHDOG_MS: number = 120000;

  private static shouldRetry(method: HttpMethod, path: string): boolean {
    // GET is safe to repeat. Login has no business-side mutation, so it also
    // gets the same short transport retry window. Never repeat writes here.
    return method === 'GET' || (method === 'POST' && path === '/auth/login');
  }

  private static wait(delayMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), delayMs);
    });
  }

  private static requestOnce<T>(method: HttpMethod, path: string, body?: Object, timeoutMs?: number): Promise<ApiResp<T>> {
    const httpRequest = http.createHttp();
    const header: Record<string, string> = { 'Content-Type': 'application/json' };
    const token: string = AuthStore.getToken();
    if (token.length > 0) {
      header['Authorization'] = 'Bearer ' + token;
    }
    const watchdogMs: number = timeoutMs !== undefined && timeoutMs > 0 ? timeoutMs : ApiClient.REQUEST_TIMEOUT_MS;
    const options: http.HttpRequestOptions = {
      method: toRequestMethod(method),
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: ApiClient.CONNECT_TIMEOUT_MS,
      readTimeout: Math.max(ApiClient.READ_TIMEOUT_MS, watchdogMs)
    };
    if (method === 'PATCH') {
      options.customMethod = 'PATCH';
    }
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }
    return new Promise<ApiResp<T>>((resolve, reject) => {
      let settled: boolean = false;
      const timeoutId: number = setTimeout((): void => {
        if (settled) {
          return;
        }
        settled = true;
        try {
          httpRequest.destroy();
        } catch (_error) {
          // The request may already have been released by NetworkKit.
        }
        reject(new Error(`请求超时(${watchdogMs}ms)`));
      }, watchdogMs);
      const finishError = (error: Object): void => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timeoutId);
        try {
          httpRequest.destroy();
        } catch (_error) {
          // The request may already have been released by NetworkKit.
        }
        reject(error);
      };
      try {
        httpRequest.request(ApiConfig.API_BASE + path, options, (err: BusinessError, data: http.HttpResponse) => {
          if (err) {
            finishError(err);
            return;
          }
          if (settled) {
            return;
          }
          try {
            const rawResult: Object = data.result as Object;
            const resultText: string = typeof rawResult === 'string' ? rawResult : JSON.stringify(rawResult);
            const resp: ApiResp<T> = JSON.parse(resultText) as ApiResp<T>;
            if (typeof resp.code !== 'number') {
              throw new Error('响应格式无效');
            }
            if (resp.code >= 500) {
              throw new Error(`服务器暂时不可用(${resp.code})`);
            }
            if (resp.code === 401) {
              AuthStore.clear();
            }
            settled = true;
            clearTimeout(timeoutId);
            // NetworkKit normally accepts destroy after the callback, but a
            // device-side transport can still throw while releasing it. A
            // release failure must never turn an otherwise valid response
            // into a Promise that remains pending forever.
            try {
              httpRequest.destroy();
            } catch (_error) {
              Logger.warn('[ApiClient]', `${method} ${ApiClient.logPath(path)} destroy failed after response`);
            }
            resolve(resp);
          } catch (error) {
            finishError(error instanceof Error ? error : new Error('响应解析失败'));
          }
        });
      } catch (error) {
        finishError(error instanceof Error ? error : new Error('网络请求失败'));
      }
    });
  }

  private static async request<T>(method: HttpMethod, path: string, body?: Object, timeoutMs?: number): Promise<ApiResp<T>> {
    const retryable: boolean = ApiClient.shouldRetry(method, path);
    let retryIndex: number = 0;
    while (true) {
      try {
        return await ApiClient.requestOnce<T>(method, path, body, timeoutMs);
      } catch (error) {
        if (!retryable || retryIndex >= ApiClient.MAX_NETWORK_RETRIES) {
          const message: string = error instanceof Error ? error.message : '网络请求失败';
          Logger.warn('[ApiClient]', `${method} ${ApiClient.logPath(path)} failed: ${message}`);
          throw new Error(message);
        }
        await ApiClient.wait(ApiClient.RETRY_DELAYS_MS[retryIndex]);
        retryIndex += 1;
      }
    }
  }

  private static logPath(path: string): string {
    const queryIndex: number = path.indexOf('?');
    return queryIndex >= 0 ? path.slice(0, queryIndex) : path;
  }

  public static get<T>(path: string): Promise<ApiResp<T>> {
    return ApiClient.request<T>('GET', path);
  }

  /** 通用方法发送（供需要动态 method 的调用方使用，如知识库代理）。 */
  public static send<T>(method: HttpMethod, path: string, body?: Object): Promise<ApiResp<T>> {
    return ApiClient.request<T>(method, path, body);
  }

  /** 读取服务端分页资源的全部记录，避免首屏固定 size 截断业务关系。 */
  public static async getAll<T>(path: string, pageSize: number = 200): Promise<ApiResp<Paged<T>>> {
    const safePageSize: number = pageSize > 0 && pageSize <= 200 ? pageSize : 200;
    const items: T[] = [];
    const startedAt: number = Date.now();
    let page: number = 1;
    let total: number = -1;
    let previousItemCount: number = -1;
    while (page <= ApiClient.MAX_PAGES) {
      if (Date.now() - startedAt >= ApiClient.GET_ALL_TIMEOUT_MS) {
        Logger.warn('[ApiClient]', `分页请求超过时间上限: ${ApiClient.logPath(path)}`);
        return {
          code: 504,
          msg: '分页请求超时，请稍后重试',
          data: { list: items, page: 1, size: items.length, total: items.length }
        };
      }
      const separator: string = path.indexOf('?') >= 0 ? '&' : '?';
      const response: ApiResp<Paged<T>> = await ApiClient.get<Paged<T>>(
        `${path}${separator}page=${page}&size=${safePageSize}`);
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        return response;
      }
      const batch: T[] = response.data.list ?? [];
      items.push(...batch);
      if (Date.now() - startedAt >= ApiClient.GET_ALL_TIMEOUT_MS) {
        Logger.warn('[ApiClient]', `分页请求超过时间上限: ${ApiClient.logPath(path)}`);
        return {
          code: 504,
          msg: '分页请求超时，请稍后重试',
          data: { list: items, page: 1, size: items.length, total: items.length }
        };
      }
      const reportedTotal: number = Number(response.data.total);
      if (Number.isFinite(reportedTotal) && reportedTotal >= 0) {
        total = reportedTotal;
      }
      if (batch.length === 0 || (total >= 0 && items.length >= total) || batch.length < safePageSize ||
        items.length <= previousItemCount) {
        break;
      }
      previousItemCount = items.length;
      page++;
    }
    if (page > ApiClient.MAX_PAGES) {
      Logger.warn('[ApiClient]', `分页超过安全上限: ${ApiClient.logPath(path)}`);
      return {
        code: 500,
        msg: '分页响应超过安全上限',
        data: { list: items, page: 1, size: items.length, total: items.length }
      };
    }
    return {
      code: 0,
      msg: '',
      data: { list: items, page: 1, size: items.length, total: Math.max(total, items.length) }
    };
  }

  public static post<T>(path: string, body?: Object, timeoutMs?: number): Promise<ApiResp<T>> {
    return ApiClient.request<T>('POST', path, body, timeoutMs);
  }

  /**
   * SSE 流式 POST：每个完整事件通过 onEvent(event, text) 实时下发；
   * Promise 以 done 事件的原始 JSON 文本收尾（由调用方解析最终响应体）。
   */
  public static postSSE(path: string, body: Object, onEvent: (event: string, text: string) => void,
    timeoutMs: number = 190000): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const httpRequest = http.createHttp();
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      let buffer: string = '';
      let lastDone: string = '';
      let settled: boolean = false;
      let receivedAny: boolean = false;
      const watchdog: number = setTimeout(() => {
        finishError(`请求超时(${timeoutMs}ms)`);
      }, timeoutMs + 5000);
      const finishOk = (): void => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(watchdog);
        try {
          httpRequest.destroy();
        } catch (_error) {
        }
        resolve(lastDone);
      };
      const finishError = (message: string): void => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(watchdog);
        Logger.error('[ApiClient]', `postSSE error: ${message}`);
        try {
          httpRequest.destroy();
        } catch (_error) {
        }
        reject(new Error(message));
      };
      const processChunk = (chunk: ArrayBuffer): void => {
        receivedAny = true;
        buffer += decoder.decodeToString(new Uint8Array(chunk));
        let separator: number = buffer.indexOf('\n\n');
        while (separator >= 0) {
          const rawEvent: string = buffer.substring(0, separator);
          buffer = buffer.substring(separator + 2);
          const dataLines: string[] = rawEvent.split('\n')
            .filter((line: string): boolean => line.startsWith('data:'));
          if (dataLines.length > 0) {
            const data: string = dataLines.map((line: string): string => line.substring(5).trimStart()).join('');
            try {
              const frame: SseFrame = JSON.parse(data) as SseFrame;
              if (frame.event === 'done') {
                lastDone = data;
              }
              if (frame.event === 'error') {
                finishError(frame.text.length > 0 ? frame.text : 'AI 服务暂不可用');
                return;
              }
              onEvent(frame.event, frame.text);
            } catch (_error) {
              // 跳过无法解析的帧
            }
          }
          separator = buffer.indexOf('\n\n');
        }
      };
      // 部分版本回调为 AsyncCallback（err 在前），部分为数据在前；两者都兼容。
      httpRequest.on('dataReceive', (first: ArrayBuffer | BusinessError, second?: ArrayBuffer) => {
        const chunk: ArrayBuffer | undefined = second !== undefined && second !== null ? second : first as ArrayBuffer;
        if (chunk !== undefined && chunk !== null && chunk.byteLength > 0) {
          processChunk(chunk);
        }
      });
      httpRequest.on('dataEnd', () => {
        finishOk();
      });
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream'
      };
      const token: string = AuthStore.getToken();
      if (token.length > 0) {
        header['Authorization'] = 'Bearer ' + token;
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: ApiClient.CONNECT_TIMEOUT_MS,
        readTimeout: timeoutMs
      };
      httpRequest.requestInStream(ApiConfig.API_BASE + path, options, (err: BusinessError) => {
        // SSE 由服务端主动关流，此处可能带 err；只要收到过数据就按成功收尾
        if (err && !settled && !receivedAny) {
          finishError('网络连接失败');
        }
        finishOk();
      });
    });
  }

  /** Upload one file as a multipart form field while retaining auth headers. */
  public static uploadBinary<T>(path: string, data: ArrayBuffer, contentType: string,
    extraHeaders: Record<string, string> = {}, fileName: string = 'admission-photo',
    dataJson: string = ''): Promise<ApiResp<T>> {
    const httpRequest = http.createHttp();
    const boundary: string = `----KXBAdmissionPhoto${Date.now()}`;
    const encoder = new util.TextEncoder('utf-8');
    let prefixText: string = `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${fileName}"\r\n` +
      `Content-Type: ${contentType}\r\n\r\n`;
    if (dataJson.length > 0) {
      prefixText = `--${boundary}\r\nContent-Disposition: form-data; name="data"\r\n\r\n${dataJson}\r\n` + prefixText;
    }
    const prefix: Uint8Array = encoder.encodeInto(prefixText);
    const suffix: Uint8Array = encoder.encodeInto(`\r\n--${boundary}--\r\n`);
    const bytes: Uint8Array = new Uint8Array(prefix.length + data.byteLength + suffix.length);
    bytes.set(prefix, 0);
    bytes.set(new Uint8Array(data), prefix.length);
    bytes.set(suffix, prefix.length + data.byteLength);
    const header: Record<string, string> = { 'Content-Type': `multipart/form-data; boundary=${boundary}` };
    Object.keys(extraHeaders).forEach((key: string): void => {
      header[key] = extraHeaders[key];
    });
    const token: string = AuthStore.getToken();
    if (token.length > 0) {
      header['Authorization'] = 'Bearer ' + token;
    }
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: ApiClient.CONNECT_TIMEOUT_MS,
      readTimeout: ApiClient.READ_TIMEOUT_MS,
      extraData: bytes.buffer as ArrayBuffer
    };
    return new Promise<ApiResp<T>>((resolve, reject) => {
      let settled: boolean = false;
      const timeoutId: number = setTimeout(() => {
        if (settled) {
          return;
        }
        settled = true;
        try {
          httpRequest.destroy();
        } catch (_error) {
          // Ignore release failures after a watchdog timeout.
        }
        reject(new Error(`上传超时(${ApiClient.REQUEST_TIMEOUT_MS}ms)`));
      }, ApiClient.REQUEST_TIMEOUT_MS);
      const finishError = (error: Object): void => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timeoutId);
        try {
          httpRequest.destroy();
        } catch (_error) {
          // Ignore release failures while completing an error path.
        }
        reject(error);
      };
      try {
        httpRequest.request(ApiConfig.API_BASE + path, options, (err: BusinessError, response: http.HttpResponse) => {
          if (err) {
            finishError(err);
            return;
          }
          if (settled) {
            return;
          }
          try {
            const rawResult: Object = response.result as Object;
            const resultText: string = typeof rawResult === 'string' ? rawResult : JSON.stringify(rawResult);
            const payload: ApiResp<T> = JSON.parse(resultText) as ApiResp<T>;
            if (typeof payload.code !== 'number') {
              throw new Error('响应格式无效');
            }
            if (payload.code === 401) {
              AuthStore.clear();
            }
            settled = true;
            clearTimeout(timeoutId);
            try {
              httpRequest.destroy();
            } catch (_error) {
              Logger.warn('[ApiClient]', `POST ${ApiClient.logPath(path)} destroy failed after upload response`);
            }
            resolve(payload);
          } catch (error) {
            finishError(error instanceof Error ? error : new Error('上传响应解析失败'));
          }
        });
      } catch (error) {
        finishError(error instanceof Error ? error : new Error('上传请求失败'));
      }
    });
  }

  /**
   * downloadBinary 的鉴权版本：下载需要登录的私有文件（如入住病例内容），
   * 路径与 request() 一样基于 API_BASE 拼接并注入 Bearer 令牌。
   */
  public static downloadBinaryAuthorized(path: string): Promise<ArrayBuffer> {
    const token: string = AuthStore.getToken();
    const header: Record<string, string> = {};
    if (token.length > 0) {
      header['Authorization'] = 'Bearer ' + token;
    }
    return ApiClient.downloadStream(ApiConfig.API_BASE + path, header);
  }

  /**
   * 流式下载一个可直接访问的 URL（如知识库签名下载地址）的完整字节。
   * 走 requestInStream 以绕开 request 的响应体大小上限；URL 自带鉴权签名，
   * 不注入后端令牌。传输失败、非 2xx 或超时都以 Error 拒绝。
   */
  public static downloadBinary(url: string): Promise<ArrayBuffer> {
    return ApiClient.downloadStream(url, {});
  }

  private static downloadStream(url: string, header: Record<string, string>): Promise<ArrayBuffer> {
    return new Promise<ArrayBuffer>((resolve: (value: ArrayBuffer) => void, reject: (reason: Error) => void) => {
      const httpRequest = http.createHttp();
      const chunks: ArrayBuffer[] = [];
      let settled: boolean = false;
      let watchdogId: number = -1;

      const finishError = (message: string): void => {
        if (settled) { return; }
        settled = true;
        clearTimeout(watchdogId);
        try {
          httpRequest.destroy();
        } catch (_error) {
          // destroy 在回调或事件路径中可能已被 SDK 释放。
        }
        Logger.warn('[ApiClient]', `downloadBinary failed: ${message}`);
        reject(new Error(message));
      };
      const finishOk = (): void => {
        if (settled) { return; }
        settled = true;
        clearTimeout(watchdogId);
        try {
          httpRequest.destroy();
        } catch (_error) {
          // ignore
        }
        let total: number = 0;
        chunks.forEach((chunk: ArrayBuffer): void => {
          total += chunk.byteLength;
        });
        const merged: ArrayBuffer = new ArrayBuffer(total);
        const view: Uint8Array = new Uint8Array(merged);
        let offset: number = 0;
        chunks.forEach((chunk: ArrayBuffer): void => {
          view.set(new Uint8Array(chunk), offset);
          offset += chunk.byteLength;
        });
        resolve(merged);
      };

      watchdogId = setTimeout((): void => {
        finishError(`下载超时(${ApiClient.DOWNLOAD_WATCHDOG_MS}ms)`);
      }, ApiClient.DOWNLOAD_WATCHDOG_MS);

      httpRequest.on('dataReceive', (data: ArrayBuffer): void => {
        chunks.push(data);
      });
      httpRequest.on('dataEnd', (): void => {
        finishOk();
      });

      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: ApiClient.DOWNLOAD_CONNECT_TIMEOUT_MS,
        readTimeout: ApiClient.DOWNLOAD_READ_TIMEOUT_MS
      };
      try {
        httpRequest.requestInStream(url, options, (err: BusinessError, responseCode: number) => {
          if (err) {
            finishError(err.message && err.message.length > 0 ? err.message : '网络请求失败');
            return;
          }
          if (responseCode < 200 || responseCode >= 300) {
            finishError(`下载失败(HTTP ${responseCode})`);
          }
        });
      } catch (error) {
        finishError(error instanceof Error ? error.message : '下载请求失败');
      }
    });
  }

  public static patch<T>(path: string, body?: Object): Promise<ApiResp<T>> {
    return ApiClient.request<T>('PATCH', path, body);
  }

  public static put<T>(path: string, body?: Object): Promise<ApiResp<T>> {
    return ApiClient.request<T>('PUT', path, body);
  }

  public static delete<T>(path: string): Promise<ApiResp<T>> {
    return ApiClient.request<T>('DELETE', path);
  }
}

export default ApiClient;
