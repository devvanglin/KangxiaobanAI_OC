import { LoginUser } from './Dto';

/** 会话令牌管理（内存单例）。 */
class AuthStore {
  private static token: string = '';
  private static user: LoginUser | null = null;

  public static getToken(): string {
    return AuthStore.token;
  }

  public static getUser(): LoginUser | null {
    return AuthStore.user;
  }

  public static setSession(token: string, user: LoginUser): void {
    AuthStore.token = token;
    AuthStore.user = user;
  }

  public static clear(): void {
    AuthStore.token = '';
    AuthStore.user = null;
  }
}

export default AuthStore;