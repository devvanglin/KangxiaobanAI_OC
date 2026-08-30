// Copyright (c) 2026 Huawei Device Co., Ltd.
// Licensed under the Apache License, Version 2.0.

import { WideAdminWorkspace } from './WideAdminWorkspace';

/**
 * Compatibility facade for callers that still use the historical doctor
 * workspace name.
 *
 * The doctor and administrator wide consoles intentionally have one visual
 * source of truth. Keeping this facade preserves the old component contract
 * for incremental migrations without reintroducing a second navigation tree
 * or a second set of layout tokens.
 */
@ComponentV2
export struct WideDoctorWorkspace {
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  /** Retained for source compatibility with the former admission shell. */
  @Param admissionCompactWidth: boolean = false;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};

  build() {
    WideAdminWorkspace({
      statusBarHeight: this.statusBarHeight,
      naviIndicatorHeight: this.naviIndicatorHeight,
      compactWidth: this.compactWidth,
      canHandleAlerts: false,
      isDoctor: true,
      onOpenAbout: () => this.onOpenAbout(),
      onOpenGeneral: () => this.onOpenGeneral(),
      onLogout: () => this.onLogout()
    })
  }
}
