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

/** REST 请求封装，自动携带 Bearer token。 */
export class ApiClient {
  private static request<T>(method: HttpMethod, path: string, body?: Object): Promise<ApiResp<T>> {
    const req = http.createHttp();
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
      req.request(ApiConfig.API_BASE + path, options, (err: BusinessError, data: http.HttpResponse) => {
        req.destroy();
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
    return { code: 0, msg: '', data: { list: items, page: 1, size: items.length, total: Math.max(total, items.length) } };
  }

  public static post<T>(path: string, body?: Object): Promise<ApiResp<T>> {
    return ApiClient.request<T>('POST', path, body);
  }
}
