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
import exit from '../common/Exit.test';

const CASE: string = 'VideoCreateGif';   // 案例名称
const CASE_NAME: string = '视频截取gif图'; // 案例中文名称

/**
 * 【视频截取gif图】自动化测试用例
 * 1.点击宫格页面中的视频项能正常打开视频播放
 * 2.点击视频播放页的gif按钮能正常打开截取gif页面
 * 3.调整视频的选择范围
 * 4.生成gif图片
 * 5.gif保存至图库
 * 6.点击视频播放页面的返回按钮
 * 7.点击生成gif页面的返回按钮
 * 8.点击生成gif页面的返回按钮
 */
export default function
videoCreateGifTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  let driver = Driver.create();

  // 点击宫格页面中的视频项能正常打开视频播放
  clickVideoItem(driver);

  // 点击视频播放页的gif按钮能正常打开截取gif页面
  clickGifButton(driver);

  // 调整视频的选择范围
  selectTimeFrame(driver);

  // 生成gif图片
  createGif(driver);

  // gif保存至图库
  saveGif(driver);

  // 点击视频播放页面的返回按钮
  clickBackInVideoPlayPage(driver);

  // 点击截取gif页面的返回按钮
  clickBackInSelectTimeFramePage(driver);

  // 点击生成gif页面的返回按钮
  clickBackInCreateGifPage(driver);

  // 退出案例
  exit(CASE_NAME);
}

/**
 * 关联用例：点击宫格页面中的视频项能正常打开视频播放
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.判断id为video_x_component的Component的isEnabled是否为true，如果为true说明正在播放，这里isEnabled与isPlaying保持相同的值。
 * 3.返回宫格页面。
 * 4.点击"在线视频截取gif"的视频，打开视频播放页面。
 * 5.判断id为video_x_component的Component的isEnabled是否为true，如果为true说明正在播放，这里isEnabled与isPlaying保持相同的值。
 */
function clickVideoItem(driver: Driver) {
  it(CASE + '_点击宫格页面中的视频项能正常打开视频播放', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const firstVideoItemComponent = await driver.findComponent(ON.id('first_video'));
    await firstVideoItemComponent.click();

    await driver.delayMs(3000);

    // 判断id为video_x_component的Component的isEnabled是否为true，如果为true说明正在播放，这里isEnabled与isPlaying保持相同的值
    const firstXComponent = await driver.findComponent(ON.id('video_x_component'));
    let isPlaying = await firstXComponent.isEnabled();
    expect(isPlaying).assertEqual(true);

    await driver.pressBack();
    await driver.delayMs(1000);

    // 点击"在线视频截取gif"的视频
    const secondVideoItemComponent = await driver.findComponent(ON.id('second_video'));
    await secondVideoItemComponent.click();

    await driver.delayMs(8000);

    // 判断id为video_x_component的Component的isEnabled是否为true，如果为true说明正在播放，这里isEnabled与isPlaying保持相同的值
    const xComponent = await driver.findComponent(ON.id('video_x_component'));
    isPlaying = await xComponent.isEnabled();
    expect(isPlaying).assertEqual(true);

    await driver.pressBack();
    await driver.delayMs(2000);

    done();
  })
}

/**
 * 关联用例：点击视频播放页的gif按钮能正常打开截取gif页面
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击"gif"按钮，打开截取gif页面。
 * 3.判断id为left_gif_thumb_handle的Component是否存在，如果存在说明已正常打开截取gif页面。
 */
