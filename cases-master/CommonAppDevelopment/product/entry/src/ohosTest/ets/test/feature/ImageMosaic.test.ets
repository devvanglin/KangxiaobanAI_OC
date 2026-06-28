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
import { Driver, ON, Point } from "@ohos.UiTest";
import { expect, it } from "@ohos/hypium";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import exit from '../common/Exit.test';

/**
 * 【图片编辑实现马赛克效果】自动化测试用例
 */
export default function ImageMosaicTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn('图片编辑实现马赛克效果');
  const driver = Driver.create();

  /**
   * 本测试用例通过在同一区域截取原始图、马赛克后的图、恢复原状的图 三张图片
   * 然后分析第一张图图跟第二张图数据不一致，跟第三张图数据一致，来确定用例功能正常
   */
  it("图片编辑实现马赛克效果", 0, async (done: Function) => {
    await driver.delayMs(200);
    // 找到图片组件
    await driver.assertComponentExist(ON.id('img_mosaic'));
    const imageComponent = await driver.findComponent(ON.id('img_mosaic'));
    await driver.delayMs(200);

    // 获取绘制马赛克区域的中心位置
    const imageRect = await imageComponent.getBounds();
    let centerPoint: Point = {
      // 此处取整数，避免rk上运行报错
      x: Math.floor((imageRect.right - imageRect.left) / 2), y: Math.floor((imageRect.bottom - imageRect.top) / 2) + 200
    };

    // 定义三张图片的位置，此处需要将路径替换为entry_test
    const picPath1 = getContext().filesDir.replaceAll('entry', 'entry_test') + "/1.png"; // 截取原图
    const picPath2 = getContext().filesDir.replaceAll('entry', 'entry_test') + "/2.png"; // 截取马赛克后的图
    const picPath3 = getContext().filesDir.replaceAll('entry', 'entry_test') + "/3.png"; // 截取恢复原状的图
    const offset: number = 200; // 图片截取区域范围

    // 截取原始图片
    await driver.screenCapture(picPath1, {
      left: centerPoint.x - offset,
      top: centerPoint.y - offset,
      right: centerPoint.x + offset,
      bottom: centerPoint.y + offset
    });
    await driver.delayMs(200);

    // 在图片上绘制马赛克
    await driver.fling({
      x: centerPoint.x - offset, y: centerPoint.y - offset
    }, {
      x: centerPoint.x + offset, y: centerPoint.y + offset
    }, 5, 600);

    await driver.delayMs(1000);

    // 截取马赛克后的图片
    await driver.screenCapture(picPath2, {
      left: centerPoint.x - offset,
      top: centerPoint.y - offset,
      right: centerPoint.x + offset,
      bottom: centerPoint.y + offset
    });
    await driver.delayMs(200);

    // 断言原图与马赛克后的图不一致
    let isEqual: boolean = await isPicEqual(picPath1, picPath2);
    expect(isEqual).assertEqual(false);
    await driver.delayMs(200);

    // 获取恢复原装按钮，并恢复原状
    await driver.assertComponentExist(ON.id('btn_restore_pic'));
    const btnComponent = await driver.findComponent(ON.id('btn_restore_pic'));
    await btnComponent.click();
    await driver.delayMs(200);

    // 截取恢复原装后的图片
    await driver.screenCapture(picPath3, {
      left: centerPoint.x - offset,
      top: centerPoint.y - offset,
      right: centerPoint.x + offset,
      bottom: centerPoint.y + offset
    });

    // 断言原图与恢复原状的图后的图一致
    isEqual = await isPicEqual(picPath1, picPath3);
    await driver.delayMs(200);
    expect(isEqual).assertEqual(true);

    done();
  })

  exit('图片编辑实现马赛克效果');
}

/**
 * 判断两张图片是否一致
 */
async function isPicEqual(picPath1: string, picPath2: string): Promise<boolean> {
  // 获取图片1的数据
  const picSource1 = image.createImageSource(picPath1);
  let dataArray1: Uint8Array;
  await picSource1.createPixelMap().then(async (pixelMap: image.PixelMap) => {
    const bufferData = new ArrayBuffer(pixelMap!.getPixelBytesNumber());
    await pixelMap!.readPixelsToBuffer(bufferData);
    // 将像素数据转换为 Uint8Array 便于像素处理
    dataArray1 = new Uint8Array(bufferData);
  }).catch((err: BusinessError) => {
    return false;
  });

  // 获取图片2的数据
  const picSource2 = image.createImageSource(picPath2);
  let dataArray2: Uint8Array;
  await picSource2.createPixelMap().then(async (pixelMap: image.PixelMap) => {
    const bufferData = new ArrayBuffer(pixelMap!.getPixelBytesNumber());
    await pixelMap!.readPixelsToBuffer(bufferData);
    // 将像素数据转换为 Uint8Array 便于像素处理
    dataArray2 = new Uint8Array(bufferData);
  }).catch((err: BusinessError) => {
    return false;
  });

  // 判断两张图片的大小是否一致
  if (dataArray1!.byteLength !== dataArray2!.byteLength) {
    return false;
  }

  // 判断两张图片的像素数据一致
  for (let index = 0; index < dataArray1!.byteLength; index += 4) {
    if (dataArray1![index] === dataArray2![index] && dataArray1![index + 1] === dataArray2![index + 1] &&
      dataArray1![index + 2] === dataArray2![index + 2] && dataArray1![index + 3] === dataArray2![index + 3]) {
      ;
    } else {
      return false;
    }
  }
  return true;
}