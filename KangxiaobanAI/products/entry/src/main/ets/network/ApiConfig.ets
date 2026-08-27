/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

/**
 * 后端接口地址配置。
 * 开发时把 Kangxiaoban Go 后端跑在一台机器上，真机通过局域网访问。
 * 默认地址仅为演示占位，请按实际环境修改：http://<后端所在电脑的局域网IP>:8080
 */
export class ApiConfig {
  // REST 接口根路径
  public static readonly API_BASE: string = 'http://192.168.100.110:8080/api/v1';
  // WebSocket 实时推送地址
  public static readonly WS_URL: string = 'ws://192.168.100.110:8080/api/v1/ws';
}