/**
 * 家属端后端接口配置。
 * 指向运行 Kangxiaoban Go 后端的主机；真机请用局域网 IP。
 */
export class ApiConfig {
  public static readonly API_BASE: string = 'http://10.10.1.233:8080/api/v1';
  public static readonly WS_URL: string = 'ws://10.10.1.233:8080/api/v1/ws';
}
