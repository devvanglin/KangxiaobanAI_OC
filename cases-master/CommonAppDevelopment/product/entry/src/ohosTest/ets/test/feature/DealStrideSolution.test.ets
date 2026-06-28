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
import { Driver, ON } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'DealStrideSolution'; // 案例名称
const CASE_NANE: string = '解决相机预览花屏案例'; // 案例中文名称

/**
 * 【解决相机预览花屏案例】自动化测试用例（注：本案例仅支持真机验证）
 * 1. 点击授权给相机
 * 2. 验证页面是否正常
 */
export default function dealStrideSolutionTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn(CASE_NANE);
  let driver = Driver.create();

  /**
   * 点击权限弹窗进入案例，页面正常
   */
  it(CASE + '判断页面是否正常', 0, async (done: Function) => {
    let btnPermission = await driver.findComponent(ON.text('允许'));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1500);
    }
    // 断言存在相机渲染页面
    await driver.assertComponentExist(ON.id('DealStrideSolutionComponent'));
    done();
  })

  /**
   * 退出案例
   */
  exit(CASE_NANE)
}