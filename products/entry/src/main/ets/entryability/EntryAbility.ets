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

import { AbilityConstant, common, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import Logger from '../util/Logger';
import { WindowUtil } from '../util/WindowUtil';
import { PreferenceManager } from '../util/PreferenceManager';
import { StorageKey } from '../common/CommonConstants';

const TAG: string = '[KanxiaobanAbility]';

export default class KanxiaobanAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Logger.error(TAG, `Failed to set colorMode. Cause: ${err.message}`);
    }
    Logger.info(TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    Logger.info(TAG, 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    Logger.info(TAG, `Ability configuration updated. colorMode: ${newConfig.colorMode}`);
    WindowUtil.refreshSystemBarAppearance();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    Logger.info(TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/LoginPage', (err) => {
      if (err.code) {
        Logger.error(TAG, `Failed to load the content. Cause: ${err.message}`);
        return;
      }
      WindowUtil.initialize(windowStage);
      this.applyStartupSettings();
      Logger.info(TAG, 'Succeeded in loading the content.');
    });
  }

  private applyStartupSettings(): void {
    const preferenceManager: PreferenceManager = PreferenceManager.getInstance();
    const appearance: string = preferenceManager.getValue<string>(StorageKey.GENERAL_APPEARANCE,
      JSON.stringify('system')) ?? 'system';
    const fontSize: string = preferenceManager.getValue<string>(StorageKey.GENERAL_FONT_SIZE,
      JSON.stringify('system')) ?? 'system';
    const language: string = preferenceManager.getValue<string>(StorageKey.GENERAL_APP_LANGUAGE,
      JSON.stringify('system')) ?? 'system';
    try {
      const appContext: common.ApplicationContext = this.context.getApplicationContext();
      if (appearance === 'light') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (appearance === 'dark') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
      if (fontSize !== 'system') {
        let scale: number = 1.0;
        if (fontSize === 'small') {
          scale = 0.85;
        } else if (fontSize === 'large') {
          scale = 1.15;
        } else if (fontSize === 'xlarge') {
          scale = 1.3;
        }
        appContext.setFontSizeScale(scale);
      }
      let languageTag: string = '';
      if (language === 'zh-CN') {
        languageTag = 'zh-CN';
      } else if (language === 'en-US') {
        languageTag = 'en-US';
      }
      appContext.setLanguage(languageTag);
    } catch (err) {
      Logger.error(TAG, `applyStartupSettings failed: ${err.message}`);
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    Logger.info(TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    Logger.info(TAG, 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    Logger.info(TAG, 'Ability onBackground');
  }
}
