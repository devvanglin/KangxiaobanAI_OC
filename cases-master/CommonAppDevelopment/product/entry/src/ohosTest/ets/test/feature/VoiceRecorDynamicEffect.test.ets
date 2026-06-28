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

import { expect, it } from '@ohos/hypium';
import { Driver, ON, UIEventObserver, UIElementInfo } from '@ohos.UiTest';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'voicerecordynamiceffect'; // 案例名称
const CASE_NAME: string = '语音录制和声音动效实现'; // 案例中文名称

/**
 * 【语音录制和声音动效实现案例】自动化测试用例
 * 1. 搜索进入【语音录制和声音动效实现】，按住说话
 * 2. 长按发送语音消息
 */
export default function voiceRecordDynamicEffectTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);
  const driver = Driver.create();

  /**
   * 按住说话
   * 通过提示提示 "说话时间太短" 来判断
   */
  it(CASE + '按住说话', 0, async (done: Function) => {
    const agreement = await driver.findComponent(ON.text('允许'));
    await agreement.click();
    await driver.delayMs(300);
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual('说话时间太短！'); // 通过弹出'删除成功'提示来验证
    };
    observer.once('toastShow', callback);
    const speakButton = await driver.findComponent(ON.text('按住说话'));
    await speakButton.click();
    await driver.delayMs(500);
    done();
  })

  /**
   * 长按发送语音消息
   * 通过松开后发送一条语音消息判断
   */
  it(CASE + '长按发送语音消息', 0, async (done: Function) => {
    const speakButton = await driver.findComponent(ON.text('按住说话'));
    await speakButton.longClick();
    await driver.delayMs(300);
    await driver.assertComponentExist(ON.id('voice_add_image'));
    done();
  })

  // 退出案例
  exit(CASE_NAME);
}