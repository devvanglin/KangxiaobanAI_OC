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
import { HdsNavigationAttribute } from '@kit.UIDesignKit';

export class HdsNavigationModifier implements AttributeModifier<HdsNavigationAttribute> {
  private widthBreakpoint: WidthBreakpoint = WidthBreakpoint.WIDTH_LG;
  private navigationMode: NavigationMode = NavigationMode.Auto;

  constructor(widthBreakpoint: WidthBreakpoint, navigationMode: NavigationMode) {
    this.widthBreakpoint = widthBreakpoint;
    this.navigationMode = navigationMode;
  }

  applyNormalAttribute(instance: HdsNavigationAttribute): void {
    instance
      .navBarWidth(this.widthBreakpoint === WidthBreakpoint.WIDTH_LG ? '36%' : '50%')
      .mode(this.navigationMode)
      .hideTitleBar(true)
      .hideToolBar(true)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}