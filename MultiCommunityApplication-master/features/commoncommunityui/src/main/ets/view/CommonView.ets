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
import { common } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { BreakpointType, CommonConstants } from 'commonmulticommunityapplication';
import { SecNavigationViewModel } from '../viewmodel/HomeViewModel';

/**
 * Top-level secondary navigation bar component.
 */
@Builder
export function SecondaryNavigationView(index: number, titleTabs: Resource, viewModel: SecNavigationViewModel) {
  Text(titleTabs)
    .fontSize(viewModel.currentSubTabIndex === index ? 24 : 18)
    .fontWeight(viewModel.currentSubTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
    .fontColor(viewModel.currentSubTabIndex === index ? $r('app.color.font_primary') : $r('app.color.font_tertiary'))
}

/**
 * Circular search button.
 */
@Builder
export function CommonIcon(icon: Resource) {
  Button({ type: ButtonType.Circle }) {
    SymbolGlyph(icon)
      .fontColor([$r('sys.color.icon_primary')])
      .fontSize($r('sys.float.Title_M'))
  }
  .buttonStyle(ButtonStyleMode.NORMAL)
  .width(40)
  .height(40)
}

/**
 * Public search bar.
 */
@ComponentV2
export struct SearchBar {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private moduleName: string = '';

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
  }

  build() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontColor([$r('app.color.font_tertiary')])
        .fontSize($r('sys.float.Body_L'))

      TextInput({ placeholder: $r('app.string.search_placeholder') })
        .focusable(false)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.font_color_primary'))
        .placeholderColor($r('app.color.placeholder_color'))
        .backgroundColor($r('app.color.search_bar_background_color'))
        .padding(0)
        .layoutWeight(1)
    }
    .borderRadius(this.moduleName !== CommonConstants.DEVICE_TYPE_PC ? 24 : 8)
    .backgroundColor($r('app.color.search_bar_background_color'))
    .width(new BreakpointType<number>(0, 192, 240, 249).getValue(this.breakpoint.widthBreakpoint))
    .height(36)
    .padding({ left: 12 })
  }
}