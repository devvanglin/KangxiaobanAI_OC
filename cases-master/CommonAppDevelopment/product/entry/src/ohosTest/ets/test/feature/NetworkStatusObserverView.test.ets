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

import { Component, Driver, ON } from "@kit.TestKit";
import { expect, it } from "@ohos/hypium";
import exit from "../common/Exit.test";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Want } from "@kit.AbilityKit";
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

const CASE: string = 'NetworkStatusObserver'; // 案例名称
const TAG: string = '[NetworkStatusObserver_Test]';
const DELAY_MS: number = 500; // 指定500ms的延迟

const delegator: AbilityDelegatorRegistry.AbilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();

/**
 * 【网络状态监听】自动化测试用例
 */
export default function networkStatusObserverTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('网络状态监听');

  const driver = Driver.create();

  it("网络状态监听", 0, async (done: Function) => {
    await driver.assertComponentExist(ON.text("自动播放设置"));
    await driver.assertComponentExist(ON.id("id_network_status_observer_video"));

    const autoPlaySetting: Component = await driver.findComponent(ON.text("自动播放设置"));
    await driver.delayMs(DELAY_MS);
    await autoPlaySetting.click();
    await driver.delayMs(DELAY_MS);

    await driver.assertComponentExist(ON.text("自动播放设置"));
    await driver.assertComponentExist(ON.text("3G/4G/5G自动播放"));
    await driver.assertComponentExist(ON.id("id_network_status_observer_cellular_toggle"));
    await driver.assertComponentExist(ON.text("WI-FI自动播放"));
    await driver.assertComponentExist(ON.id("id_network_status_observer_wifi_toggle"));

    const cellularAutoPlay: Component = await driver.findComponent(ON.id("id_network_status_observer_cellular_toggle"));
    await driver.delayMs(DELAY_MS);
    await cellularAutoPlay.click();
    await driver.delayMs(DELAY_MS);
    const wifiAutoPlay: Component = await driver.findComponent(ON.id("id_network_status_observer_wifi_toggle"));
    await driver.delayMs(DELAY_MS);
    await wifiAutoPlay.click();
    await driver.delayMs(DELAY_MS);

    await driver.pressBack();
    await driver.delayMs(DELAY_MS);
    done();
  })

  exit(CASE);
}