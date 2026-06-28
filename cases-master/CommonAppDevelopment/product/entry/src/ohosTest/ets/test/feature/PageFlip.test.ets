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
import { Driver, ON, UiDirection } from '@ohos.UiTest';
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'PageFilp'; // 案例名称
const TAG: string = '[PageFilp_Test]';

/**
 * 【阅读翻页方式案例】自动化测试用例
 * 1. 进入模块即是左右翻页模式。
 * 2. 点击屏幕中间区域弹出上下菜单。
 * 3. 点击设置按钮，弹出翻页方式切换按钮，点击可切换翻页方式。
 * 4. 左右翻页方式可点击翻页，也可滑动翻页，点击屏幕左边1/3区域向左翻页，点击中间1/3区域弹出菜单，点击屏幕右边1/3区域向右翻页。
 * 5. 上下翻页方式只可上下滑动翻页。
 * 6. 覆盖翻页方式可点击翻页，也可滑动翻页，点击屏幕左边1/3区域向左翻页，点击中间1/3区域弹出菜单，点击屏幕右边1/3区域向右翻页。
 * 7. 点击设置按钮，弹出字体变小按钮，点击按钮文本会相应变小。
 * 8. 点击设置按钮，弹出背景颜色按钮，点击按钮可切换背景色。
 * 9. 点击设置按钮，弹出阅读背景按钮，点击按钮可有阅读背景图片。
 * 10. 点击设置按钮，弹出文本朗读按钮，点击按钮朗读控件起播，拉起播放器面板并开始播放。
 * 11. 可点击播放面板中的上一页、下一页按钮，或当前页播放完毕自动跳到下一页，阅读文本会同步跳到对应页面。
 */
