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
import { fileIo as fs } from '@kit.CoreFileKit';
import { emitter } from '@kit.BasicServicesKit';
import exit from '../common/Exit.test';

const CASE: string = 'MultipleFilesDownload';
const TAG: string = '[MultipleFilesDownload_Test]';
const DELAY_MS: number = 1000;

/**
 * 【多文件下载监听案例】自动化测试用例
 * 主要功能：使用request上传下载模块实现多文件下载监听
 * 执行步骤：
 * 1.点击“全部开始”，下载队列中五个任务能正常下载完成，且下载完成的文件在下载列表中消失
 * 2.点击“全部暂停”，下载队列中正在下载的任务被暂停
 * 3.点击“全部开始”，然后在下载完成前点击“全部暂停”，然后再次点击“全部开始”。下载任务重新恢复下载
 * 4.下载完成后，在案例应用缓存路径下可以找到下载的文件
 * 5.下载完成后，切换到下载历史页面，已下载的文件出现在该页面中
 * 6.下载历史页面，可删除已下载的文件
 * 7.删除的文件，在案例应用缓存路径下不能找到已删除的文件
 * 8.点击文件，若在案例应用缓存路径下可以找到下载的文件，提示文件已存在
 * 9.点击文件，若在案例应用缓存路径下不能找到该文件，弹框提示用户“是否重新下载",点击“确定”，该文件会在下载历史页面消失
 * 10.重新下载的文件会出现在下载列表页面，可点击“全部开始”按钮，重新下载
 */
