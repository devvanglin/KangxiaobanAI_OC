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
import { it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import exit from './common/Exit';

const TAG: string = '[CustomScan_Test]';
const CASE: string = 'PermissionFlow';

export default function permissionFlowTest() {
  let driver = Driver.create();
  hilog.info(0x0000, TAG, `${CASE} begin`);

  it(CASE + '_RequestCameraPermission', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_RequestCameraPermission begin`);
    // 首次进入扫码页面，请求相机权限
    await driver.delayMs(2000);

    // 检查权限弹窗并点击"允许"
    try {
      let btnPermission = await driver.findComponent(ON.text('仅使用期间允许', MatchPattern.CONTAINS));
      if (btnPermission) {
        await btnPermission.click();
        await driver.delayMs(1000);
      }
    } catch (error) {
      hilog.info(0x0000, TAG, 'Permission dialog not found or already granted');
    }

    // 验证权限已授予，进入扫码界面
    await driver.delayMs(1000);
    hilog.info(0x0000, TAG, `${CASE}_RequestCameraPermission end`);
    done();
  });

  it(CASE + '_CameraPermissionGranted', 0, async (done: Function) => {
    hilog.info(0x0000, TAG, `${CASE}_CameraPermissionGranted begin`);
    // 验证相机流组件已加载
    await driver.assertComponentExist(ON.id('camera_component'));
    hilog.info(0x0000, TAG, `${CASE}_CameraPermissionGranted end`);
    done();
  });

  exit(CASE);
  hilog.info(0x0000, TAG, `${CASE} end`);
}
