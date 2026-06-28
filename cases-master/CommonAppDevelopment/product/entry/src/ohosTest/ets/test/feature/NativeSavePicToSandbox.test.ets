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
import exit from "../common/Exit.test";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";

/**
 * 【Native保存图片到应用沙箱】自动化测试用例
 */
export default function nativeSavePicToSandboxTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('Native保存图片到应用沙箱');

  const driver = Driver.create();

  it("保存RawFile图片到沙箱", 0, async (done: Function) => {

    await driver.delayMs(200);
    const txt_rawfile_path = await driver.findComponent(ON.id('txt_rawfile_sandbox_path'));
    await driver.delayMs(100);
    // 读取初始时rawfile沙箱路径
    let rawfile_path_old: string = await txt_rawfile_path!.getText();
    await driver.delayMs(100);
    // 判断初始时rawfile沙箱路径为空
    expect(rawfile_path_old).assertEqual('');

    const btn_save_rawfile = await driver.findComponent(ON.id('btn_save_rawfile_pic'));
    await driver.delayMs(100);
    await btn_save_rawfile.click();
    await driver.delayMs(500);
    // 读取rawfile保存的沙箱路径
    let rawfile_path_new: string = await txt_rawfile_path!.getText();
    // 判断已经获取图片的沙箱路径
    expect(rawfile_path_new.includes('.jpg')).assertEqual(true);
    done();
  })

  it("保存网络图片到沙箱", 0, async (done: Function) => {

    await driver.delayMs(200);
    const txt_internet_path = await driver.findComponent(ON.id('txt_internet_sandbox_path'));
    await driver.delayMs(100);
    // 读取初始时网络图片沙箱路径
    let internet_path_old: string = await txt_internet_path!.getText();
    await driver.delayMs(100);
    // 判断初始时网络图片沙箱路径为空
    expect(internet_path_old).assertEqual('');

    const btn_save_internet = await driver.findComponent(ON.id('btn_save_internet_pic'));
    await driver.delayMs(100);
    await btn_save_internet.click();
    await driver.delayMs(500);
    // 读取网络图片保存的沙箱路径
    let internet_path_new: string = await txt_internet_path!.getText();
    // 判断已经获取图片的沙箱路径
    expect(internet_path_new.includes('.jpg')).assertEqual(true);
    done();
  })

  exit('Native保存图片到应用沙箱');
}