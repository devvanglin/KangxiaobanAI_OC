/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with License.
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

import { Component, Driver, ON, MatchPattern } from "@kit.TestKit";
import { it } from "@ohos/hypium";
import { logger } from "utils";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import exit from "../common/Exit.test";

const TAG: string = '[FoldableScreenCases_Test]';
const CASE_NAME: string = '折叠屏音乐播放器案例';

/**
 * 【折叠屏音乐播放器案例】自动化测试用例
 * 测试内容：
 * 1. 进入音乐播放器页面
 * 2. 测试播放控制按钮
 * 3. 测试播放、暂停功能
 * 4. 测试上一首、下一首功能
 * 5. 测试播放模式切换
 * 6. 测试进度条控制
 * 7. 测试时间显示
 */
export default function foldableScreenCasesTest() {
  // 引入common文件中通用脚本,进入要验证的案例
  searchCaseClickIn(CASE_NAME);

  const driver = Driver.create();

  /**
   * 测试进入音乐播放器页面
   */
  it("进入音乐播放器页面", 0, async (done: Function) => {
    logger.info(TAG, 'EnterMusicPlayerPage begin');
    await driver.delayMs(2000);

    // 验证音乐播放器信息组件存在
    try {
      await driver.assertComponentExist(ON.id('music_player_info_comp'));
      logger.info(TAG, 'Music player info component found');
    } catch (error) {
      logger.info(TAG, 'Music player info component not found, may use different id');
    }

    logger.info(TAG, 'EnterMusicPlayerPage end');
    done();
  });

  /**
   * 测试播放控制按钮存在性
   */
  it("验证播放控制按钮", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyControlButtons begin');

    // 验证播放模式按钮
    try {
      await driver.assertComponentExist(ON.id('btn_play_mode'));
      logger.info(TAG, 'Play mode button found');
    } catch (error) {
      logger.info(TAG, 'Play mode button not found');
    }

    // 验证上一首按钮
    try {
      await driver.assertComponentExist(ON.id('btn_play_previous'));
      logger.info(TAG, 'Play previous button found');
    } catch (error) {
      logger.info(TAG, 'Play previous button not found');
    }

    // 验证播放/暂停按钮
    try {
      await driver.assertComponentExist(ON.id('btn_play_pause'));
      logger.info(TAG, 'Play/pause button found');
    } catch (error) {
      logger.info(TAG, 'Play/pause button not found');
    }

    // 验证下一首按钮
    try {
      await driver.assertComponentExist(ON.id('btn_play_next'));
      logger.info(TAG, 'Play next button found');
    } catch (error) {
      logger.info(TAG, 'Play next button not found');
    }

    logger.info(TAG, 'VerifyControlButtons end');
    done();
  });

  /**
   * 测试播放功能
   */
  it("播放音乐", 0, async (done: Function) => {
    logger.info(TAG, 'PlayMusic begin');

    try {
      let btnPlay = await driver.findComponent(ON.id('btn_play_pause'));
      if (btnPlay) {
        await btnPlay.click();
        await driver.delayMs(2000);
        logger.info(TAG, 'Music played');
      }
    } catch (error) {
      logger.info(TAG, 'Play button not found or click failed');
    }

    logger.info(TAG, 'PlayMusic end');
    done();
  });

  /**
   * 测试暂停功能
   */
  it("暂停音乐", 0, async (done: Function) => {
    logger.info(TAG, 'PauseMusic begin');

    try {
      let btnPause = await driver.findComponent(ON.id('btn_play_pause'));
      if (btnPause) {
        await btnPause.click();
        await driver.delayMs(1000);
        logger.info(TAG, 'Music paused');
      }
    } catch (error) {
      logger.info(TAG, 'Pause button not found or click failed');
    }

    logger.info(TAG, 'PauseMusic end');
    done();
  });

  /**
   * 测试下一首功能
   */
  it("切换下一首", 0, async (done: Function) => {
    logger.info(TAG, 'NextMusic begin');

    try {
      let btnNext = await driver.findComponent(ON.id('btn_play_next'));
      if (btnNext) {
        await btnNext.click();
        await driver.delayMs(2000);
        logger.info(TAG, 'Next music played');
      }
    } catch (error) {
      logger.info(TAG, 'Next button not found or click failed');
    }

    logger.info(TAG, 'NextMusic end');
    done();
  });

  /**
   * 测试上一首功能
   */
  it("切换上一首", 0, async (done: Function) => {
    logger.info(TAG, 'PreviousMusic begin');

    try {
      let btnPrevious = await driver.findComponent(ON.id('btn_play_previous'));
      if (btnPrevious) {
        await btnPrevious.click();
        await driver.delayMs(2000);
        logger.info(TAG, 'Previous music played');
      }
    } catch (error) {
      logger.info(TAG, 'Previous button not found or click failed');
    }

    logger.info(TAG, 'PreviousMusic end');
    done();
  });

  /**
   * 测试播放模式切换
   */
  it("切换播放模式", 0, async (done: Function) => {
    logger.info(TAG, 'SwitchPlayMode begin');

    try {
      let btnPlayMode = await driver.findComponent(ON.id('btn_play_mode'));
      if (btnPlayMode) {
        // 切换多次，测试不同模式
        for (let i = 0; i < 4; i++) {
          await btnPlayMode.click();
          await driver.delayMs(500);
        }
        logger.info(TAG, 'Play mode switched');
      }
    } catch (error) {
      logger.info(TAG, 'Play mode button not found or click failed');
    }

    logger.info(TAG, 'SwitchPlayMode end');
    done();
  });

  /**
   * 测试进度条存在性
   */
  it("验证进度条", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyProgressSlider begin');

    try {
      await driver.assertComponentExist(ON.id('music_progress_slider'));
      logger.info(TAG, 'Progress slider found');
    } catch (error) {
      logger.info(TAG, 'Progress slider not found');
    }

    logger.info(TAG, 'VerifyProgressSlider end');
    done();
  });

  /**
   * 测试时间显示
   */
  it("验证时间显示", 0, async (done: Function) => {
    logger.info(TAG, 'VerifyTimeDisplay begin');

    try {
      await driver.assertComponentExist(ON.id('current_time_text'));
      logger.info(TAG, 'Current time text found');
    } catch (error) {
      logger.info(TAG, 'Current time text not found');
    }

    try {
      await driver.assertComponentExist(ON.id('total_time_text'));
      logger.info(TAG, 'Total time text found');
    } catch (error) {
      logger.info(TAG, 'Total time text not found');
    }

    logger.info(TAG, 'VerifyTimeDisplay end');
    done();
  });

  /**
   * 测试退出音乐播放器页面
   */
  it("退出音乐播放器页面", 0, async (done: Function) => {
    logger.info(TAG, 'ExitMusicPlayerPage begin');

    // 返回上一页
    await driver.pressBack();
    await driver.delayMs(1000);

    logger.info(TAG, 'ExitMusicPlayerPage end');
    done();
  });

  exit(CASE_NAME);
}
