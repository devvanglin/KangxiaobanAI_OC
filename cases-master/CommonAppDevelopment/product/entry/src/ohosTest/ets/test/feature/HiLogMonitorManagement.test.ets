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

import { Driver, ON } from "@kit.TestKit";
import { expect, it } from "@ohos/hypium";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { HiLogMonitorManagement } from 'hilogmonitormanagement';
import exit from "../common/Exit.test";

/**
 * 【监听HiLog日志实现测试用例验证】自动化测试用例
 */
export default function hiLogMonitorManagementTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('在Native侧实现进度通知功能');

  const driver = Driver.create();
  it("监听HiLog日志实现测试用例验证", 0, async (done: Function) => {
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
    let downloadBtn = await driver.findComponent(ON.id('btnProgressNotify'));
    await downloadBtn.click();
    await driver.delayMs(100);
    // 验证注册日志回调后，isMonitorLogPrint 为 true
    expect(isMonitorLogPrint).assertEqual(true);
    // 验证完后关闭侦听
    hiLogMonitor.cancelCallback();

    done();
  })

  exit('在Native侧实现进度通知功能');
}