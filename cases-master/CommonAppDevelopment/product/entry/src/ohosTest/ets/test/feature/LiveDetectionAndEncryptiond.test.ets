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
import { Component, Driver, ON } from '@ohos.UiTest';
import { logger } from "utils";
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'livedetectionandencryptiond'; // 案例名称
const CASE_NAME: string = '人脸识别验证案例';

/**
 * 【人脸识别验证案例】自动化测试用例
 * 1. 拉起半模态弹窗
 */
export default function liveDetectionAndEncryptiondTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('人脸识别验证案例');
  const driver = Driver.create();

  /**
   * 执行步骤：
   * 1、拉起半模态弹窗
   * 2、通过判断是否出现"同意协议认证"字样来判断
   **/
  it(CASE + '拉起半模态弹窗', 0, async (done: Function) => {
    const login = await driver.findComponent(ON.text('登录'));
    await login.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.text('同意协议认证'));
    await driver.pressBack();
    await driver.delayMs(500);
    done();
  })

  // 退出案例
  exit(CASE_NAME);

}