function clickGifButton(driver: Driver) {
  it(CASE + '_点击视频播放页的gif按钮能正常打开截取gif页面', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const firstVideoItemComponent = await driver.findComponent(ON.id('first_video'));
    await firstVideoItemComponent.click();

    await driver.delayMs(2000);

    // 点击"gif"按钮
    const gifButton = await driver.findComponent(ON.text('gif'));
    await gifButton.click();

    await driver.delayMs(1000);

    // 判断id为left_gif_thumb_handle的Component是否存在，如果存在说明已正常打开截取gif页面
    await driver.assertComponentExist(ON.id('left_gif_thumb_handle'));

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：调整视频的选择范围
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击"gif"按钮，打开截取gif页面。
 * 3.移动选中框左侧的条状物。
 * 4.判断选中框左侧的条状物是否正常移动了。
 * 5.移动选中框右侧的条状物。
 * 6.判断选中框右侧的条状物是否正常移动了。
 * 7.移动选中框。
 * 8.判断选中框左侧和右侧的条状物是否正常移动了。
 */
function selectTimeFrame(driver: Driver) {
  it(CASE + '_调整视频的选择范围', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const firstVideoItemComponent = await driver.findComponent(ON.id('first_video'));
    await firstVideoItemComponent.click();

    await driver.delayMs(1000);

    // 点击"gif"按钮
    const gifButton = await driver.findComponent(ON.text('gif'));
    await gifButton.click();

    await driver.delayMs(1000);

    // 移动选中框左侧的条状物
    const leftGifThumbHandle = await driver.findComponent(ON.id('left_gif_thumb_handle'));
    const leftGifThumbHandleRect = await leftGifThumbHandle.getBounds();
    let leftY = Math.floor((leftGifThumbHandleRect.top + leftGifThumbHandleRect.bottom) / 2);
    await driver.drag(leftGifThumbHandleRect.left, leftY, leftGifThumbHandleRect.left + 200, leftY);

    // 判断选中框左侧的条状物是否正常移动了
    const newLeftGifThumbHandleRect = await leftGifThumbHandle.getBounds();
    expect(newLeftGifThumbHandleRect.left > leftGifThumbHandleRect.left).assertEqual(true);

    // 移动选中框右侧的条状物
    const rightGifThumbHandle = await driver.findComponent(ON.id('right_gif_thumb_handle'));
    const rightGifThumbHandleRect = await rightGifThumbHandle.getBounds();
    let rightY = Math.floor((rightGifThumbHandleRect.top + rightGifThumbHandleRect.bottom) / 2);
    await driver.drag(rightGifThumbHandleRect.right, rightY, rightGifThumbHandleRect.right - 200, rightY);

    // 判断选中框右侧的条状物是否正常移动了
    const newRightGifThumbHandleRect = await rightGifThumbHandle.getBounds();
    expect(newRightGifThumbHandleRect.left < rightGifThumbHandleRect.left).assertEqual(true);

    // 移动选中框
    let middleX = Math.floor((newLeftGifThumbHandleRect.left + newRightGifThumbHandleRect.left) / 2);
    await driver.drag(middleX, leftY, middleX + 200, leftY);

    // 判断选中框左侧和右侧的条状物是否正常移动了
    const newLeftGifThumbHandleRect1 = await leftGifThumbHandle.getBounds();
    expect(newLeftGifThumbHandleRect1.left > newLeftGifThumbHandleRect.left).assertEqual(true);
    const newRightGifThumbHandleRect1 = await rightGifThumbHandle.getBounds();
    expect(newRightGifThumbHandleRect1.left > newRightGifThumbHandleRect.left).assertEqual(true);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：生成gif图片
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击"gif"按钮，打开截取gif页面。
 * 3.点击"下一步"按钮，打开生成gif页面。
 * 4.判断"生成成功"的Toast是否存在，如果存在，说明gif生成成功。
 */
function createGif(driver: Driver) {
  it(CASE + '_生成gif图片', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const videoItemComponent = await driver.findComponent(ON.id('first_video'));
    await videoItemComponent.click();

    await driver.delayMs(1000);

    // 点击"gif"按钮
    const gifButton = await driver.findComponent(ON.text('gif'));
    await gifButton.click();

    await driver.delayMs(1000);

    // 点击"下一步"按钮
    const nextStepButton = await driver.findComponent(ON.text('下一步'));
    await nextStepButton.click();

    // 判断"生成成功"的Toast是否存在，如果存在，说明gif生成成功
    const createSuccessPromptComponent = await driver.waitForComponent(ON.text('生成成功'), 8000);
    expect(createSuccessPromptComponent !== null).assertEqual(true);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：gif保存至图库
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击"gif"按钮，打开截取gif页面。
 * 3.点击"下一步"按钮，打开生成gif页面。
 * 4.判断"生成成功"的Toast是否存在，如果存在，说明gif生成成功。
 * 5.点击SaveButton，弹出是否允许保存至图库的弹窗。
 * 6.点击"允许"按钮。
 * 7.判断"保存成功"的Toast是否存在，如果存在，说明保存至图库成功。
 */
function saveGif(driver: Driver) {
  it(CASE + '_gif保存至图库', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const videoItemComponent = await driver.findComponent(ON.id('first_video'));
    await videoItemComponent.click();

    await driver.delayMs(1000);

    // 点击"gif"按钮
    const gifButton = await driver.findComponent(ON.text('gif'));
    await gifButton.click();

    await driver.delayMs(1000);

    // 点击"下一步"按钮
    const nextStepButton = await driver.findComponent(ON.text('下一步'));
    await nextStepButton.click();

    // 判断"生成成功"的Toast是否存在，如果存在，说明gif生成成功
    const createSuccessPromptComponent = await driver.waitForComponent(ON.text('生成成功'), 8000);
    expect(createSuccessPromptComponent !== null).assertEqual(true);

    // 点击SaveButton，弹出是否允许图片保存至图库的弹窗
    const saveButton = await driver.findComponent(ON.type('SaveButton'));
    await saveButton.click();

    await driver.delayMs(1000);

    const btnPermission = await driver.findComponent(ON.text('允许'));
    if (btnPermission !== null && btnPermission !== undefined) {
      await btnPermission!.click();
      await driver.delayMs(1000);
    }

    // 判断"保存成功"的Toast是否存在，如果存在，说明保存至图库成功
    const saveSuccessPromptComponent = await driver.waitForComponent(ON.text('保存成功'), 2000);
    expect(saveSuccessPromptComponent !== null).assertEqual(true);

    await driver.delayMs(1000);

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：点击视频播放页面的返回按钮
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击返回按钮。
 * 3.判断id为first_video的Component是否存在，如果存在，说明已返回到视频宫格页面。
 */
function clickBackInVideoPlayPage(driver: Driver) {
  it(CASE + '_点击视频播放页面的返回按钮', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const videoItemComponent = await driver.findComponent(ON.id('first_video'));
    await videoItemComponent.click();

    await driver.delayMs(1000);

    // 点击返回按钮
    const backComponent = await driver.findComponent(ON.id('video_play_back'));
    await backComponent.click();

    await driver.delayMs(1000);

    // 判断id为first_video的Component是否存在，如果存在，说明已返回到视频宫格页面
    await driver.assertComponentExist(ON.id('first_video'));

    done();
  })
}

/**
 * 关联用例：点击截取gif页面的返回按钮
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击"gif"按钮，打开截取gif页面。
 * 3.点击返回按钮。
 * 4.判断"下一步"按钮是否不存在，如果不存在，说明截取gif页面已关闭。
 *   判断"gif"按钮是否存在，如果存在，说明已返回到视频播放页面。
 */
function clickBackInSelectTimeFramePage(driver: Driver) {
  it(CASE + '_点击截取gif页面的返回按钮', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const videoItemComponent = await driver.findComponent(ON.id('first_video'));
    await videoItemComponent.click();

    await driver.delayMs(1000);

    // 点击"gif"按钮
    const gifButton = await driver.findComponent(ON.text('gif'));
    await gifButton.click();

    await driver.delayMs(1000);

    // 点击返回按钮
    const backComponent = await driver.findComponent(ON.id('select_gif_time_frame_back'));
    await backComponent.click();

    await driver.delayMs(1000);

    // 判断"下一步"按钮是否不存在，如果不存在，说明截取gif页面已关闭
    const nextStepButton = await driver.findComponent(ON.text('下一步'));
    expect(nextStepButton === null).assertEqual(true);

    // 判断"gif"按钮是否存在，如果存在，说明已返回到视频播放页面
    await driver.assertComponentExist(ON.text('gif'));

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}

/**
 * 关联用例：点击截取gif页面的返回按钮
 * 执行步骤：
 * 1.点击"本地视频截取gif"的视频，打开视频播放页面。
 * 2.点击"gif"按钮，打开截取gif页面。
 * 3.点击"下一步"按钮，打开生成gif页面。
 * 4.判断"生成成功"的Toast是否存在，如果存在，说明gif生成成功。
 * 5.点击返回按钮。
 * 6.判断id为image1的Component是否不存在，如果不存在，说明生成gif页面已关闭。
 *   判断"下一步"按钮是否存在，如果存在，说明已返回到截取gif页面。
 */
function clickBackInCreateGifPage(driver: Driver) {
  it(CASE + '_点击生成gif页面的返回按钮', 0, async (done: Function) => {
    // 点击"本地视频截取gif"的视频
    const videoItemComponent = await driver.findComponent(ON.id('first_video'));
    await videoItemComponent.click();

    await driver.delayMs(1000);

    // 点击"gif"按钮
    const gifButton = await driver.findComponent(ON.text('gif'));
    await gifButton.click();

    await driver.delayMs(1000);

    // 点击"下一步"按钮
    const nextStepButton = await driver.findComponent(ON.text('下一步'));
    await nextStepButton.click();

    // 判断"生成成功"的Toast是否存在，如果存在，说明gif生成成功
    const createSuccessPromptComponent = await driver.waitForComponent(ON.text('生成成功'), 8000);
    expect(createSuccessPromptComponent !== null).assertEqual(true);

    // 点击返回按钮
    const backComponent = await driver.findComponent(ON.id('gif_create_back'));
    await backComponent.click();

    await driver.delayMs(1000);

    // 判断id为image1的Component是否不存在，如果不存在，说明生成gif页面已关闭
    const image = await driver.findComponent(ON.id("image1"));
    expect(image === null).assertEqual(true);

    // 判断"下一步"按钮是否存在，如果存在，说明已返回到截取gif页面
    await driver.assertComponentExist(ON.text('下一步'));

    await driver.pressBack();
    await driver.delayMs(1000);

    done();
  })
}