/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

export interface BreakpointTypeOptions<T> {
  xs?: T;
  sm: T;
  md: T;
  lg: T;
  xl?: T;
}

export class BreakpointType<T> {
  private xs: T;
  private sm: T;
  private md: T;
  private lg: T;
  private xl: T;

  public constructor(param: BreakpointTypeOptions<T>) {
    this.xs = param.xs ?? param.sm;
    this.sm = param.sm;
    this.md = param.md;
    this.lg = param.lg;
    this.xl = param.xl ?? param.lg;
  }

  public getValue(currentBreakpoint: WidthBreakpoint): T {
    if (currentBreakpoint === WidthBreakpoint.WIDTH_XS) {
      return this.xs;
    }
    if (currentBreakpoint === WidthBreakpoint.WIDTH_SM) {
      return this.sm;
    }
    if (currentBreakpoint === WidthBreakpoint.WIDTH_MD) {
      return this.md;
    }
    if (currentBreakpoint === WidthBreakpoint.WIDTH_XL) {
      return this.xl;
    }
    return this.lg;
  }
}

/**
 * 断点判定工具：统一 wide/tablet/pc 判定，避免散落维护。
 * - wide  = MD / LG / XL（平板及以上）
 * - tablet = MD（平板）
 * - pc    = LG / XL（PC 桌面）
 */
export class BreakpointUtil {
  static isWide(breakpoint: WidthBreakpoint): boolean {
    return breakpoint === WidthBreakpoint.WIDTH_MD ||
      breakpoint === WidthBreakpoint.WIDTH_LG ||
      breakpoint === WidthBreakpoint.WIDTH_XL;
  }

  static isTablet(breakpoint: WidthBreakpoint): boolean {
    return breakpoint === WidthBreakpoint.WIDTH_MD;
  }

  static isPc(breakpoint: WidthBreakpoint): boolean {
    return breakpoint === WidthBreakpoint.WIDTH_LG ||
      breakpoint === WidthBreakpoint.WIDTH_XL;
  }

  static isExtraWide(breakpoint: WidthBreakpoint): boolean {
    return breakpoint === WidthBreakpoint.WIDTH_LG ||
      breakpoint === WidthBreakpoint.WIDTH_XL;
  }
}