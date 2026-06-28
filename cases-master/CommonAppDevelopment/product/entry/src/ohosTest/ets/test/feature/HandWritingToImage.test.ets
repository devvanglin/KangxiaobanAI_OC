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
 * 【手写绘制及保存图片】自动化测试用例
 * 主要功能：本示例使用drawing库的Pen和Path结合NodeContainer组件实现手写绘制功能。手写板上完成绘制后，通过调用image库的packToFile和packing接口将手写板的绘制内容保存为图片，并将图片文件保存在应用沙箱路径中。
 * 执行步骤：
 * 1. 在虚线区域内滑动五次绘制线条，packToFile保存图片和packing保存图片按钮变为可用状态。
 * 2. 点击packToFile保存图片按钮，显示图片沙箱路径。
 * 3. 点击packing保存图片按钮，显示图片沙箱路径且与点击packToFile保存图片后的图片路径不同。
 * 4. 点击五次撤销按钮，每次点击后最近一次绘制消失，最后一次撤销后虚线区域内无绘制内容，并且packToFile保存图片和packing保存图片按钮变为禁用状态。
 * 5. 在虚线区域内滑动五次绘制线条，然后点击重置按钮，区域内所有绘制消失，并且packToFile保存图片和packing保存图片按钮变为禁用状态。
 */
