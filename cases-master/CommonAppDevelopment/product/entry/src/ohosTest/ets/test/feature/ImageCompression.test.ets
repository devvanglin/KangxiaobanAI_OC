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

const CASE: string = 'ImageCompression';
const TAG: string = '[ImageCompression_Test]';
const DELAY_MS: number = 500;

let driver = Driver.create();

// 通过 ID 滑动 slider
async function drawSliderWithId(text: string) {
  let atom = text;
  await driver.assertComponentExist(ON.id(atom));
  let slider = await driver.findComponent(ON.id(atom));
  let rect = await slider.getBoundsCenter();
  await driver.drag(rect.x, rect.y, rect.x - 150, rect.y, 800);
  await driver.delayMs(DELAY_MS);
}

/**
 * 【图片压缩方案】自动化测试用例
 * 主要功能：通过packing和scale实现图片压缩（如自动压缩到目标大小以内，手动调整图片质量和尺寸进行压缩等），以及把图片压缩成不同格式后保存到图库。
 * 执行步骤：
 * 1.添加测试图片。点击使用测试图片的"保存至图库"按钮。添加图片后，在"压缩前"下方显示图片，图片大小，格式，尺寸信息。
 * 2.压缩模式选择"自动模式"，输入图片压缩目标大小，点击"压缩"按钮，查看"压缩后"下方显示压缩后的图片大小，格式，尺寸
 * 3.压缩模式选择"自动模式"，输入图片压缩目标大小后，查看压缩后的大小不超过"图片压缩目标大小"
 * 4.压缩后的图片保存至图库功能
 * 5.选择不同的"输出格式"，查看压缩后的图片格式
 * 6.查看"scale每次缩小倍数"功能的压缩效果。"scale每次缩小倍数"设置为最小值0.01，压缩后的图片大小相比设置其他值，更接近图片压缩目标大小
 * 7.查看设置"压缩偏好"选项后，压缩功能是否正常。
 * （1）选择“优先压缩质量”时，“packing最小二分单位”滑块可以正常滑动，“最低图片质量”滑块不可滑动
 * （2）步骤（1）后，点击压缩按钮，压缩功能正常
 * （3）选择“优先压缩尺寸”时，“packing最小二分单位”滑块不可滑动，“最低图片质量”滑块可以滑动
 * （4）步骤（4）后，点击压缩按钮，压缩功能正常
 * 8.压缩模式选择"手动模式"，设置"图片质量"，查看压缩效果
 * 9.压缩模式选择"手动模式"，设置"图片尺寸"，查看压缩效果
 */