export default function pageFlipTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('阅读翻页方式案例');

  let driver = Driver.create();

  /**
   * 关联用例: 进入模块即是左右翻页模式。
   * 执行步骤:
   * 1. 左右翻页方式可点击翻页，也可滑动翻页。
   * 2. 点击屏幕左边1/3区域向左翻页，点击中间1/3区域弹出菜单，点击屏幕右边1/3区域向右翻页。
   */
  it('左右翻页模式', 0, async (done: Function) => {
    // 获取设备的大小
    let size = await driver.getDisplaySize();
    const minpointx = size.x / 3 - 30;
    const maxPointx = size.x - 30;
    const middPointx = size.x / 2;
    const middPointy = size.y / 2;

    logger.info(TAG, `${CASE}_左右翻页模式 begin`);

    // 滑动向右翻页
    await driver.fling(UiDirection.RIGHT, 4000);
    await driver.delayMs(1000);
    await driver.fling(UiDirection.RIGHT, 4000);
    await driver.delayMs(1000);

    // 判断是否成功滑动右翻页
    await driver.assertComponentExist(ON.id('pageIndex2'));

    // 滑动向左翻页
    await driver.fling(UiDirection.LEFT, 4000);
    await driver.delayMs(1000);

    // 判断是否成功滑动左翻页
    await driver.assertComponentExist(ON.id('pageIndex1'));

    // 点击屏幕右边1/3区域向右翻页
    await driver.click(maxPointx , middPointy);
    await driver.delayMs(1000);

    // 判断是否成功点击右翻页
    await driver.assertComponentExist(ON.id('pageIndex2'));

    // 点击屏幕左边1/3区域向左翻页
    await driver.click(minpointx, middPointy);
    await driver.delayMs(1000);
    await driver.click(minpointx, middPointy);
    await driver.delayMs(1000);

    // 判断是否成功点击左翻页
    await driver.assertComponentExist(ON.id('pageIndex0'));

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_左右翻页模式 end`);

    done();
  })

  /**
   * 关联用例: 上下翻页模式。
   * 执行步骤:
   * 1. 弹出菜单，点击设置按钮，点击上下翻页按钮即切换为上下翻页模式。
   * 2. 上下翻页方式只可上下滑动翻页。
   */
  it('上下翻页模式', 0, async (done: Function) => {
    // 点击设置按钮
    let clickSetting = await driver.findComponent(ON.id('setting'));
    await clickSetting.click();
    await driver.delayMs(1000);

    // 点击上下翻页按钮
    let clickDownTop = await driver.findComponent(ON.text('上下翻页'));
    await clickDownTop.click();
    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_上下翻页模式 begin`);

    // 向下滑动
    const scrollPart = await driver.findComponent(ON.id('pageIndex1'));
    let beforeHeight = (await scrollPart.getBounds()).top;
    await driver.swipe(200, 2000, 200, 100, 1000);
    await driver.delayMs(2000);
    let afterHeight = (await scrollPart.getBounds()).top;
    let isScroll = beforeHeight > afterHeight ? true : false;

    // 判断是否成功向下滑动翻页
    expect(isScroll).assertEqual(true);
    await driver.delayMs(1000);

    // 向上滑动
    beforeHeight = (await scrollPart.getBounds()).top;
    await driver.swipe(200, 100, 200, 2000, 1000);
    await driver.delayMs(2000);
    afterHeight = (await scrollPart.getBounds()).top
    isScroll = beforeHeight < afterHeight ? true : false;

    // 判断是否成功向上滑动翻页
    expect(isScroll).assertEqual(true);

    logger.info(TAG, `${CASE}_上下翻页模式 end`);

    done();
  })

  /**
   * 关联用例: 覆盖翻页模式。
   * 执行步骤:
   * 1. 覆盖翻页方式可点击翻页，也可滑动翻页。
   * 2. 点击屏幕左边1/3区域向左翻页，点击中间1/3区域弹出菜单，点击屏幕右边1/3区域向右翻页。
   */
  it('覆盖翻页模式', 0, async (done: Function) => {
    // 获取设备的大小
    let size = await driver.getDisplaySize();
    const minpointx = size.x / 3 - 30;
    const maxPointx = size.x - 30;
    const middPointx = size.x / 2;
    const middPointy = size.y / 2;

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    let clickSetting = await driver.findComponent(ON.id('setting'));
    await clickSetting.click();
    await driver.delayMs(1000);

    // 点击覆盖翻页按钮
    let clickCover = await driver.findComponent(ON.text('覆盖翻页'));
    await clickCover.click();
    await driver.delayMs(1000);

    logger.info(TAG, `${CASE}_覆盖翻页模式 begin`);

    // 滑动向右翻页
    await driver.fling(UiDirection.RIGHT, 4000);
    await driver.delayMs(1000);
    await driver.fling(UiDirection.RIGHT, 4000);
    await driver.delayMs(1000);

    // 判断是否成功滑动右翻页
    await driver.assertComponentExist(ON.id('pageIndex3'));

    // 滑动向左翻页
    await driver.fling(UiDirection.LEFT, 4000);
    await driver.delayMs(1000);

    // 判断是否成功滑动左翻页
    await driver.assertComponentExist(ON.id('pageIndex2'));

    // 点击屏幕右边1/3区域向右翻页
    await driver.click(maxPointx , middPointy);
    await driver.delayMs(1000);
    await driver.click(maxPointx , middPointy);
    await driver.delayMs(1000);

    // 判断是否成功点击右翻页
    await driver.assertComponentExist(ON.id('pageIndex4'));

    // 点击屏幕左边1/3区域向左翻页
    await driver.click(minpointx, middPointy);
    await driver.delayMs(1000);
    await driver.click(minpointx, middPointy);
    await driver.delayMs(1000);
    await driver.click(minpointx, middPointy);
    await driver.delayMs(1000);

    // 判断是否成功点击左翻页
    await driver.assertComponentExist(ON.id('pageIndex1'));

    logger.info(TAG, `${CASE}_覆盖翻页模式 end`);

    done();
  })


  /**
   * 关联用例: 字体变小。
   * 执行步骤:
   * 1. 弹出菜单，点击设置按钮。
   * 2. 点击字体变小按钮文本会相应变小。
   */
  it('字体变小', 0, async (done: Function) => {
    let isTextSize: boolean = false;
    emitter.on({
      eventId: 0, priority: 0
    }, (data: emitter.EventData) => {
      isTextSize = data.data?.isTextSize;
    })

    // 获取设备的大小
    let size = await driver.getDisplaySize();
    const middPointx = size.x / 2;
    const middPointy = size.y / 2;

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    let clickSetting = await driver.findComponent(ON.id('setting'));
    await clickSetting.click();
    await driver.delayMs(1000);

    // 点击字体变小按钮
    let clickFontSize = await driver.findComponent(ON.id('fontSize'));
    await clickFontSize.click();
    logger.info(TAG, `${CASE}_点击字体变小按钮`);
    await driver.delayMs(3000);

    // 判断是否点击字体变小按钮文本字体变小
    expect(isTextSize).assertEqual(true);

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    await clickSetting.click();
    await driver.delayMs(1000);

    // 再次点击字体变小按钮，文本字体大小会变为默认大小
    await clickFontSize.click();
    await driver.delayMs(1000);
    done();
  })

  /**
   * 关联用例: 背景颜色。
   * 执行步骤:
   * 1. 弹出菜单，点击设置按钮。
   * 2. 点击背景颜色按钮可切换背景色。
   */
  it('背景颜色', 0, async (done: Function) => {
    let isbgColor: boolean = false;
    emitter.on({
      eventId: 0, priority: 0
    }, (data: emitter.EventData) => {
      isbgColor = data.data?.isbgColor;
    })

    // 获取设备的大小
    let size = await driver.getDisplaySize();
    const middPointx = size.x / 2;
    const middPointy = size.y / 2;

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    let clickSetting = await driver.findComponent(ON.id('setting'));
    await clickSetting.click();
    await driver.delayMs(1000);

    // 点击背景颜色按钮
    let clickBackgroundColor = await driver.findComponent(ON.id('bgColor'));
    await clickBackgroundColor.click();
    logger.info(TAG, `${CASE}_点击背景颜色按钮`);
    await driver.delayMs(3000);

    // 判断是否点击背景颜色按钮换背景色
    expect(isbgColor).assertEqual(true);

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    await clickSetting.click();
    await driver.delayMs(1000);

    // 再次点击背景颜色按钮，阅读背景色恢复为默认背景
    await clickBackgroundColor.click();
    await driver.delayMs(1000);
    done();
  })

  /**
   * 关联用例: 阅读背景。
   * 执行步骤:
   * 1. 弹出菜单，点击设置按钮。
   * 2. 点击阅读背景按钮可有阅读背景图片。
   */
  it('阅读背景', 0, async (done: Function) => {
    let isbgImage: boolean = false;
    emitter.on({
      eventId: 0, priority: 0
    }, (data: emitter.EventData) => {
      isbgImage = data.data?.isbgImage;
    })

    // 获取设备的大小
    let size = await driver.getDisplaySize();
    const middPointx = size.x / 2;
    const middPointy = size.y / 2;

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    let clickSetting = await driver.findComponent(ON.id('setting'));
    await clickSetting.click();
    await driver.delayMs(1000);

    // 点击阅读背景按钮可有阅读背景图片
    let clickBgImage = await driver.findComponent(ON.id('bgImage'));
    await clickBgImage.click();
    logger.info(TAG, `${CASE}_点击阅读背景按钮`);
    await driver.delayMs(3000);

    // 判断是否点击背景阅读按钮切换背景图片
    expect(isbgImage).assertEqual(true);


    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    await clickSetting.click();
    await driver.delayMs(1000);

    // 再次点击阅读背景按钮，无阅读背景图片
    await clickBgImage.click();
    await driver.delayMs(2000);
    done();
  })

  /**
   * 关联用例: 文本朗读。
   * 执行步骤:
   * 1. 弹出菜单，点击设置按钮。
   * 2. 点击文本朗读按钮朗读控件起播，拉起播放器面板并开始播放。
   */
  it('文本朗读', 0, async (done: Function) => {
    let isTextReader: boolean = false;
    emitter.on({
      eventId: 0, priority: 0
    }, (data: emitter.EventData) => {
      isTextReader = data.data?.isTextReader;
    })

    // 获取设备的大小
    let size = await driver.getDisplaySize();
    const middPointx = size.x / 2;
    const middPointy = size.y / 2;

    // 点击中间1/3区域弹出菜单
    await driver.click(middPointx, middPointy);
    await driver.delayMs(1000);

    // 点击设置按钮
    let clickSetting = await driver.findComponent(ON.id('setting'));
    await clickSetting.click();
    await driver.delayMs(1000);

    // 点击文本朗读按钮
    let clickFontSize = await driver.findComponent(ON.id('textReading'));
    await clickFontSize.click();
    logger.info(TAG, `${CASE}_点击文本阅读按钮`);
    await driver.delayMs(1000);

    // 判断是否点击文本阅读按钮拉起朗读面板
    expect(isTextReader).assertEqual(true);
    await driver.delayMs(2000);

    done();
  })

  exit('阅读翻页方式案例');
}
