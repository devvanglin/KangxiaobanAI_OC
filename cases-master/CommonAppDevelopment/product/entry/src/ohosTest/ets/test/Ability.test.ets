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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { Component, Driver, ON, MatchPattern } from '@ohos.UiTest';
import Want from '@ohos.app.ability.Want';
import { logger } from 'utils';
import { HiLogMonitorManagement } from 'hilogmonitormanagement';

const BUNDLE: string = 'Cases';
const TAG: string = '[Cases_Test]';
const delegator: AbilityDelegatorRegistry.AbilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();

/**
 * Resource转化为string函数
 * @param resource
 * @returns string
 */
async function getResourceString(resource: Resource): Promise<string> {
  let manage = delegator.getAppContext().resourceManager;
  let text = await manage.getStringValue(resource);
  return text;
}

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    })

    /**
     * 打开应用
     */
    it(BUNDLE + '_startAbility', 0, async (done: Function) => {
      logger.info(TAG, BUNDLE + '_startAbility start')
      let want: Want = {
        bundleName: 'com.north.cases',
        abilityName: 'EntryAbility'
      };
      delegator.startAbility(want, (err) => {
        logger.info(TAG, 'StartAbility get err ' + JSON.stringify(err));
        expect(err).assertNull();
      })
      logger.info(TAG, BUNDLE + '_startAbility end');
      let driver: Driver = Driver.create();
      await driver.delayMs(3000);
      // 等待开机广告结束
      await driver.delayMs(5000);
      done();
    })
    /**
     * 注册日志回调，验证Native侧实现进度条通知功能
     */
    it('Case_ProgressNotify_001', 1, async (done: Function) => {
      logger.info(TAG, `${BUNDLE}_ProgressNotify_001 begin`);
      let driver: Driver = Driver.create();
      await driver.delayMs(500);
      // 进入tab的native页签
      let nativeTab: Component = await driver.findComponent(ON.text('Native'));
      await driver.delayMs(500);
      await nativeTab.click();
      await driver.delayMs(500);

      // 点击进入Native侧实现进度条通知功能案例
      await driver.swipe(0, 800, 0, 100, 600);
      let notifyBtn: Component = await driver.findComponent(ON.text('进度通知', MatchPattern.CONTAINS));
      await driver.delayMs(500);
      await notifyBtn!.click();
      await driver.delayMs(500);

      // TODO: 知识点： 注册日志回调, 侦听Native侧实现进度条通知功能
      const logMonitor: string = "downloadTask begin"; // 要监听的日志内容
      let isMonitorLogPrint: Boolean = false; // 监听的日志内容是否打印
      let logCallback: string = ""; // 回调返回的日志内容
      const hiLogMonitor: HiLogMonitorManagement = new HiLogMonitorManagement();
      hiLogMonitor.registerCallback(logMonitor, ((strLog: string) => {
        // 判断返回的日志内容是否包含侦听的日志内容
        logCallback = strLog;
        if (logCallback.indexOf(logMonitor) !== -1) {
          isMonitorLogPrint = true;
        } else {
          isMonitorLogPrint = false;
        }
      }));
      isMonitorLogPrint = false;
      // 点击开始下载按钮
      let downloadBtn: Component = await driver.findComponent(ON.id('btnProgressNotify'));
      logger.info(TAG,
        'TestLogCallback registerCallback call begin, isMonitorLogPrint:' + isMonitorLogPrint.toString());
      await downloadBtn.click();
      await driver.delayMs(100);
      // 验证注册日志回调后，isMonitorLogPrint 为 true
      expect(isMonitorLogPrint).assertEqual(true);
      // 验证完后关闭侦听
      hiLogMonitor.cancelCallback();
      logger.info(TAG,
        'TestLogCallback registerCallback call end, isMonitorLogPrint:' + isMonitorLogPrint.toString() + ', log: ' +
          logCallback);

      // 退出到首页面
      await driver.delayMs(500);
      await driver.pressBack();
      logger.info(TAG, `${BUNDLE}_ProgressNotify_001 end`);
      done();
    })

    // 进入边缓存边播放范例主页面
    it('Case_videCache_001', 1, async () => {
      logger.info(TAG, `${BUNDLE}_videCache_001 begin`);
      let driver: Driver = Driver.create();
      await driver.delayMs(2000); // 延迟时间2000ms
      let videoCacheBtn: Component =
        await driver.findComponent(ON.text(await getResourceString($r('app.string.video_cache_title_name')),
          MatchPattern.CONTAINS));
      await driver.delayMs(500); // 延迟时间500ms
      await videoCacheBtn.click();
      await driver.delayMs(500);
    })
    // 实现播放暂停以及重新播放功能
    it('Case_videCache_002', 1, async () => {
      logger.info(TAG, `${BUNDLE}_videCache_002 begin`);
      let driver: Driver = Driver.create();
      await driver.delayMs(1000);
      // 点击暂停
      let videoSwitch: Component = await driver.findComponent(ON.id('videoSwitch'));
      await driver.delayMs(22000); // 延迟时间22000ms
      await videoSwitch.click();
      await driver.delayMs(500);
      // 点击播放
      await videoSwitch.click();
      // 点击重置
      await driver.delayMs(10000);
      await videoSwitch.click();
      // 返回页面
      await driver.delayMs(500);
      await driver.pressBack();
    })
  })
}