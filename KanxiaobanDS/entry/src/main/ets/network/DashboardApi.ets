import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiResponse, CockpitSnapshot, LoginResponse } from '../model/DashboardModels';

const API_BASE: string = 'http://10.10.1.233:8080/api/v1';

interface LoginRequest {
  username: string;
  password: string;
  tenant_code?: string;
}

export class DashboardApi {
  private static request<T>(method: http.RequestMethod, path: string, token: string,
    body?: Object): Promise<ApiResponse<T>> {
    const request = http.createHttp();
    const header: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token.length > 0) {
      header['Authorization'] = `Bearer ${token}`;
    }
    const options: http.HttpRequestOptions = {
      method: method,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 10000
    };
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }
    return new Promise<ApiResponse<T>>((resolve, reject) => {
      request.request(`${API_BASE}${path}`, options, (error: BusinessError, response: http.HttpResponse) => {
        request.destroy();
        if (error) {
          reject(error);
          return;
        }
        try {
          resolve(JSON.parse(response.result as string) as ApiResponse<T>);
        } catch (_error) {
          reject(new Error('服务器响应格式错误'));
        }
      });
    });
  }

  public static login(username: string, password: string, tenantCode: string): Promise<ApiResponse<LoginResponse>> {
    const payload: LoginRequest = { username: username, password: password };
    if (tenantCode.trim().length > 0) {
      payload.tenant_code = tenantCode.trim();
    }
    return DashboardApi.request<LoginResponse>(http.RequestMethod.POST, '/auth/login', '', payload);
  }

  public static cockpit(token: string): Promise<ApiResponse<CockpitSnapshot>> {
    return DashboardApi.request<CockpitSnapshot>(http.RequestMethod.GET, '/dashboard/cockpit', token);
  }
}

export default DashboardApi;
