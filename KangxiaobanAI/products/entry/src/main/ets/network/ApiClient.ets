/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { http } from '@kit.NetworkKit';
import AuthStore from './AuthStore';
import { ApiResp, Paged } from './Dto';
import { ApiConfig } from './ApiConfig';

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
  private static readonly MAX_NETWORK_RETRIES: number = 2;
  private static readonly RETRY_DELAYS_MS: number[] = [250, 750];

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
      connectTimeout: 10000,
      readTimeout: 10000
    };
    if (method === 'PATCH') {
      options.customMethod = 'PATCH';
    }
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }
    return new Promise<ApiResp<T>>((resolve, reject) => {
      httpRequest.request(ApiConfig.API_BASE + path, options, (err: BusinessError, data: http.HttpResponse) => {
        httpRequest.destroy();
        if (err) {
          reject(err);
          return;
        }
        try {
          const resp = JSON.parse(data.result as string) as ApiResp<T>;
          if (resp.code >= 500) {
            throw new Error(`服务器暂时不可用(${resp.code})`);
          }
          if (resp.code === 401) {
            AuthStore.clear();
          }
          resolve(resp);
        } catch {
          reject(new Error('响应解析失败'));
        }
      });
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
          throw new Error(error instanceof Error ? error.message : '网络请求失败');
        }
        await ApiClient.wait(ApiClient.RETRY_DELAYS_MS[retryIndex]);
        retryIndex += 1;
      }
    }
  }

  public static get<T>(path: string): Promise<ApiResp<T>> {
    return ApiClient.request<T>('GET', path);
  }

  /** 读取服务端分页资源的全部记录，避免首屏固定 size 截断业务关系。 */
  public static async getAll<T>(path: string, pageSize: number = 200): Promise<ApiResp<Paged<T>>> {
    const items: T[] = [];
    let page: number = 1;
    let total: number = 0;
    while (page <= 1000) {
      const separator: string = path.indexOf('?') >= 0 ? '&' : '?';
      const response: ApiResp<Paged<T>> = await ApiClient.get<Paged<T>>(
        `${path}${separator}page=${page}&size=${pageSize}`);
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        return response;
      }
      const batch: T[] = response.data.list ?? [];
      items.push(...batch);
      total = response.data.total;
      if (batch.length === 0 || items.length >= total || batch.length < pageSize) {
        break;
      }
      page++;
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
