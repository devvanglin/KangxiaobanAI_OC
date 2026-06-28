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
import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { CommonConstants, Logger, WindowUtil } from 'commonmulticommunityapplication';

const TAG = 'PcAbility';

export default class PcAbility extends UIAbility {
  onCreate(): void {
    Logger.info(TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    Logger.info(TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    Logger.info(TAG, '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error(TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      Logger.info(TAG, 'Succeeded in loading the content.');

      try {
        WindowUtil.getInstance().updateWindowInfo();
        WindowUtil.getInstance().setMainWindow(windowStage.getMainWindowSync());
        WindowUtil.getInstance()
          .setPCImmersive(CommonConstants.PC_DECOR_HEIGHT, CommonConstants.PC_STATUS_BAR_ICON_SIZE);
      } catch (error) {
        Logger.error(TAG, 'Get window failed. %{public}s', JSON.stringify(error));
      }
    });
  }

  onWindowStageDestroy(): void {
    try {
      WindowUtil.getInstance().release();
    } catch (error) {
      Logger.error(TAG, 'WindowUtil getInstance release failed.');
    }
    // Main window is destroyed, release UI related resources
    Logger.info(TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    Logger.info(TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    Logger.info(TAG, '%{public}s', 'Ability onBackground');
  }
}
