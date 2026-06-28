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
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import { logger } from 'utils';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'MiniPlayerAnimation';
const TAG: string = '[MiniPlayerAnimation_Test]';
const DELAY_MS: number = 500;

/**
 * 【音乐播放转场一镜到底效果实现】自动化测试用例
 * 主要功能：音乐播放的Mini条播放栏在转场时的一镜到底动画是音乐播放器应用开发中常见的需求。本案例实现Mini条的一镜到底动画，如Mini条歌曲封面的缩放动画，Mini条的展开收起动画等。
 * 执行步骤：
 * 1.点击Mini条展开动画（动效需手工用例进行测试）
 * 2.点击全屏播放页左上角收起按钮的收起动画（动效需手工用例进行测试）
 * 3.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分时松手的自动向上回弹动画（动效需手工用例进行测试）
 * 4.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分时松手的自动向上回弹动画效果是否正常（动效需手工用例进行测试）
 * 5.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的下半部分时松手的自动向下收起动画（动效需手工用例进行测试）
 * 6.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分时松手的自动向下收起动画效果是否正常（动效需手工用例进行测试）
 */
export default function akiUsePracticeTest() {
  searchCaseClickIn('音乐播放转场一镜到底效果实现');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);
  // 全屏播放页Y轴位置
  let detailsPageYPosition = 0;
  // Mini条透明度
  let miniPlayerOpacity = 0;
  // 全屏播放页透明度
  let detailsPageOpacity = 0;
  // 歌曲封面图偏移量
  let miniImgOffsetSize = 0;
  // 歌曲封面图X轴偏移距离
  let miniImgOffsetX = 0;
  // 设备屏幕宽度
  let screenWidth = 0;
  // 设备屏幕高度
  let screenHeight = 0;
  // 全屏播放页左上角收起按钮和右上角分享按钮图标透明度
  let detailsPageTopOpacity = 0;
  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    detailsPageYPosition = data.data?.detailsPageYPosition;
    miniPlayerOpacity = data.data?.miniPlayerOpacity;
    detailsPageOpacity = data.data?.detailsPageOpacity;
    miniImgOffsetSize = data.data?.miniImgOffsetSize;
    miniImgOffsetX = data.data?.miniImgOffsetX;
    screenWidth = data.data?.screenWidth;
    screenHeight = data.data?.screenHeight;
    detailsPageTopOpacity = data.data?.detailsPageTopOpacity;
  })

  /**
   * 1.点击Mini条展开动画（动效需手工用例进行测试）
   */
  it(CASE + 'Mini条展开动画', 0, async (done: Function) => {
    // 1.全屏播放页会从底部自下而上做平移动画
    await driver.assertComponentExist(ON.id('mini'));
    // 点击Mini条
    let mini = await driver.findComponent(ON.id('mini'));
    await mini.click();
    await driver.delayMs(2000);
    // 断言平移动画结束后的位置，展开后位置为0
    expect(true).assertEqual(detailsPageYPosition === 0);
    // 2.Mini条会逐渐变透明，全屏播放页会从透明逐渐变到不透明
    // 断言Mini条变透明
    expect(true).assertEqual(miniPlayerOpacity === 0);
    // 断言全屏播放页不透明
    expect(true).assertEqual(detailsPageOpacity === 1);
    // 3.Mini条中歌曲封面图会逐渐放大并上移到全屏播放页水平居中位置
    // 断言歌曲封面图放大。歌曲封面尺寸变化量miniImgOffsetSize大于0说明封面图放大
    expect(true).assertEqual(miniImgOffsetSize > 0);
    // 断言歌曲封面图在全屏播放页水平居中位置=（屏幕宽度-歌曲封面图宽度（miniImgOffsetSize+MINI_IMG_SIZE 32）-图片两边外边距MINI_IMG_MARGIN_LEFT 12*2）/2
    expect(true).assertEqual(miniImgOffsetX === (screenWidth - (miniImgOffsetSize + 32) - 12 * 2) / 2);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 2.点击全屏播放页左上角收起按钮的收起动画（动效需手工用例进行测试）
   */
  it(CASE + '全屏播放页收起动画', 0, async (done: Function) => {
    // 1.全屏播放页会从顶部自上而下做平移动画
    await driver.assertComponentExist(ON.id('retract'));
    // 点击收起按钮
    let retract = await driver.findComponent(ON.id('retract'));
    await retract.click();
    await driver.delayMs(2000);
    // 断言平移动画结束后的位置，不同设备收起后位置不一样，这里断言大于0即认为收起
    expect(true).assertEqual(detailsPageYPosition > 0);
    // 2.Mini条会逐渐变不透明，全屏播放页会从不透明逐渐变到透明
    // 断言Mini条变不透明
    expect(true).assertEqual(miniPlayerOpacity === 1);
    // 断言全屏播放页透明
    expect(true).assertEqual(detailsPageOpacity === 0);
    // 3.全屏播放页中歌曲封面图会逐渐缩小并移动到Mini条里
    // 断言歌曲封面图缩小。歌曲封面尺寸变化量miniImgOffsetSize为0说明封面图已缩到最小
    expect(true).assertEqual(miniImgOffsetSize === 0);
    // 断言歌曲封面图移动到Mini条里，歌曲封面图X轴偏移距离miniImgOffsetX为0
    expect(true).assertEqual(miniImgOffsetX === 0);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 3.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分时松手的自动向上回弹动画（动效需手工用例进行测试）
   */
  it(CASE + '全屏播放页拖动到屏幕的上半部分时松手的向上回弹动画', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('mini'));
    // 点击Mini条，展开全屏播放页
    let mini = await driver.findComponent(ON.id('mini'));
    await mini.click();
    await driver.delayMs(2000);
    // 在全屏播放页拖动，并往下拉
    await driver.assertComponentExist(ON.id('detailsPage'));
    let detailsPage = await driver.findComponent(ON.id('detailsPage'));
    let rect = await detailsPage.getBounds();
    // 在屏幕上半部分滑动后松手（下拉滑动屏幕高度的1/3距离）
    let slideDistance = Math.floor(rect.top + vp2px(screenHeight / 3));
    await driver.swipe(rect.left, rect.top + 100, rect.left, slideDistance, 1000);
    await driver.delayMs(2000);
    // 全屏播放页会有向上回弹动画（根据全屏播放页Y轴位置进行判断）
    expect(true).assertEqual(detailsPageYPosition === 0);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 4.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分时松手的自动向上回弹动画效果是否正常（动效需手工用例进行测试）
   */
  it(CASE + '全屏播放页拖动到屏幕的上半部分时松手的向上回弹动画效果', 0, async (done: Function) => {
    // 在全屏播放页拖动，并往下拉
    await driver.assertComponentExist(ON.id('detailsPage'));
    let detailsPage = await driver.findComponent(ON.id('detailsPage'));
    let rect = await detailsPage.getBounds();
    // 在屏幕上半部分滑动后松手（下拉滑动屏幕高度的1/3距离）
    let slideDistance = Math.floor(rect.top + vp2px(screenHeight / 3));
    await driver.swipe(rect.left, rect.top + 100, rect.left, slideDistance, 1000);
    await driver.delayMs(2000);
    // 1.歌曲封面图会逐渐放大并水平居中（只能确认动效结束后，歌曲封面图是否放大并水平居中）
    // 断言歌曲封面图放大。歌曲封面尺寸变化量miniImgOffsetSize大于0说明封面图放大
    expect(true).assertEqual(miniImgOffsetSize > 0);
    // 断言歌曲封面图在全屏播放页水平居中位置=（屏幕宽度-歌曲封面图宽度（miniImgOffsetSize+MINI_IMG_SIZE）-图片两边外边距MINI_IMG_MARGIN_LEFT）/2
    expect(true).assertEqual(miniImgOffsetX === (screenWidth - (miniImgOffsetSize + 32) - 12 * 2) / 2);
    // 2.全屏播放页左上角收起按钮和右上角分享按钮图标透明度由透明变成不透明（只能确认动效结束后，透明度是否为1）
    expect(true).assertEqual(detailsPageTopOpacity === 1);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 5.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的下半部分时松手的自动向下收起动画（动效需手工用例进行测试）
   */
  it(CASE + '全屏播放页拖动到屏幕的下半部分时松手的向下收起动画', 0, async (done: Function) => {
    // 在全屏播放页拖动，并往下拉。可以看到全屏播放页会有向下收起动画
    await driver.assertComponentExist(ON.id('detailsPage'));
    let detailsPage = await driver.findComponent(ON.id('detailsPage'));
    let rect = await detailsPage.getBounds();
    // 在屏幕下半部分滑动后松手（下拉滑动屏幕高度的2/3距离）
    let slideDistance = Math.floor(rect.top + vp2px(screenHeight / 3 * 2));
    await driver.swipe(rect.left, rect.top + 100, rect.left, slideDistance, 1000);
    await driver.delayMs(2000);
    // 全屏播放页会有向下收起动画（根据全屏播放页Y轴位置进行判断，不同设备收起后位置不一样，这里断言大于0即认为收起）
    expect(true).assertEqual(detailsPageYPosition > 0);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 6.在全屏播放页，手指按住全屏播放页向下拖动，当全屏播放页拖动到屏幕的上半部分时松手的自动向下收起动画效果是否正常（动效需手工用例进行测试）
   */
  it(CASE + '全屏播放页拖动到屏幕的上半部分时松手的向下收起动画效果', 0, async (done: Function) => {
    // 点击Mini条展开到全屏播放页
    await driver.assertComponentExist(ON.id('mini'));
    let mini = await driver.findComponent(ON.id('mini'));
    await mini.click();
    await driver.delayMs(2000);
    await driver.assertComponentExist(ON.id('detailsPage'));
    let detailsPage = await driver.findComponent(ON.id('detailsPage'));
    let rect = await detailsPage.getBounds();
    // 在屏幕下半部分滑动后松手（下拉滑动屏幕高度的2/3距离）
    let slideDistance = Math.floor(rect.top + vp2px(screenHeight / 3 * 2));
    await driver.swipe(rect.left, rect.top + 100, rect.left, slideDistance, 1000);
    await driver.delayMs(2000);
    // 1.歌曲封面图会逐渐缩小并往左侧偏移到Mini条位置。断言歌曲封面图缩小。歌曲封面尺寸变化量miniImgOffsetSize为0说明封面图已缩到最小
    expect(true).assertEqual(miniImgOffsetSize === 0);
    // 断言歌曲封面图移动到Mini条里，歌曲封面图X轴偏移距离miniImgOffsetX为0
    expect(true).assertEqual(miniImgOffsetX === 0);
    // 2.全屏播放页透明度逐渐变低
    expect(true).assertEqual(detailsPageOpacity === 0);
    // 3.Mini条从透明逐渐变成不透明
    expect(true).assertEqual(miniPlayerOpacity === 1);
    done();
  })

  exit('音乐播放转场一镜到底效果实现');
}