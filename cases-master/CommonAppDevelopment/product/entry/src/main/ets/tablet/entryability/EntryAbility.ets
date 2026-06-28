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

import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
// 基础公共工具类base，主要包括日志打印和主页列表数据类型以及控制器
import { logger } from 'utils/Index';
import { Configuration } from '@ohos.app.ability.Configuration';
import display from '@ohos.display';
import { BusinessError } from '@ohos.base';
// 日期数据持久化数据模块
import { DataManager, DateModel } from 'customcalendarpickerdialog/Index';
import webview from '@ohos.web.webview';

// 引用异常处理模块
import { eventSubscription } from 'applicationexception/Index';
import { preloadSOByTaskPool } from 'nativerawfile/Index';

import { DynamicsRouter } from 'routermodule/Index';

const TAG = 'EntryAbility'
// 资源异常枚举
const RESOURCE_CONTROL: number = 7;
// 网络PDF文件路径，其中“#toolbar=0”屏蔽Web组件的工具栏
const REMOTE_URL: string =
  'https://gitee.com/harmonyos-cases/cases/raw/master/CommonAppDevelopment/feature/webpdfviewer/src/main/resources/rawfile/sample.pdf#toolbar=0';

// registryDocumentViewPickerFn(); // napi封装ets

export default class EntryAbility extends UIAbility {
  // napi封装ets
  // abilityID: string = generateAbilityID();
  private mWindow!: window.Window;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    logger.info(TAG, '%{public}s', 'Ability onCreate');
    DynamicsRouter.routerInit({
      libPrefix: "@ohos", mapPath: "routerMap"
    }, this.context);
    // TODO：需求：待系统查杀类型需求开发，补充查杀系统枚举类型
    if (launchParam.lastExitReason === RESOURCE_CONTROL) {
    }
    // 绑定上下文信息
    AppStorage.setOrCreate('context', this.context);
    // 事件订阅(获取上次异常退出信息)
    eventSubscription();
    /**
     * 在Ability的onCreate周期函数中和后续的应用声明周期函数中可以使用TaskPool子线程预加载so库，后续通过句柄调用库中的native方法。
     * 此处在Ability的onCreate周期函数中使用TaskPool子线程预加载so库，加载完成后在nativerawfile模块中使用。
     */
    preloadSOByTaskPool();
    // 全局设置为浅色模式
    let applicationContext = this.context.getApplicationContext();
    applicationContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);

    // 通过WebviewController可以控制Web组件各种行为。一个WebviewController对象只能控制一个Web组件，且必须在Web组件和WebviewController绑定后，才能调用WebviewController上的方法（静态方法除外）。
    webview.WebviewController.initializeWebEngine();
    // 启动预连接，连接地址为即将打开的网址。
    webview.WebviewController.prepareForPageLoad(REMOTE_URL, true, 1);
  }

  onDestroy(): void {
    logger.info(TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    logger.info(TAG, '%{public}s', 'Ability onWindowStageCreate');
    this.mWindow = windowStage.getMainWindowSync();

    // 加载应用入口页面
    windowStage.loadContent('tablet/pages/EntryView', (err, data) => {
      if (err.code) {
        logger.info(TAG, 'Failed to load the content. Cause:', JSON.stringify(err));
        return;
      }
      // addUIContext(this.abilityID, windowStage); // napi封装ets
      logger.info(TAG, 'Succeeded in loading the content. Data:', JSON.stringify(data));
    });
    // setTopAbilityID(this.abilityID, windowStage); // napi封装ets

    let windowClass: window.Window | undefined = undefined;
    window.getLastWindow(this.context, (err: BusinessError, data) => {
      if (err.code) {
        console.error('Failed to obtain top window. Cause:' + JSON.stringify(err));
        return;
      }
      windowClass = data;
      console.info('Success to obtain top window. Cause:' + JSON.stringify(data));
      // 窗口内容规避的顶部状态栏高度
      let statusHeight = 0;
      // 窗口内容规避的底部安全区高度
      let bottomHeight = 0;
      // 获取窗口内容规避的区域在componentstack里使用
      const type = window.AvoidAreaType.TYPE_SYSTEM;
      try {
        const avoidArea = windowClass.getWindowAvoidArea(type);
        console.info('Succeeded to obtain the area. Cause:' + JSON.stringify(avoidArea));
        statusHeight = avoidArea.topRect.height;
        bottomHeight = avoidArea.bottomRect.height;
      } catch (exception) {
        console.error('Failed to obtain the area. Cause:' + JSON.stringify(exception));
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
        screenHeight = displayClass.height;
      } catch (exception) {
        console.error('Failed to obtain the default display object. Code: ' + JSON.stringify(exception));
      }
      console.error('Succeeded to obtain the default display object. Code: ' + JSON.stringify(displayClass));
      // 存储当前窗口高度
      AppStorage.setOrCreate('screenHeight', screenHeight);

      // TODO: 知识点：设置监听键盘变化，控制虚拟键盘抬起时页面的避让模式
      const avoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const bottomRectHeight = avoidArea.bottomRect.height;
      windowClass.on('keyboardHeightChange', (data) => {
        if (data > 0) {
          AppStorage.setOrCreate('keyboardHeight', data - bottomRectHeight);
        } else {
          AppStorage.setOrCreate('keyboardHeight', 0);
        }

        logger.info(TAG,
          'tablet keyboardHeight data:' + data.toString() + ',bottomAvoidArea:' + bottomRectHeight.toString());
      })
    });

    globalThis.setOrientation = async (orientation: window.Orientation): Promise<void> => {
      // 设置导航栏、状态栏不显示，从而达到沉浸式效果
      await this.mWindow.setWindowSystemBarEnable(['status', 'navigation']);
      // 设置窗口的显示方向
      await this.mWindow.setPreferredOrientation(orientation);
    };
    // 订阅窗口尺寸变化
    this.mWindow.on('windowSizeChange', (size: window.Size) => {
      console.info(`onWindowSizeChange: size = ${JSON.stringify(size)}`);
      AppStorage.setOrCreate('windowSize', size);
    });

    // 获取当前的颜色模式并保存
    AppStorage.setOrCreate('currentColorMode', this.context.config.colorMode);
    // 保存windowStage供fitfordarkmode的har包中FitForDarkPage.ets中setStatusBar方法修改状态栏颜色。
    AppStorage.setOrCreate('windowStage', windowStage);

    // 获取Preferences实例
    this.getPreferencesData();
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    logger.info(TAG, '%{public}s', 'Ability onWindowStageDestroy');
    // removeUIContext(this.abilityID); // napi封装ets
    // 移除当前windowStage实例缓存
    AppStorage.delete('windowStage');
  }

  onForeground(): void {
    // Ability has brought to foreground
    logger.info(TAG, '%{public}s', 'Ability onForeground');

  }

  onBackground(): void {
    // Ability has back to background
    logger.info(TAG, '%{public}s', 'Ability onBackground');
  }

  // TODO: 知识点：检测当前的深浅模式是否发生变化，刷新状态栏
  onConfigurationUpdate(config: Configuration) {
    // 获取最新的变更颜色并更新到AppStorage
    AppStorage.setOrCreate('currentColorMode', config.colorMode);
    logger.info(`onConfigurationUpdate, config: ${JSON.stringify(config)}`);
  }

  // 获取Preferences实例
  getPreferencesData() {
    DataManager.getDate(this.context, (dateModel: DateModel) => {
      // TODO: 知识点：应用级变量的状态管理
      AppStorage.setOrCreate<DateModel>('selectedDate', dateModel);
    })
  }
}
