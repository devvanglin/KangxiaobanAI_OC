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

import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pushService } from '@kit.PushKit';

export default class EntryAbility extends UIAbility {

  private localStorage = new LocalStorage();

  // The input parameters want and launchParam are not actually used. They are defined during project initialization
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');

    const value = want.parameters?.testKey;
    hilog.info(0x0000, 'testTag', 'Succeeded in getting message data, value is %{public}s', value??'default value');
    this.localStorage.setOrCreate('want', want)

    // Obtain a push token
    pushService.getToken().then(token => {
      hilog.info(0x0000, 'testTag', 'Succeeded in getting push token');
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', 'Failed to get push token: %{public}d %{public}s', err.code, err.message);
    })
    // Report the push token to both the Push Kit server and your server
  }

  // When the app is in the background, click pop-up to invoke
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const value = want.parameters?.testKey;
    hilog.info(0x0000, 'testTag', 'Succeeded in getting message data, value is %{public}s', value??'default value');
    this.localStorage.setOrCreate('want', want)
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');

      // Pull up the notification pop-up to request notification authorization from the user
      notificationManager.isNotificationEnabled().then((flag: boolean) => {
        hilog.info(0x0000, 'testTag', 'isNotificationEnabled success, data: %{public}d', flag);
        if (!flag) {
          notificationManager.requestEnableNotification(this.context)
            .then(() => {
              hilog.info(0x0000, 'testTag', 'requestEnableNotification success');
            })
            .catch((err: BusinessError) => {
              if (1600004 === err.code) {
                hilog.error(0x0000, 'testTag',
                  `[ANS] requestEnableNotification refused, code is ${err.code}, message is ${err.message}`);
              } else {
                hilog.error(0x0000, 'testTag',
                  `[ANS] requestEnableNotification failed, code is ${err.code}, message is ${err.message}`);
              }
            })
        }
      }).catch((err: BusinessError) => {
        hilog.error(0x0000, 'testTag', `isNotificationEnabled fail, code is ${err.code}, message is ${err.message}`);
      })
    });
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

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(0x0000, 'testTag', '%{public}s', newConfig.language);
    AppStorage.setOrCreate('currentLanguage', newConfig.language);
  }
}