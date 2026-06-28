/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { logger } from '../utils/Logger';
import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'EntryAbility'


export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });

    let windowClass: window.Window | undefined = undefined;
    window.getLastWindow(this.context, (err: BusinessError, data) => {
      if (err.code) {
        logger.error('Failed to obtain top window. Cause:' + JSON.stringify(err));
        return;
      }
      windowClass = data;
      logger.info('Success to obtain top window. Cause:' + JSON.stringify(data));
      // 窗口内容规避的顶部状态栏高度
      let statusHeight = 0;
      // 窗口内容规避的底部安全区高度
      let bottomHeight = 0;
      // 获取窗口内容规避的区域在componentstack里使用
      const type = window.AvoidAreaType.TYPE_SYSTEM;
      try {
        const avoidArea = windowClass.getWindowAvoidArea(type);
        logger.info('Succeeded to obtain the area. Cause:' + JSON.stringify(avoidArea));
        statusHeight = avoidArea.topRect.height;
        bottomHeight = avoidArea.bottomRect.height
      } catch (exception) {
        logger.error('Failed to obtain the area. Cause:' + JSON.stringify(exception));
      }
      // 存储窗口内容规避的状态栏高度
      AppStorage.setOrCreate('statusHeight', statusHeight);
      // 存储窗口内容规避的底部安全区高度
      AppStorage.setOrCreate('bottomHeight', bottomHeight);

      // 当前窗口高度
      let screenHeight = 0;
      // 获取窗口区域在componentstack里使用
      let displayClass: display.Display | null = null;
      try {
        displayClass = display.getDefaultDisplaySync();
        logger.info('Succeeded to obtain the default display object. Code: ' + JSON.stringify(displayClass));
        screenHeight = displayClass.height;
      } catch (exception) {
        logger.error('Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
      }
      // 存储当前窗口高度
      AppStorage.setOrCreate('screenHeight', screenHeight);

      // TODO: 知识点：设置监听键盘变化，控制虚拟键盘抬起时页面避让
      const bottomAvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        .bottomRect
        .height;
      windowClass.on('keyboardHeightChange', (data) => {
        if (data > 0) {
          AppStorage.setOrCreate('keyboardHeight', data - bottomAvoidArea);
        } else {
          AppStorage.setOrCreate('keyboardHeight', 0);
        }
        logger.info(TAG, 'keyboardHeight data:' + data.toString() + ',bottomAvoidArea:' +
        bottomAvoidArea.toString());
      })

      // window的宽度
      let windowWidth: number = 0;
      try {
        const windowProperties = windowClass.getWindowProperties();
        windowWidth = windowProperties.windowRect.width;
        logger.info("Succeeded to obtain the window properties. Window width: ", windowWidth.toString())
      } catch (exception) {
        logger.error('Failed to obtain the window properties. Code: ' + JSON.stringify(exception));
      }
      AppStorage.setOrCreate("windowWidth", windowWidth);
    });

    // 获取当前的颜色模式并保存
    AppStorage.setOrCreate('currentColorMode', this.context.config.colorMode);
    // 保存windowStage供fitfordarkmode的har包中FitForDarkPage.ets中setStatusBar方法修改状态栏颜色。
    AppStorage.setOrCreate('windowStage', windowStage);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
