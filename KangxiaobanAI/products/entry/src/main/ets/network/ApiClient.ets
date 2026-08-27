/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { http } from '@kit.NetworkKit';
import AuthStore from './AuthStore';
import { ApiResp } from './Dto';
import { ApiConfig } from './ApiConfig';

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

function toRequestMethod(method: HttpMethod): http.RequestMethod {
  switch (method) {
    case 'POST':
      return http.RequestMethod.POST;
    case 'PUT':
      return http.RequestMethod.PUT;
    case 'PATCH':
      return http.RequestMethod.PATCH;
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
  private static request<T>(method: HttpMethod, path: string, body?: Object): Promise<ApiResp<T>> {
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
          if (resp.code === 401) {
            AuthStore.clear();
          }
          resolve(resp);
        } catch (e) {
          reject(e);
        }
      });
    });
  }

  public static get<T>(path: string): Promise<ApiResp<T>> {
    return ApiClient.request<T>('GET', path);
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