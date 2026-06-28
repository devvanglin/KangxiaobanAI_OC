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
import { SecondaryNavigationView } from './CommonView';

/**
 * Top Secondary Navigation Bar
 */
@ComponentV2
export struct TopSecNavView {
  private moduleName: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Param @Require viewModel: SecNavigationViewModel;
  @Param @Require firstTitle: Resource;
  @Param @Require secondTitle: Resource;
  @Event onFirstClick: () => void = () => {
  };
  @Event onSecondClick: () => void = () => {
  };

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
  }

  build() {
    Stack() {
      Row({
        space: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 24.5 :
          new BreakpointType<number>(24, 48, 56, 24.5).getValue(this.breakpoint.widthBreakpoint)
      }) {
        Row() {
          SecondaryNavigationView(0, this.firstTitle, this.viewModel)
        }
        .onClick(() => {
          this.onFirstClick();
        })

        Row() {
          SecondaryNavigationView(1, this.secondTitle, this.viewModel)
        }
        .onClick(() => {
          this.onSecondClick();
        })
      }
    }
    .width('100%')
    .height(56)
    .alignContent(this.moduleName === CommonConstants.DEVICE_TYPE_PC ? Alignment.Start : Alignment.Center)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.moduleName === CommonConstants.DEVICE_TYPE_PC ? $r('app.color.background_top') :
      $r('app.color.background_primary'))
  }
}