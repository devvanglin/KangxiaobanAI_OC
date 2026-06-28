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
 * 【视频卡片和列表区域的联动滚动】自动化测试用例
 * 主要功能：本示例使用Scroll和List组件嵌套，通过List组件的滚动控制器和nestedScroll属性实现了视频卡片和列表区域的联动滚动场景。
 * 执行步骤：
 * 1. 在列表区域向上循环滑动，每次滑动一个列表项的高度，滑动距离不超过页面的可滑动距离时页面滚动。列表内不滚动。页面滚动到顶部后视频隐藏，继续向上滑动视频卡片吸顶，列表向上滚动。
 * 2. 向下先滑动一个列表项的高度，列表滚动，页面不滚动，继续向下滑动，滑动次数与向上循环滑动的次数相同，滑动结束后列表滚动至头部，视频显示。
 * 3. 点击播放按钮，视频播放时间变化，按钮变为暂停按钮。（视频播放状态和进度条需手工用例进行测试）
 * 4. 点击暂停按钮，视频播放时间停止变化，按钮变为播放按钮。（视频播放状态和进度条需手工用例进行测试）
 * 5. 点击下一条按钮，视频播放时间重置为00:00，视频卡片的新闻标题与切换的新闻标题一致。（列表项高亮是否切换需手工用例进行测试）
 * 6. 点击上一条按钮，视频播放时间重置为00:00，视频卡片的新闻标题与切换的新闻标题一致，处于第一条时再次点击上一条，提示“已经是第一条数据了”。（列表项高亮是否切换需手工用例进行测试）
 * 7. 点击列表第5个列表项，视频播放时间重置为00:00，视频卡片的新闻标题与第5个列表项中的新闻标题一致，同时第5个列表项在列表显示区域滚动至第四条位置。点击第3个列表项，列表滚动至头部。（列表项高亮是否切换需手工用例进行测试）
 */
