/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { LoginUser } from './Dto';

/**
 * 会话令牌管理（内存单例）。
 * M2 先存内存，后续里程碑接入持久化（登录态保持）。
 */
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