/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { http } from '@kit.NetworkKit';
import AuthStore from './AuthStore';
import { ApiResp, Paged } from './Dto';
import { ApiConfig } from './ApiConfig';
import Logger from '../util/Logger';

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

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

  private static requestOnce<T>(method: HttpMethod, path: string, body?: Object): Promise<ApiResp<T>> {
    const httpRequest = http.createHttp();
    const header: Record<string, string> = { 'Content-Type': 'application/json' };
    const token: string = AuthStore.getToken();
    if (token.length > 0) {
      header['Authorization'] = 'Bearer ' + token;
    }
    const options: http.HttpRequestOptions = {
      method: toRequestMethod(method),
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: ApiClient.CONNECT_TIMEOUT_MS,
      readTimeout: ApiClient.READ_TIMEOUT_MS
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
        reject(new Error(`请求超时(${ApiClient.REQUEST_TIMEOUT_MS}ms)`));
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

  private static async request<T>(method: HttpMethod, path: string, body?: Object): Promise<ApiResp<T>> {
    const retryable: boolean = ApiClient.shouldRetry(method, path);
    let retryIndex: number = 0;
    while (true) {
      try {
        return await ApiClient.requestOnce<T>(method, path, body);
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

  public static post<T>(path: string, body?: Object): Promise<ApiResp<T>> {
    return ApiClient.request<T>('POST', path, body);
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