export default function imageCompressionTest() {
  searchCaseClickIn('图片压缩方案');
  logger.info(TAG, `${CASE} begin`);
  // 保存到图库的测试图片uri
  let testUri: string = '';
  // 压缩后图片大小
  let afterCompressionSize: string = '';
  // 压缩后图片格式
  let showCompressFormat: string = '';
  // 压缩后图片宽高
  let afterCompressImgSize: string = '';
  emitter.on('ImageCompression0', (data: emitter.EventData) => {
    afterCompressionSize = data.data?.afterCompressionSize;
  })
  emitter.on('ImageCompression1', (data: emitter.EventData) => {
    showCompressFormat = data.data?.showCompressFormat;
  })
  emitter.on('ImageCompression2', (data: emitter.EventData) => {
    testUri = data.data?.testUri;
  })
  emitter.on('ImageCompression3', (data: emitter.EventData) => {
    afterCompressImgSize = data.data?.afterCompressImgSize;
  })

  /**
   * 1.添加测试图片。点击使用测试图片的"保存至图库"按钮。添加图片后，在"压缩前"下方显示图片，图片大小，格式，尺寸信息。
   */
  it(CASE + '添加测试图片', 0, async (done: Function) => {
    // 把测试图片添加到图库，并在页面显示
    let testImageBtn = await driver.findComponent(ON.text('保存至图库'));
    await testImageBtn.click();
    await driver.delayMs(DELAY_MS);
    // 获取安全弹窗"允许"按钮
    const allowBtn = await driver.findComponent(ON.text('允许'));
    if (allowBtn !== null && allowBtn !== undefined) {
      // 点击"允许"按钮，若可获取保存按钮，点击后即可关闭预览框
      await allowBtn!.click();
      await driver.delayMs(1000);
    }
    await driver.delayMs(DELAY_MS);
    // 断言图片大小，格式，尺寸信息
    await driver.assertComponentExist(ON.text('503.0'));
    await driver.assertComponentExist(ON.text('jpeg'));
    await driver.assertComponentExist(ON.text('2000*1500'));
    await driver.delayMs(DELAY_MS);
    done();
  })


  /**
   * 2.压缩模式选择"自动模式"，输入图片压缩目标大小（比如10kb），点击"压缩"按钮，查看"压缩后"下方显示压缩后的图片大小，格式，尺寸
   */
  it(CASE + '查看"自动模式"图片压缩效果', 0, async (done: Function) => {
    // 选择"自动模式"
    let autoMode = await driver.findComponent(ON.id('autoMode'));
    await autoMode.click();
    // 输入图片压缩目标大小10，单位kb
    let inputComponent = await driver.findComponent(ON.id('textInput'));
    await inputComponent.inputText('10'); // 输入文字
    await driver.delayMs(DELAY_MS);
    // 点击'压缩'按钮
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    await driver.delayMs(2000);
    // 查看"压缩后"下方显示压缩后的图片大小，格式，尺寸
    await driver.assertComponentExist(ON.text('1.7'));
    await driver.assertComponentExist(ON.text('jpeg'));
    await driver.assertComponentExist(ON.text('240*180'));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 3.压缩模式选择"自动模式"，输入图片压缩目标大小后，查看压缩后的大小不超过"图片压缩目标大小"
   */
  it(CASE + '查看压缩后的大小不超过"图片压缩目标大小"', 0, async (done: Function) => {
    // 选择"自动模式"
    let autoMode = await driver.findComponent(ON.id('autoMode'));
    await autoMode.click();
    // 输入图片压缩目标大小10，单位kb
    let inputComponent = await driver.findComponent(ON.id('textInput'));
    await inputComponent.inputText('10'); // 输入文字
    // 点击'压缩'按钮
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    await driver.delayMs(2000);
    // 断言压缩后的大小是否不超过"图片压缩目标大小"
    expect(true).assertEqual(Number(afterCompressionSize) <= 10);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 4.压缩后的图片保存至图库功能
   */
  it(CASE + '压缩后的图片保存至图库功能', 0, async (done: Function) => {
    // 判断图片是否存在
    expect(true).assertEqual(testUri !== '');
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 5.选择不同的"输出格式"，查看压缩后的图片格式
   */
  it(CASE + '选择不同的"输出格式"，查看压缩后的图片格式', 0, async (done: Function) => {
    // （1）按原格式压缩后的图片格式是否为jpeg
    expect(true).assertEqual(showCompressFormat === 'jpeg');
    // （2）按PNG压缩后的图片格式是否为PNG
    // 点击输出格式
    let outputFormat = await driver.findComponent(ON.id('outputFormat'));
    await outputFormat.click();
    await driver.delayMs(DELAY_MS);
    // 点击PNG选项
    let pngFormat = await driver.findComponent(ON.text('PNG'));
    await pngFormat.click();
    await driver.delayMs(DELAY_MS);
    // 点击压缩
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    await driver.delayMs(2000);
    expect(true).assertEqual(showCompressFormat === 'png');
    // （3）按JPG压缩后的图片格式是否为JPG
    await outputFormat.click();
    await driver.delayMs(DELAY_MS);
    let jpgFormat = await driver.findComponent(ON.text('JPG'));
    await jpgFormat.click();
    await driver.delayMs(DELAY_MS);
    await compressBtn.click();
    await driver.delayMs(2000);
    expect(true).assertEqual(showCompressFormat === 'jpeg');
    // 按WEBP压缩后的图片格式是否为WEBP
    await outputFormat.click();
    await driver.delayMs(DELAY_MS);
    let webpFormat = await driver.findComponent(ON.text('WEBP'));
    await webpFormat.click();
    await driver.delayMs(DELAY_MS);
    await compressBtn.click();
    await driver.delayMs(2000);
    expect(true).assertEqual(showCompressFormat === 'webp');
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 6.查看"scale每次缩小倍数"功能的压缩效果。"scale每次缩小倍数"设置为最小值0.01，压缩后的图片大小相比设置其他值，更接近图片压缩目标大小
   */
  it(CASE + '查看"scale每次缩小倍数"功能的压缩效果', 0, async (done: Function) => {
    // 基于前面用例5的webp压缩后的图片大小和"scale每次缩小倍数"设置为最小值0.01的图片大小进行比较。"scale每次缩小倍数"设为0.01后压缩的图片大小比默认的0.4更接近"图片压缩目标大小"
    // 把"scale每次缩小倍数"滑块滑到最小0.01
    await drawSliderWithId('scaleSlider');
    // "scale每次缩小倍数"默认值为0.4时，webp格式压缩后的图片大小
    const defaultCompressSize: number = Number(afterCompressionSize);
    // 点击压缩
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    // 压缩时间尽量设大一点
    await driver.delayMs(5000);
    // 获取当前"scale每次缩小倍数"设置0.01时，压缩后的图片大小
    const setCompressSize = Number(afterCompressionSize);
    // 判断"scale每次缩小倍数"设置0.01的压缩后图片大小是否大于设置0.4时压缩后的图片大小,并且不超过"图片压缩目标大小"
    expect(true).assertEqual((setCompressSize > defaultCompressSize) && (setCompressSize <= 10));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   *  7.查看设置"压缩偏好"选项后，压缩功能是否正常
   * （1）选择“优先压缩质量”时，“packing最小二分单位”滑块可以正常滑动，“最低图片质量”滑块不可滑动
   * （2）点击压缩按钮，压缩功能正常
   * （3）选择“优先压缩尺寸”时，“packing最小二分单位”滑块不可滑动，“最低图片质量”滑块可以滑动
   * （4）点击压缩按钮，压缩功能正常
   */
  it(CASE + '查看设置"压缩偏好"选项后，压缩功能是否正常', 0, async (done: Function) => {
    // （1）选择“优先压缩质量”时，“packing最小二分单位”滑块可以正常滑动，“最低图片质量”滑块不可滑动
    // 点击"优先压缩质量"
    let qualityPriority = await driver.findComponent(ON.id('qualityPriority'));
    await qualityPriority.click();
    // 查找参数设置项的Scroll组件
    let scrollBar = await driver.findComponent(ON.id('setScroll'));
    // 获取Scroll边框信息
    let rect = await scrollBar.getBounds();
    // 上滑到“packing最小二分单位”滑块位置
    await driver.swipe(rect.left + 50, rect.bottom, rect.left + 50, rect.bottom - 100, 1000);
    await driver.delayMs(DELAY_MS);
    // 判断“packing最小二分单位”滑块是否使能。使能说明能滑动
    await driver.assertComponentExist(ON.id('packingSlider').enabled(true));
    // 判断“最低图片质量”滑块是否没有使能。没有使能说明不能滑动
    await driver.assertComponentExist(ON.id('minQualitySlider').enabled(false));
    await driver.delayMs(DELAY_MS);
    // （2）点击压缩按钮，压缩功能正常
    // 点击压缩
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    await driver.delayMs(5000);
    // 断言afterCompressionSize压缩后图片大小是否大于0。大于0说明已压缩
    expect(true).assertEqual(Number(afterCompressionSize) > 0);
    // （3）选择“优先压缩尺寸”时，“packing最小二分单位”滑块不可滑动，“最低图片质量”滑块可以滑动
    // 点击"优先压缩尺寸"
    let scalePriority = await driver.findComponent(ON.id('scalePriority'));
    await scalePriority.click();
    await driver.delayMs(DELAY_MS);
    // 断言“packing最小二分单位”滑块是否没有使能。没有使能说明不能滑动
    await driver.assertComponentExist(ON.id('packingSlider').enabled(false));
    // 断言“最低图片质量”滑块是否使能。使能说明能滑动
    await driver.assertComponentExist(ON.id('minQualitySlider').enabled(true));
    await driver.delayMs(DELAY_MS);
    // （4）点击压缩按钮，压缩功能正常
    await compressBtn.click();
    await driver.delayMs(8000);
    // 断言afterCompressionSize压缩后图片大小是否大于0。大于0说明已压缩
    expect(true).assertEqual(Number(afterCompressionSize) > 0);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   *  8.压缩模式选择"手动模式"，设置"图片质量"，查看压缩效果。“图片质量”值设置越低，图片越不清晰。“图片质量”值设置越高，图片越清晰
   */
  it(CASE + '压缩模式选择"手动模式"，设置"图片质量"，查看压缩效果', 0, async (done: Function) => {
    // 选择"手动模式"
    let manualMode = await driver.findComponent(ON.id('manualMode'));
    await manualMode.click();
    await driver.delayMs(DELAY_MS);
    let scrollBar = await driver.findComponent(ON.id('setScroll'));
    // 获取Scroll边框信息
    let rect = await scrollBar.getBounds();
    // 上滑到手动模式的滑块位置
    await driver.swipe(rect.left + 50, rect.bottom, rect.left + 50, rect.bottom - 500, 1000);
    await driver.delayMs(DELAY_MS);
    // 先点击压缩按钮，记录一次默认质量100时的压缩图片大小
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    await driver.delayMs(5000);
    const defaultCompressSize: number = Number(afterCompressionSize);
    // 再滑动滑块，压缩，记录一次调低质量后的压缩图片大小
    await drawSliderWithId('imageQuality');
    await compressBtn.click();
    await driver.delayMs(5000);
    const setCompressSize = Number(afterCompressionSize);
    // “图片质量”值设置越低，图片越不清晰。“图片质量”值设置越高，图片越清晰。根据比较默认质量100时的压缩图片大小和调低质量后的压缩图片大小判断。图片质量越小越不清晰
    expect(true).assertEqual(defaultCompressSize > setCompressSize);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   *  9.压缩模式选择"手动模式"，设置"图片尺寸"，查看压缩效果。图片尺寸设置越低，图片尺寸越小
   */
  it(CASE + '压缩模式选择"手动模式"，设置"图片尺寸"，查看压缩效果', 0, async (done: Function) => {
    // 滑动滑块，压缩，记录一次调低尺寸后压缩的图片宽高
    await drawSliderWithId('imageScale');
    await driver.delayMs(DELAY_MS);
    let compressBtn = await driver.findComponent(ON.text('压缩'));
    await compressBtn.click();
    await driver.delayMs(5000);
    // 测试图片默认100%尺寸压缩后图片宽高为2000*1500。和调低尺寸的宽高比较是否变小了。
    const PARTS: string[] = afterCompressImgSize.split('*');
    let width = Number(PARTS[0]);
    let height = Number(PARTS[1]);
    await driver.delayMs(DELAY_MS);
    // 断言图片尺寸设置越低，图片尺寸越小
    expect(true).assertEqual(width < 2000 && height < 1500);
    done();
  })

  exit('图片压缩方案');
}