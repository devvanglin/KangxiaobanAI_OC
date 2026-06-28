/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { Driver, ON, MatchPattern } from '@ohos.UiTest';
import { it } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import exit from './common/Exit';

const TAG: string = '[CustomScan_Test]';
const CASE: string = 'PhotoPickerFlow';

export default function photoPickerFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_OpenPhotoPicker', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_OpenPhotoPicker begin`);
    // 处理权限
    await driver.delayMs(2000);
    try {
      let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
      if (btnPermission) {
        await btnPermission.click();
        await driver.delayMs(1000);
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Permission already granted');
    }

    // 点击图库按钮
    let btnGallery = await driver.findComponent(ON.id('btn_gallery'));
    await btnGallery.click();
    await driver.delayMs(2000);
    hilog.info(0x0000, TAG, `${CASE}_OpenPhotoPicker end`);
    done();
  });

  it(CASE + '_CancelSelection', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_CancelSelection begin`);
    // 返回扫码界面
    await driver.pressBack();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_CancelSelection end`);
    done();
  });

  it(CASE + '_SelectQRCodeImage', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_SelectQRCodeImage begin`);
    // 再次打开图库
    let btnGallery = await driver.findComponent(ON.id('btn_gallery'));
    await btnGallery.click();
    await driver.delayMs(2000);

    // 这里需要选择包含二维码的图片进行测试
    // 由于实际设备上的图片不可控，这里只做流程测试
    await driver.pressBack();
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_SelectQRCodeImage end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
