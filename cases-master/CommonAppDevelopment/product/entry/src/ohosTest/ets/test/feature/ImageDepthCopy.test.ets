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

import image from '@ohos.multimedia.image'; // 导入Image模块
import { BusinessError } from '@kit.BasicServicesKit';
import { Driver, ON } from "@kit.TestKit";
import { expect, it } from "@ohos/hypium";
import { logger } from 'utils';
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Size } from 'slidetohideanddisplace/src/main/ets/model/Util';
import exit from '../common/Exit.test';

const CASE: string = 'ImageDepthCopy'; // 案例名称
const TAG: string = '[ImageDepthCopy_Test]';

/**
 * 【PixelMap深拷贝案例】自动化测试用例
 */
export default function imageDepthCopyTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('PixelMap深拷贝案例');
  const driver = Driver.create();

  /**
   * 通过判断裁剪后保存的图片的尺寸是否符合要求来验证功能正常
   */
  it("验证图片裁剪尺寸正确", 0, async (done: Function) => {
    await driver.delayMs(200);
    // 定义保存的5张图片
    const picPath0 = getContext().filesDir + "/0.jpg";     // 初始图片
    const picPath1 = getContext().filesDir + "/1.jpg";     // 恢复后的图片
    const picPath11 = getContext().filesDir + "/11.jpg";   // 1:1图片
    const picPath43 = getContext().filesDir + "/43.jpg";   // 4:3图片
    const picPath169 = getContext().filesDir + "/169.jpg"; // 16:9图片

    // 保存最初的图片
    await driver.assertComponentExist(ON.id('btn_Save'));
    const btnSaveComponent = await driver.findComponent(ON.id('btn_Save'));
    await btnSaveComponent.click();
    await driver.delayMs(200);
    // 弹窗确认保存
    await driver.assertComponentExist(ON.text('确认'));
    const btnConrimComponent = await driver.findComponent(ON.text('确认'));
    await btnConrimComponent.click();
    await driver.delayMs(500);
    // 获取初始图片大小
    const sizeInit: Size = await getImageSize(picPath0);
    // 断言初始图片大小正常
    let isEqual: boolean = ((sizeInit.height > 0) && (sizeInit.width > 0));
    expect(isEqual).assertEqual(true);

    // 保存四个不同裁剪大小的图片
    for (let index: number = 3; index >= 0; index--) {
      let componentID: string = 'listItem_' + index.toString().toString();
      // 裁剪
      await driver.assertComponentExist(ON.id(componentID));
      const btnCropComponent = await driver.findComponent(ON.id(componentID));
      await btnCropComponent.click();
      await driver.delayMs(200);

      // 保存裁剪后的图片
      await btnSaveComponent.click();
      await driver.delayMs(200);
      // 弹窗确认保存
      await driver.assertComponentExist(ON.text('确认'));
      const btnConrimComponent = await driver.findComponent(ON.text('确认'));
      await btnConrimComponent.click();
      await driver.delayMs(500);
    }
    // 获取裁剪后的图片尺寸
    const size11: Size = await getImageSize(picPath11);     // 1:1图片
    const size169: Size = await getImageSize(picPath169);   // 16:9图片
    const size43: Size = await getImageSize(picPath43);     // 4:3图片
    const size1: Size = await getImageSize(picPath1);       // 恢复原图后的图片

    // 断言 1:1 裁剪的图片正常
    let lowSize: number = (sizeInit.height > sizeInit.width ? sizeInit.width : sizeInit.height); // 取初始图片宽、高的小值
    if (size11.height === size11.width && size11.height === lowSize) {
      isEqual = true;
    } else {
      isEqual = false;
    }
    expect(isEqual).assertEqual(true);

    // 断言 恢复原图后裁剪的图片正常
    isEqual = (size1.width === sizeInit.width && size1.height === sizeInit.height);
    expect(isEqual).assertEqual(true);

    // 断言 16:9图片正常
    isEqual = (size169.width === sizeInit.width && size169.height === Math.floor((sizeInit.height * 9 / 16)));
    expect(isEqual).assertEqual(true);

    // 断言 4:3图片正常
    isEqual = (size43.width === sizeInit.width && size43.height === Math.floor((sizeInit.height * 3 / 4)));
    expect(isEqual).assertEqual(true);

    done();
  })

  exit('PixelMap深拷贝案例');
}

/**
 * 获取图片尺寸
 */
async function getImageSize(picPath: string): Promise<Size> {
  const picSource = image.createImageSource(picPath);
  let sizeImg = new Size(0, 0);
  await picSource!.createPixelMap().then(async (pixelMap: image.PixelMap) => {
    const imageInfo: image.ImageInfo = await pixelMap.getImageInfo();
    sizeImg.height = imageInfo.size.height;
    sizeImg.width = imageInfo.size.width;
  }).catch((err: BusinessError) => {
    logger.info(TAG, `${CASE} getImageSize fail, message: ${err.message}, error code: ${err.code}`);
  });
  return sizeImg;
}