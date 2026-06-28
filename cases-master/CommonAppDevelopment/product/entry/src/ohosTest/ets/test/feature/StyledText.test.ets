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
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { Component, Driver, ON, UIEventObserver, UIElementInfo } from '@kit.TestKit';
import { expect, it } from '@ohos/hypium';
import exit from '../common/Exit.test';

/**
 * 【Text实现部分文本高亮和超链接样式】自动化测试用例
 *
 * 执行步骤：
 * 1. 进入Text实现部分文本高亮和超链接样式主页。
 * 2. 依次点击StyledString和Text&Span页签，对应页签高亮，页面切换至对应页签内容，列表正常显示，列表正文中超链接高亮。（高亮效果需要手工用例查看）
 * 3. 长按Text&Span页的列表项，列表项背景色变化，弹出提示"仅演示，可自行实现长按分享、点赞、收藏功能"。（背景色变化需要手工用例验证）
 * 4. 点击StyledString页签切换页面，长按列表项，列表项背景色变化，弹出提示"仅演示，可自行实现长按分享、点赞、收藏功能"。（背景色变化需要手工用例验证）
 */
export default function styledTextTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('Text实现部分文本高亮和超链接样式');

  const driver: Driver = Driver.create();

  it('验证Tab切换功能', 0, async (done: Function) => {
    // 断言两个页签存在
    await driver.assertComponentExist(ON.text('Text&Span'));
    await driver.assertComponentExist(ON.text('StyledString'));
    // 获取"Text&Span"组件和"StyledString"组件
    const textAndSpanTabBar: Component = await driver.findComponent(ON.text('Text&Span'));
    const styledStringTabBar: Component = await driver.findComponent(ON.text('StyledString'));

    // 点击"StyledString"组件
    await styledStringTabBar.click();
    await driver.delayMs(1000);
    // 断言"StyledString"页的列表项存在
    await driver.assertComponentExist(ON.id('styledStringItem0'));
    // 断言此时不存在"Text&Span"页的列表项
    let textAndSpanItem = await driver.findComponent(ON.id('textAndSpanItem0'));
    expect(textAndSpanItem).assertEqual(null);

    // 点击"Text&Span"组件
    await textAndSpanTabBar.click();
    await driver.delayMs(1000);
    // 断言"Text&Span"页的列表项存在
    await driver.assertComponentExist(ON.id('textAndSpanItem0'));
    // 断言此时不存在"Text&Span"页的列表项
    let styledStringItem = await driver.findComponent(ON.id('styledStringItem0'));
    expect(styledStringItem).assertEqual(null);

    done();
  })

  it('Text&Span页列表项长按提示功能', 0, async (done: Function) => {
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let toast = '仅演示，可自行实现长按分享、点赞、收藏功能';
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual(toast);
    };
    observer.once('toastShow', callback);

    // 断言列表项存在
    await driver.assertComponentExist(ON.id('textAndSpanItem0'));
    // 长按"列表项"
    await driver.longClick(500, 800);
    await driver.delayMs(1000);

    done();
  })

  it('StyledString页列表项长按提示功能', 0, async (done: Function) => {
    const observer: UIEventObserver = await driver.createUIEventObserver();
    let toast = '仅演示，可自行实现长按分享、点赞、收藏功能';
    let callback = (UIElementInfo: UIElementInfo) => {
      expect(UIElementInfo.text).assertEqual(toast);
    };
    observer.once('toastShow', callback);

    // 断言"StyledString"页签存在
    await driver.assertComponentExist(ON.text('StyledString'));
    // 获取并点击StyledString"组件
    const styledStringTabBar: Component = await driver.findComponent(ON.text('StyledString'));
    // 点击"StyledString"组件
    await styledStringTabBar.click();
    await driver.delayMs(1000);

    // 断言列表项存在
    await driver.assertComponentExist(ON.id('styledStringItem0'));
    // 长按"列表项"
    await driver.longClick(500, 800);
    await driver.delayMs(1000);

    done();
  })

  // 返回瀑布流主页面
  exit('Text实现部分文本高亮和超链接样式');
}