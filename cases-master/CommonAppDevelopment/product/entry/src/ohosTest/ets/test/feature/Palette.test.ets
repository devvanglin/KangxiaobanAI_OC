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

import { Driver, ON } from '@kit.TestKit';
import { expect, it } from '@ohos/hypium';
import exit from '../common/Exit.test';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';

/**
 * 【画笔调色板】自动化测试用例
 * 主要功能：本示例实现了一个网格渐变的画笔调色板，能够根据给定的 HSL 类型颜色和色阶数，按亮度生成渐变色，用户可以通过调色板选择颜色并在画布上绘制路径。
 * 执行步骤：
 * 1. 验证存在12个预设的常用颜色色块，并且可以点击，点击后当前画笔颜色修改为对应颜色。（当前画笔颜色是否修改需要手工用例进行测试）
 * 2. 验证存在当前画笔颜色组件，点击后显示网格渐变的调色板，其中包含13*9个可点击色块。点击其中的色块，切换画笔颜色。（当前画笔颜色是否修改需要手工用例进行测试）
 * 3. 在绘制区域滑动手指，跟手绘制轨迹，轨迹颜色为当前画笔颜色。（轨迹位置和颜色是否满足预期需要手工用例进行测试）
 */
export default function paletteTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('画笔调色板案例');

  const driver = Driver.create();

  it('验证点击预设常用颜色切换画笔颜色功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在12个预设常用颜色色块，并且每个色块可点击
    for (let i = 0; i < 12; i++) {
      await driver.assertComponentExist(ON.id(`presetColor${i}`));
      let presetColorComponent = await driver.findComponent(ON.id(`presetColor${i}`));
      let isClickable = await presetColorComponent.isClickable();
      expect(isClickable).assertEqual(true);
    }
    done();
  })

  it('验证点击当前画笔颜色显示调色板功能', 0, async (done: Function) => {
    await driver.delayMs(500);
    // 断言存在当前选中的画笔颜色组件，并且可点击
    await driver.assertComponentExist(ON.id('selectedColor'));
    let selectedColorComponent = await driver.findComponent(ON.id('selectedColor'));
    await selectedColorComponent.click();
    await driver.delayMs(200);
    // 断言存在调色板组件，13*9
    await driver.assertComponentExist(ON.id('palette'));
    // 断言调色板组件中存在13*9的色块，每个色块可点击
    await driver.assertComponentExist(ON.type('GridItem').within(ON.id('palette')));
    let colors = await driver.findComponents(ON.type('GridItem').within(ON.id('palette')));
    expect(colors.length).assertEqual(13 * 9);
    for(let i = 0; i < colors.length; i++){
      let isClickable = await colors[i].isClickable();
      expect(isClickable).assertEqual(true);
    }
    done();
  })

  it('验证绘制功能', 0, async (done: Function) => {
    await driver.delayMs(500);
    // 断言存在绘制区域
    await driver.assertComponentExist(ON.type('NodeContainer'));
    // 滑动绘制轨迹
    await driver.swipe(600, 800, 600, 1000, 600);
    await driver.delayMs(200);
    // 断言存在RenderNode（每笔绘制对应一个RenderNode）
    await driver.assertComponentExist(ON.type('RenderNode'));
    let renderNodeComponents = await driver.findComponents(ON.type('RenderNode'));
    // 滑动后断言RenderNode个数加1
    expect(renderNodeComponents.length).assertEqual(1);
    // 最后一次撤销后RenderNode不存在
    let palette = await driver.findComponent(ON.type('palette'));
    expect(palette).assertEqual(null);
    done();
  })

  exit('画笔调色板案例');
}