export default function handWritingToImageTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('手写绘制及保存图片');
  // 保存到沙箱的图片路径
  let filePath: string = '';
  const driver = Driver.create();

  it('验证虚线区域手写功能', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在packToFile保存图片按钮，并且按钮处于禁用状态
    await driver.assertComponentExist(ON.text('packToFile保存图片'));
    let packToFileButtonComponent = await driver.findComponent(ON.text('packToFile保存图片'));
    let packToFileButtonEnabledBefore = await packToFileButtonComponent.isEnabled();
    expect(packToFileButtonEnabledBefore).assertEqual(false);
    // 断言存在packing保存图片按钮，并且按钮处于禁用状态
    await driver.assertComponentExist(ON.text('packing保存图片'));
    let packingButtonComponent = await driver.findComponent(ON.text('packing保存图片'));
    let packingButtonEnabledBefore = await packingButtonComponent.isEnabled();
    expect(packingButtonEnabledBefore).assertEqual(false);
    // 手指在虚线区域滑动5次
    for (let i = 0; i < 5; i++) {
      await driver.fling({
        x: 300 + i * 100, y: 600
      }, {
        x: 300 + i * 100, y: 800
      }, 5, 600);
      await driver.delayMs(200);
      // 断言存在RenderNode（每笔绘制对应一个RenderNode）
      await driver.assertComponentExist(ON.type('RenderNode'));
      let renderNodeComponents = await driver.findComponents(ON.type('RenderNode'));
      // 滑动后断言RenderNode个数加1
      expect(renderNodeComponents.length).assertEqual(i + 1);
    }
    // 断言packToFile保存图片按钮和packing保存图片按钮变为可用状态
    let packToFileButtonEnabledAfter = await packToFileButtonComponent.isEnabled();
    expect(packToFileButtonEnabledAfter).assertEqual(true);
    let packingButtonEnabledAfter = await packToFileButtonComponent.isEnabled();
    expect(packingButtonEnabledAfter).assertEqual(true);
    await driver.delayMs(500);
    done();
  })

  it('验证packToFile保存图片功能', 0, async (done: Function) => {
    // 断言存在packToFile保存图片按钮
    await driver.assertComponentExist(ON.text('packToFile保存图片'));
    let packToFileButtonComponent = await driver.findComponent(ON.text('packToFile保存图片'));
    await packToFileButtonComponent.click();
    await driver.delayMs(200);
    // 断言图片路径存在
    await driver.assertComponentExist(ON.id('filePath'));
    let filePathComponent = await driver.findComponent(ON.id('filePath'));
    filePath = await filePathComponent.getText();
    expect(filePath !== '').assertEqual(true);
    await driver.delayMs(500);
    done();
  })

  it('验证packing保存图片功能', 0, async (done: Function) => {
    // 断言存在packing保存图片按钮
    await driver.assertComponentExist(ON.text('packing保存图片'));
    let packingButtonComponent = await driver.findComponent(ON.text('packing保存图片'));
    await packingButtonComponent.click();
    await driver.delayMs(200);
    // 断言图片路径存在且更新
    await driver.assertComponentExist(ON.id('filePath'));
    let filePathComponent = await driver.findComponent(ON.id('filePath'));
    let newFilePath = await filePathComponent.getText();
    expect(newFilePath !== '' && newFilePath !== filePath).assertEqual(true);
    await driver.delayMs(500);
    done();
  })

  it('验证撤销功能', 0, async (done: Function) => {
    // 断言存在撤销按钮
    await driver.assertComponentExist(ON.text('撤销'));
    let cancelButtonComponent = await driver.findComponent(ON.text('撤销'));
    // 撤销5次
    for (let i = 5; i > 0; i--) {
      await cancelButtonComponent.click();
      await driver.delayMs(200);
      if (i > 1) {
        // 断言存在RenderNode（每笔绘制对应一个RenderNode）
        await driver.assertComponentExist(ON.type('RenderNode'));
        let renderNodeComponents = await driver.findComponents(ON.type('RenderNode'));
        // 断言每次撤销后RenderNode个数减1
        expect(renderNodeComponents.length).assertEqual(i - 1);
      } else {
        // 最后一次撤销后RenderNode不存在
        let renderNodeComponents = await driver.findComponents(ON.type('RenderNode'));
        expect(renderNodeComponents).assertEqual(null);
      }
    }
    // 撤销5次后断言packToFile保存图片按钮和packing保存图片按钮变为禁用状态
    await driver.assertComponentExist(ON.text('packToFile保存图片'));
    let packToFileButtonComponent = await driver.findComponent(ON.text('packToFile保存图片'));
    let packToFileButtonEnabled = await packToFileButtonComponent.isEnabled();
    expect(false).assertEqual(packToFileButtonEnabled);
    await driver.assertComponentExist(ON.text('packing保存图片'));
    let packingButtonComponent = await driver.findComponent(ON.text('packing保存图片'));
    let packingButtonEnabled = await packingButtonComponent.isEnabled();
    expect(false).assertEqual(packingButtonEnabled);
    await driver.delayMs(500);
    done();
  })

  it('验证重置功能', 0, async (done: Function) => {
    // 手指在虚线区域滑动5次
    for (let i = 0; i < 5; i++) {
      await driver.fling({
        x: 300 + i * 100, y: 600
      }, {
        x: 300 + i * 100, y: 800
      }, 5, 600);
      await driver.delayMs(200);
      // 断言存在RenderNode（每笔绘制对应一个RenderNode）
      await driver.assertComponentExist(ON.type('RenderNode'));
      let renderNodeComponents = await driver.findComponents(ON.type('RenderNode'));
      // 滑动后断言RenderNode个数加1
      expect(i + 1).assertEqual(renderNodeComponents.length);
    }
    // 断言存在重置按钮
    await driver.assertComponentExist(ON.text('重置'));
    let resetButtonComponent = await driver.findComponent(ON.text('重置'));
    await resetButtonComponent.click();
    await driver.delayMs(200);
    // 重置后断言RenderNode不存在
    let renderNodeComponents = await driver.findComponents(ON.type('RenderNode'));
    expect(renderNodeComponents).assertEqual(null);
    // 断言packToFile保存图片按钮和packing保存图片按钮变为禁用状态
    await driver.assertComponentExist(ON.text('packToFile保存图片'));
    let packToFileButtonComponent = await driver.findComponent(ON.text('packToFile保存图片'));
    let packToFileButtonEnabled = await packToFileButtonComponent.isEnabled();
    expect(false).assertEqual(packToFileButtonEnabled);
    await driver.assertComponentExist(ON.text('packing保存图片'));
    let packingButtonComponent = await driver.findComponent(ON.text('packing保存图片'));
    let packingButtonEnabled = await packingButtonComponent.isEnabled();
    expect(false).assertEqual(packingButtonEnabled);
    await driver.delayMs(500);
    done();
  })

  exit('手写绘制及保存图片');
}