export default function multipleFilesDownloadTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('多文件下载监听案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);

  /**
   * 点击“全部开始”，下载队列中任务能正常下载完成，且下载完成的文件在下载列表中消失
   */
  it(CASE + '点击“全部开始”，下载队列中任务能正常下载完成', 0, async (done: Function) => {
    let downloadBtn = await driver.findComponent(ON.id('download'));
    // 点击“全部开始”
    await downloadBtn.click();
    // 等待下载完成，网络差的话时间设大一点
    await driver.delayMs(9000);

    // 查看文件是否存在于下载列表页面
    let fileOne = await driver.findComponent(ON.id('favor_list_tea.pngstate'));
    let fileTwo = await driver.findComponent(ON.id('after_cache.pngstate'));
    let fileThree = await driver.findComponent(ON.id('icon_main_color.pngstate'));
    let fileFour = await driver.findComponent(ON.id('image_resizable.pngstate'));
    let fileFive = await driver.findComponent(ON.id('text_overflow_detail.pngstate'));

    // 断言文件下载任务是不是都是下载完成,下载完成的文件不存在下载列表页面，而是出现在下载历史页面中
    expect(null).assertEqual(fileOne);
    expect(null).assertEqual(fileTwo);
    expect(null).assertEqual(fileThree);
    expect(null).assertEqual(fileFour);
    expect(null).assertEqual(fileFive);

    // 下载完成后，退出案例页面
    await driver.pressBack();
    await driver.delayMs(DELAY_MS);
    done();
  })

  // 重新进入案例页面
  searchCaseClickIn('多文件下载监听案例');

  /**
   * 点击“全部暂停”，下载队列中正在下载的任务被暂停
   */
  it(CASE + '点击“全部暂停”，下载队列中正在下载的任务被暂停', 0, async (done: Function) => {
    let downloadBtn = await driver.findComponent(ON.id('download'));
    // 点击“全部开始”开始下载
    await downloadBtn.click();
    // 点击“全部暂停”暂停下载
    await downloadBtn.click();
    await driver.delayMs(DELAY_MS);

    // 获取下载任务状态的Text
    let fileOne = await driver.findComponent(ON.id('favor_list_tea.pngstate'));
    let fileTwo = await driver.findComponent(ON.id('after_cache.pngstate'));
    let fileThree = await driver.findComponent(ON.id('icon_main_color.pngstate'));
    let fileFour = await driver.findComponent(ON.id('image_resizable.pngstate'));
    let fileFive = await driver.findComponent(ON.id('text_overflow_detail.pngstate'));

    // 获取下载任务状态
    const fileOneState: string = await fileOne!.getText();
    const fileTwoState: string = await fileTwo!.getText();
    const fileThreeState: string = await fileThree!.getText();
    const fileFourState: string = await fileFour!.getText();
    const fileFiveState: string = await fileFive!.getText();

    // 断言文件下载任务是不是都是“已暂停”
    expect('已暂停').assertEqual(fileOneState);
    expect('已暂停').assertEqual(fileTwoState);
    expect('已暂停').assertEqual(fileThreeState);
    expect('已暂停').assertEqual(fileFourState);
    expect('已暂停').assertEqual(fileFiveState);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 点击“全部开始”，然后在下载完成前点击“全部暂停”（对应上面的第2条用例）。然后再次点击“全部开始”，下载任务重新恢复下载
   */
  it(CASE + '点击“全部开始”，下载任务重新恢复下载', 0, async (done: Function) => {
    let downloadBtn = await driver.findComponent(ON.id('download'));
    // 点击“全部开始”重新恢复下载
    await downloadBtn.click();
    // 等待下载完成，网络差的话时间设大一点
    await driver.delayMs(9000);

    // 查看文件是否存在于下载列表页面
    let fileOne = await driver.findComponent(ON.id('favor_list_tea.pngstate'));
    let fileTwo = await driver.findComponent(ON.id('after_cache.pngstate'));
    let fileThree = await driver.findComponent(ON.id('icon_main_color.pngstate'));
    let fileFour = await driver.findComponent(ON.id('image_resizable.pngstate'));
    let fileFive = await driver.findComponent(ON.id('text_overflow_detail.pngstate'));

    // 断言文件下载任务是不是都是下载完成,下载完成的文件不存在下载列表页面，而是出现在下载历史页面中
    expect(null).assertEqual(fileOne);
    expect(null).assertEqual(fileTwo);
    expect(null).assertEqual(fileThree);
    expect(null).assertEqual(fileFour);
    expect(null).assertEqual(fileFive);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 下载完成后，在应用缓存路径下可以找到下载的文件
   */
  it(CASE + '下载完成后，在应用缓存路径下可以找到下载的文件', 0, async (done: Function) => {
    // 判断应用缓存路径下下载的文件是否存在
    let fileOneIsExist: boolean = false;
    let fileTwoIsExist: boolean = false;
    let fileThreeIsExist: boolean = false;
    let fileFourIsExist: boolean = false;
    let fileFiveIsExist: boolean = false;
    let fileOnePath = getContext().cacheDir + "/" + 'favor_list_tea.png';
    try {
      let res = fs.accessSync(fileOnePath);
      if (res) {
        fileOneIsExist = true;
      }
    } catch {
      logger.error(TAG, `${CASE} favor_list_tea.png find fail`);
    }
    let fileTwoPath = getContext().cacheDir + "/" + 'after_cache.png';
    try {
      let res = fs.accessSync(fileTwoPath);
      if (res) {
        fileTwoIsExist = true;
      }
    } catch {
      logger.error(TAG, `${CASE} after_cache.png find fail`);
    }
    let fileThreePath = getContext().cacheDir + "/" + 'icon_main_color.png';
    try {
      let res = fs.accessSync(fileThreePath);
      if (res) {
        fileThreeIsExist = true;
      }
    } catch {
      logger.error(TAG, `${CASE} icon_main_color.png find fail`);
    }
    let fileFourPath = getContext().cacheDir + "/" + 'image_resizable.png';
    try {
      let res = fs.accessSync(fileFourPath);
      if (res) {
        fileFourIsExist = true;
      }
    } catch {
      logger.error(TAG, `${CASE} image_resizable.png find fail`);
    }
    let fileFivePath = getContext().cacheDir + "/" + 'text_overflow_detail.png';
    try {
      let res = fs.accessSync(fileFivePath);
      if (res) {
        fileFiveIsExist = true;
      }
    } catch {
      logger.error(TAG, `${CASE} text_overflow_detail.png find fail`);
    }

    // 断言判断下载的文件是否都存在
    expect(true).assertEqual(fileOneIsExist);
    expect(true).assertEqual(fileTwoIsExist);
    expect(true).assertEqual(fileThreeIsExist);
    expect(true).assertEqual(fileFourIsExist);
    expect(true).assertEqual(fileFiveIsExist);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 下载完成后，切换到下载历史页面，已下载的文件出现在页面中
   */
  it(CASE + '下载完成后，切换到下载历史页面，已下载的文件出现在页面中', 0, async (done: Function)=>{
    let historyBtn = await driver.findComponent(ON.text('下载历史'));
    // 点击“下载历史”切换到下载历史页面
    await historyBtn.click();

    // 查看文件是否存在于下载历史页面
    let fileOne = await driver.findComponent(ON.id('favor_list_tea.pngstate'));
    let fileTwo = await driver.findComponent(ON.id('after_cache.pngstate'));
    let fileThree = await driver.findComponent(ON.id('icon_main_color.pngstate'));
    let fileFour = await driver.findComponent(ON.id('image_resizable.pngstate'));
    let fileFive = await driver.findComponent(ON.id('text_overflow_detail.pngstate'));

    // 获取下载任务状态
    const fileOneState: string = await fileOne!.getText();
    const fileTwoState: string = await fileTwo!.getText();
    const fileThreeState: string = await fileThree!.getText();
    const fileFourState: string = await fileFour!.getText();
    const fileFiveState: string = await fileFive!.getText();

    // 断言文件下载任务是不是都是“已下载”
    expect('已下载').assertEqual(fileOneState);
    expect('已下载').assertEqual(fileTwoState);
    expect('已下载').assertEqual(fileThreeState);
    expect('已下载').assertEqual(fileFourState);
    expect('已下载').assertEqual(fileFiveState);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 下载历史页面，可删除已下载的文件
   */
  it(CASE + '下载历史页面，可删除已下载的文件', 0, async (done: Function)=>{
    let isDel: boolean = false;
    emitter.on({
      eventId: 0, priority: 0
    }, (data: emitter.EventData) => {
      isDel = data.data?.isDel;
    })

    let fileOneDelBtn = await driver.findComponent(ON.id('favor_list_tea.pngdelete'));
    // 点击favor_list_tea.png的“删除”按钮
    await fileOneDelBtn.click();
    await driver.delayMs(DELAY_MS);

    // 判断是否点击favor_list_tea.png的“删除”按钮
    expect(isDel).assertEqual(true);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 删除的文件，在案例应用缓存路径下不能找到已删除的文件
   */
  it(CASE + '删除的文件，在案例应用缓存路径下不能找到已删除的文件', 0, async (done: Function)=>{
    // 判断应用缓存路径下下载的文件是否存在
    let fileIsExist: boolean = true;
    let filePath = getContext().cacheDir + "/" + 'favor_list_tea.png';
    let res = fs.accessSync(filePath);
    if (!res) {
      fileIsExist = false;
    }
    logger.info(TAG, `${CASE} favor_list_tea.png has been deleted`);

    // 断言判断favor_list_tea.png的文件是否存在
    expect(false).assertEqual(fileIsExist);
    await driver.delayMs(2000);
    done();
  })

  /**
   * 点击文件，若在案例应用缓存路径下可以找到下载的文件，提示文件已存在
   */
  it(CASE + '点击文件，若在案例应用缓存路径下可以找到下载的文件，提示文件已存在', 0, async (done: Function)=>{
    let fileClick = await driver.findComponent(ON.id('after_cache.png'));
    // 点击after_cache.png
    await fileClick.click();

    // 判断应用缓存路径下下载的文件是否存在
    let fileIsExist: boolean = true;
    let filePath = getContext().cacheDir + "/" + 'after_cache.png';
    try {
      let res = fs.accessSync(filePath);
      if (res) {
        fileIsExist = true;
      }
    } catch {
      logger.error(TAG, `${CASE} after_cache.png find fail`);
    }

    // 断言判断after_cache.png的文件是否存在
    expect(true).assertEqual(fileIsExist);
    await driver.delayMs(2000);
    done();
  })

  /**
   * 点击文件，若在案例应用缓存路径下不能找到该文件，弹框提示用户“favor_list_tea.png文件不存在,是否重新下载？"
   */
  it(CASE + '点击文件，若在案例应用缓存路径下不能找到该文件，弹框提示用户“是否重新下载"', 0, async (done: Function)=>{
    let fileClick = await driver.findComponent(ON.id('favor_list_tea.png'));
    // 点击favor_list_tea.png
    await fileClick.click();
    await driver.delayMs(2000);

    let alertDialogText = await driver.findComponent(ON.text('favor_list_tea.png文件不存在,是否重新下载？'));
    let isShowAlertDialog = false;
    if(alertDialogText) {
      isShowAlertDialog = true;
    }

    // 断言判断是否弹窗
    expect(true).assertEqual(isShowAlertDialog);
    await driver.delayMs(2000);
    done();
  })

  /**
   * 若要重新下载已删除的文件。点击弹窗的“确定”按钮，该文件会在下载历史页面消失
   */
  it(CASE + '若要重新下载已删除的文件。点击弹窗的“确定”按钮，该文件会在下载历史页面消失', 0, async (done: Function)=>{
    let isRedownload: boolean = false;
    emitter.on({
      eventId: 0, priority: 0
    }, (data: emitter.EventData) => {
      isRedownload = data.data?.isRedownload;
    })

    let confirmBtn = await driver.findComponent(ON.text('确定'));
    // 点击“确定”按钮重新下载
    await confirmBtn.click();
    await driver.delayMs(3000);

    // 查看文件是否存在于下载历史页面
    let file = await driver.findComponent(ON.id('favor_list_tea.pngstate'));

    // 断言文件重新下载的文件已不在下载历史页面
    expect(null).assertEqual(file);
    done();
  })

  /**
   * 重新下载的文件会出现在下载列表页面，可点击“全部开始”按钮，重新下载
   */
  it(CASE + '重新下载的文件会出现在下载列表页面，可点击“全部开始”按钮，重新下载', 0, async (done: Function)=>{
    let downloadBtn = await driver.findComponent(ON.text('下载列表'));
    // 点击“下载列表”切换到下载列表页面
    await downloadBtn.click();

    // 查看文件是否存在于下载列表页面
    let file = await driver.findComponent(ON.id('favor_list_tea.pngstate'));
    // 获取下载任务状态
    const fileOneState: string = await file!.getText();
    let isExist = false;
    if(file) {
      isExist = true;
    }
    expect(true).assertEqual(isExist);
    await driver.delayMs(2000);
    done();
  })

  exit('多文件下载监听案例');
}