export default function videoLinkageListTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('视频卡片和列表区域的联动滚动');

  const driver = Driver.create();
  let flingUpMaxValue = vp2px(160); // 页面的可滑动距离
  let itemHeight = vp2px(40); // 单个列表项高度
  let listCenterX: number = 0; // 列表水平中心x坐标
  let listTop: number = 0; // 列表初始顶部坐标
  let count = 0; // 向上循环滑动次数

  it('验证向上的嵌套滚动和视频卡片吸顶效果', 0, async (done: Function) => {
    await driver.delayMs(1000);
    // 断言存在List组件
    await driver.assertComponentExist(ON.id('videoLinkageListList'));
    let listComponent = await driver.findComponent(ON.id('videoLinkageListList'));
    // 获取列表区域
    let listRect = await listComponent.getBounds();
    listCenterX = (listRect.right + listRect.left) / 2;
    listTop = listRect.top;

    // 循环向上滑动直到滑动距离超过页面的可滑动距离
    while (count * itemHeight <= flingUpMaxValue) {
      await driver.swipe(listCenterX, listTop + itemHeight, listCenterX, listTop, 200);
      // 已滑动距离小于页面可滑动距离，继续向上滑动
      if ((count + 1) * itemHeight <= flingUpMaxValue) {
        // 向上滑动后断言第一个列表项存在，验证列表内部未发生滚动
        await driver.assertComponentExist(ON.id('videoLinkageListItem0'));
      }
      count++;
    }
    // 断言页面滑动到顶后视频消失
    let videoComponent = await driver.findComponent(ON.id('videoLinkageListVideo'));
    expect(videoComponent).assertEqual(null);
    // 断言存在视频卡片
    await driver.assertComponentExist(ON.id('newsVideoView'));
    let newsVideoView = await driver.findComponent(ON.id('newsVideoView'));
    // 获取此时的视频卡片区域
    let newsVideoViewRectBefore = await newsVideoView.getBounds();

    // 在列表区域向上滑动一个列表项高度的距离
    await driver.swipe(listCenterX, listTop + itemHeight, listCenterX, listTop, 200);
    // 断言第一个列表项消失
    let firstItem = await driver.findComponent(ON.id('videoLinkageListItem0'));
    expect(firstItem).assertEqual(null);
    // 获取滑动后的视频卡片区域
    let newsVideoViewRectAfter = await newsVideoView.getBounds();
    // 断言页面滚动到顶部后继续向上滑动视频卡片的顶部坐标不变
    expect(newsVideoViewRectBefore.top).assertEqual(newsVideoViewRectAfter.top);

    done();
  })

  it('验证向下嵌套滚动效果', 0, async (done: Function) => {
    await driver.delayMs(500);
    // 断言存在List组件
    await driver.assertComponentExist(ON.id('videoLinkageListList'));
    let listComponent = await driver.findComponent(ON.id('videoLinkageListList'));
    let listRectBefore = await listComponent.getBounds();
    // 断言存在ListItem组件
    await driver.assertComponentExist(ON.type('ListItem'));
    let listItemsBefore = await driver.findComponents(ON.type('ListItem'));
    let firstIdBefore = await listItemsBefore[0].getId();

    // 在列表区域向下滑动一个列表项高度的距离
    await driver.swipe(listCenterX, listTop, listCenterX, listTop + itemHeight, 200);
    // 断言滑动前后列表中的第一个列表项发生变化，且列表的顶部坐标不变，验证列表内部滚动且页面不滚动
    let listItemsAfter = await driver.findComponents(ON.type('ListItem'));
    let firstIdAfter = await listItemsAfter[0].getId();
    expect(firstIdBefore === firstIdAfter).assertEqual(false);
    let listRectAfter = await listComponent.getBounds();
    expect(listRectBefore.top).assertEqual(listRectAfter.top);
    // 断言视频不存在
    let videoComponent = await driver.findComponent(ON.id('videoLinkageListVideo'));
    expect(videoComponent).assertEqual(null);
    await driver.delayMs(200);

    // 循环向下滑动相同次数
    while (count > 0) {
      await driver.swipe(listCenterX, listTop, listCenterX, listTop + itemHeight, 200);
      count--;
    }
    // 滑动结束后断言第一个列表项存在
    await driver.assertComponentExist(ON.id('videoLinkageListItem0'));
    // 滑动结束后断言视频存在
    await driver.assertComponentExist(ON.id('videoLinkageListVideo'));
    done();
  })

  // 视频播放状态和进度条需手工用例进行测试
  it('验证播放', 0, async (done: Function) => {
    await driver.delayMs(500);
    // 断言存在视频当前时间文本组件
    await driver.assertComponentExist(ON.id('currentTime'));
    let currentTimeComponent = await driver.findComponent(ON.id('currentTime'));
    let initCurrentTime = await currentTimeComponent.getText();
    expect(initCurrentTime).assertEqual('00:00');
    // 断言存在播放按钮
    await driver.assertComponentExist(ON.id('play'));
    let playComponent = await driver.findComponent(ON.id('play'));
    await playComponent.click();
    // 1s后断言当前时间文本组件显示时间不为00:00（视频是否正在播放需要手工观测）
    await driver.delayMs(1000);
    let currentTime = await currentTimeComponent.getText();
    expect(currentTime !== '00:00').assertEqual(true);
    // 断言存在暂停按钮
    await driver.assertComponentExist(ON.id('pause'));
    done();
  })

  // 视频播放状态和进度条需手工用例进行测试
  it('验证暂停', 0, async (done: Function) => {
    // 断言存在暂停按钮
    await driver.assertComponentExist(ON.id('pause'));
    let pauseComponent = await driver.findComponent(ON.id('pause'));
    await pauseComponent.click();
    await driver.delayMs(1000);
    // 断言存在播放按钮
    await driver.assertComponentExist(ON.id('play'));
    // 断言存在视频当前时间文本组件
    await driver.assertComponentExist(ON.id('currentTime'));
    let currentTimeComponent = await driver.findComponent(ON.id('currentTime'));
    // 暂停后断言当前时间文本不再变化
    let currentTimeBefore = await currentTimeComponent.getText();
    await driver.delayMs(1000);
    let currentTimeAfter = await currentTimeComponent.getText();
    expect(currentTimeBefore).assertEqual(currentTimeAfter);
    done();
  })

  // 列表项高亮是否切换需手工用例进行测试
  it('验证切换下一条 ', 0, async (done: Function) => {
    // 断言存在下一条按钮
    await driver.assertComponentExist(ON.id('next'));
    let nextComponent = await driver.findComponent(ON.id('next'));
    await nextComponent.click();
    await driver.delayMs(1000);

    // 断言存在当前时间文本组件
    await driver.assertComponentExist(ON.id('currentTime'));
    let currentTimeComponent = await driver.findComponent(ON.id('currentTime'));
    let currentTime = await currentTimeComponent.getText();
    // 断言当前时间文本重置为00:00
    expect(currentTime).assertEqual('00:00');

    // 断言存在新闻标题组件
    await driver.assertComponentExist(ON.id('newsName'));
    let currentNewsNameComponent = await driver.findComponent(ON.id('newsName'));
    let currentNewsName = await currentNewsNameComponent.getText();
    // 断言存在第二个列表项和其中的标题文本
    await driver.assertComponentExist(ON.id('videoLinkageListItem1'));
    await driver.assertComponentExist(ON.type('Text').within(ON.id('videoLinkageListItem1')));
    let secondItemNewsNameComponent = await driver.findComponent(ON.type('Text').within(ON.id('videoLinkageListItem1')));
    let secondItemNewsName = await secondItemNewsNameComponent.getText();
    // 断言新闻标题文本与第二个列表项中的标题文本一致
    expect(currentNewsName).assertEqual(secondItemNewsName);

    done();
  })

  // 列表项高亮是否切换需手工用例进行测试
  it('验证切换上一条 ', 0, async (done: Function) => {
    // 断言存在上一条按钮
    await driver.assertComponentExist(ON.id('prev'));
    let prevComponent = await driver.findComponent(ON.id('prev'));
    await prevComponent.click();
    await driver.delayMs(1000);

    // 断言存在当前时间文本组件
    await driver.assertComponentExist(ON.id('currentTime'));
    let currentTimeComponent = await driver.findComponent(ON.id('currentTime'));
    let currentTime = await currentTimeComponent.getText();
    // 断言当前时间文本重置为00:00
    expect(currentTime).assertEqual('00:00');

    // 断言存在新闻标题组件
    await driver.assertComponentExist(ON.id('newsName'));
    let currentNewsNameComponent = await driver.findComponent(ON.id('newsName'));
    let currentNewsName = await currentNewsNameComponent.getText();
    // 断言存在第一个列表项和其中的标题文本
    await driver.assertComponentExist(ON.id('videoLinkageListItem0'));
    await driver.assertComponentExist(ON.type('Text').within(ON.id('videoLinkageListItem0')));
    let secondItemNewsNameComponent = await driver.findComponent(ON.type('Text').within(ON.id('videoLinkageListItem0')));
    let secondItemNewsName = await secondItemNewsNameComponent.getText();
    // 断言新闻标题文本与第一个列表项中的标题文本一致
    expect(currentNewsName).assertEqual(secondItemNewsName);
    await driver.delayMs(200);

    // 处于第一条时再次点击上一条按钮，断言提示"已经是第一条数据了"
    await prevComponent.click();
    await driver.delayMs(200);
    await driver.assertComponentExist(ON.text('已经是第一条数据了'));

    done();
  })

  // 列表项高亮是否切换需手工用例进行测试
  it('验证点击列表项切换当前播放', 0, async (done: Function) => {
    await driver.delayMs(500);
    // 断言存在第4个列表项，下标为3
    await driver.assertComponentExist(ON.id('videoLinkageListItem3'));
    let fourthItem = await driver.findComponent(ON.id('videoLinkageListItem3'));
    let fourthItemRect = await fourthItem.getBounds();

    // 断言存在第5个列表项，下标为4
    await driver.assertComponentExist(ON.id('videoLinkageListItem4'));
    let fifthItem = await driver.findComponent(ON.id('videoLinkageListItem4'));
    let fifthItemRectBefore = await fifthItem.getBounds();
    await fifthItem.click();
    await driver.delayMs(1000);
    let fifthItemRectAfter = await fifthItem.getBounds();
    // 断言点击第5个列表项后，该项的顶部坐标与第4个列表项的顶部坐标相等
    expect(fifthItemRectBefore.top !== fifthItemRectAfter.top && fifthItemRectAfter.top === fourthItemRect.top).assertEqual(true);

    // 断言存在新闻标题组件
    await driver.assertComponentExist(ON.id('newsName'));
    let currentNewsNameComponent = await driver.findComponent(ON.id('newsName'));
    let currentNewsName = await currentNewsNameComponent.getText();
    // 断言第5个列表项中的标题文本存在
    await driver.assertComponentExist(ON.id('videoLinkageListItem4'));
    await driver.assertComponentExist(ON.type('Text').within(ON.id('videoLinkageListItem4')));
    let fifthItemNewsNameComponent = await driver.findComponent(ON.type('Text').within(ON.id('videoLinkageListItem4')));
    let fifthItemNewsName = await fifthItemNewsNameComponent.getText();
    // 断言新闻标题文本与第5个列表项中的标题文本一致
    expect(currentNewsName).assertEqual(fifthItemNewsName);

    // 断言存在当前时间文本组件
    await driver.assertComponentExist(ON.id('currentTime'));
    let currentTimeComponent = await driver.findComponent(ON.id('currentTime'));
    let currentTime = await currentTimeComponent.getText();
    // 断言当前时间文本重置为00:00
    expect(currentTime).assertEqual('00:00');

    // 断言存在第3个列表项，下标为2
    await driver.assertComponentExist(ON.id('videoLinkageListItem2'));
    let thirdItem = await driver.findComponent(ON.id('videoLinkageListItem2'));
    await thirdItem.click();
    await driver.delayMs(1000);
    // 断言点击后第一个列表项存在，列表滚动到头部
    await driver.assertComponentExist(ON.id('videoLinkageListItem0'));

    done();
  })

  exit('视频卡片和列表区域的联动滚动');
}