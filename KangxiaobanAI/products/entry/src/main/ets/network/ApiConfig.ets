/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

/**
 * 后端接口地址配置。
 * 开发时把 Kangxiaoban Go 后端跑在一台机器上，真机通过局域网访问。
 * 当前部署目标后端：10.10.1.13:8080。
 */
export class ApiConfig {
  // REST 接口根路径
  public static readonly API_BASE: string = 'http://10.10.1.13:8080/api/v1';
  // WebSocket 实时推送地址
  public static readonly WS_URL: string = 'ws://10.10.1.13:8080/api/v1/ws';
}
