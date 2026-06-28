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

const CASE: string = 'CalendarSwitch';
const TAG: string = '[CalendarSwitch_Test]';
const DELAY_MS: number = 500;

/**
 * 【日历切换案例】自动化测试用例
 * 主要功能：使用Swiper实现自定义日历年视图、月视图、周视图左右滑动切换年、月、周的效果。同时使用Tabs实现年视图、月视图、周视图之间的切换效果。
 * 还有使用Calendar Kit日历服务实现日程提醒的功能。
 * 执行步骤：
 * 1.月视图左右滑动切换月份（动效需手工用例进行测试）
 * 2.在月视图上点击日期，查看选中日期功能（只能断言日期被选中，其他需手工用例进行测试）
 * 3.周视图左右滑动切换周（动效需手工用例进行测试）
 * 4.年视图左右滑动切换年（动效需手工用例进行测试）
 * 5.点击顶部"年""月""周"按钮，查看视图切换效果（动效需手工用例进行测试）
 * 6.在年视图中点击某个月份，自动切换并跳转对应月的月视图（动效需手工用例进行测试）
 * 7.在月视图中点击选中一个日期，然后切换到周视图，查看显示对应的周视图（动效需手工用例进行测试）
 * 8.在周视图中点击选中一个日期，然后切换到月视图，查看显示对应的月视图（动效需手工用例进行测试）
 * 9.在月视图或周视图上点击选中一个日期，然后切换到年视图，查看显示对应的年视图（动效需手工用例进行测试）
 * 10.日程提醒功能（只做基础操作断言,实际功能需手工用例进行测试）
 */
export default function akiUsePracticeTest() {

  searchCaseClickIn('日历切换案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);
  // 当前显示的月份
  let month = 0;
  // 当前选中的日期
  let selectDate = 0;
  // 月视图点击日期对应的年
  let selectYear = 0;
  // 当前切换显示的年
  let currentYear = 0;
  // 应用是否添加日程信息
  let isAdd = false;
  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    month = data.data?.month;
    selectDate = data.data?.selectDate;
    selectYear = data.data?.selectYear;
    currentYear = data.data?.currentYear;
    isAdd = data.data?.isAdd;
  })

  /**
   * 1.月视图左右滑动切换月份（动效需手工用例进行测试）
   */
  it(CASE + '月视图左右滑动切换月份', 0, async (done: Function) => {
    // 首次安装进入案例页面，会弹日程读写功能授权弹窗，点击允许
    await driver.assertComponentExist(ON.text('允许'));
    let allowBtn = await driver.findComponent(ON.text('允许'));
    await allowBtn.click();
    await driver.delayMs(DELAY_MS);
    // 月视图左右滑动切换月份(往右切一次，往左切一次)
    let monthView = await driver.findComponent(ON.id('monthView'));
    // 获取月视图边框信息
    let rect = await monthView.getBounds();
    // 往右切一次
    await driver.swipe(rect.left + 10, rect.top, rect.left + 700, rect.top, 2000);
    await driver.delayMs(1000);
    // 往左切一次
    await driver.swipe(rect.left + 700, rect.top, rect.left + 10, rect.top, 2000);
    await driver.delayMs(1000);
    // 获取当月
    let todayMonth = new Date().getMonth() + 1;
    // 断言切换后的月份是否正确
    expect(month).assertEqual(todayMonth);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 2.在月视图上点击日期，查看选中日期功能（只能断言日期被选中，其他需手工用例进行测试）
   */
  it(CASE + '在月视图上点击日期，查看选中日期功能', 0, async (done: Function) => {
    // 点击日期20的Text
    await driver.assertComponentExist(ON.text('20'));
    let date = await driver.findComponent(ON.text('20'));
    await date.click();
    await driver.delayMs(DELAY_MS);
    // 断言日期被选中
    expect(20).assertEqual(selectDate);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 3.周视图左右滑动切换周（动效需手工用例进行测试）
   */
  it(CASE + '周视图左右滑动切换周', 0, async (done: Function) => {
    // 点击切换到周视图
    await driver.assertComponentExist(ON.id('week'));
    let week = await driver.findComponent(ON.id('week'));
    await week.click();
    await driver.delayMs(DELAY_MS);
    let weekView = await driver.findComponent(ON.id('weekView'));
    // 获取周视图边框信息
    let rect = await weekView.getBounds();
    // 往右切一次，往左切一次
    await driver.swipe(rect.left + 10, rect.top, rect.left + 700, rect.top, 2000);
    await driver.delayMs(1000);
    await driver.swipe(rect.left + 700, rect.top, rect.left + 10, rect.top, 2000);
    await driver.delayMs(1000);
    // 断言左右切换后日期是否包含20
    await driver.assertComponentExist(ON.text('20'));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 4.年视图左右滑动切换年（动效需手工用例进行测试）
   */
  it(CASE + '年视图左右滑动切换年', 0, async (done: Function) => {
    // 点击切换到年视图
    await driver.assertComponentExist(ON.id('year'));
    let year = await driver.findComponent(ON.id('year'));
    await year.click();
    await driver.delayMs(DELAY_MS);
    let yearView = await driver.findComponent(ON.id('yearView'));
    let rect = await yearView.getBounds();
    // 往右切一次，往左切一次
    await driver.swipe(rect.left + 10, rect.top, rect.left + 700, rect.top, 2000);
    await driver.delayMs(1000);
    await driver.swipe(rect.left + 700, rect.top, rect.left + 10, rect.top, 2000);
    await driver.delayMs(1000);
    // 获取今年
    let todayYear = new Date().getFullYear();
    await driver.delayMs(DELAY_MS);
    // 断言切换后的年份是否正确
    expect(todayYear).assertEqual(currentYear);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 5.点击顶部"年""月""周"按钮，查看视图切换效果（动效需手工用例进行测试）
   */
  it(CASE + '点击顶部"年""月""周"按钮，查看视图切换效果', 0, async (done: Function) => {
    // 依次点击"月""周""年"
    await driver.assertComponentExist(ON.id('month'));
    let month = await driver.findComponent(ON.id('month'));
    await month.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('week'));
    let week = await driver.findComponent(ON.id('week'));
    await week.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('year'));
    let year = await driver.findComponent(ON.id('year'));
    await year.click();
    await driver.delayMs(DELAY_MS);
    // 断言最终是否显示年视图
    await driver.assertComponentExist(ON.id('yearView'));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 6.在年视图中点击某个月份，自动切换并跳转对应月的月视图（动效需手工用例进行测试）
   */
  it(CASE + '在年视图中点击某个月份，自动切换并跳转对应月的月视图', 0, async (done: Function) => {
    // 在年视图中点击8月
    await driver.assertComponentExist(ON.id('month8'));
    let selectMonth = await driver.findComponent(ON.id('month8'));
    await selectMonth.click();
    await driver.delayMs(1000);
    // 断言月视图是否显示8月
    expect(8).assertEqual(month);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 7.在月视图中点击选中一个日期，然后切换到周视图，查看显示对应的周视图（动效需手工用例进行测试）
   */
  it(CASE + '在月视图中点击选中一个日期，然后切换到周视图，查看显示对应的周视图', 0, async (done: Function) => {
    // 月视图点击日期15
    await driver.assertComponentExist(ON.text('15'));
    let date = await driver.findComponent(ON.text('15'));
    await date.click();
    await driver.delayMs(DELAY_MS);
    // 切换到周视图
    await driver.assertComponentExist(ON.id('week'));
    let week = await driver.findComponent(ON.id('week'));
    await week.click();
    await driver.delayMs(DELAY_MS);
    // 断言是否包含日期15
    await driver.assertComponentExist(ON.text('15'));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 8.在周视图中点击选中一个日期，然后切换到月视图，查看显示对应的月视图（动效需手工用例进行测试）
   */
  it(CASE + '在周视图中点击选中一个日期，然后切换到月视图，查看显示对应的月视图', 0, async (done: Function) => {
    // 周视图点击日期15
    await driver.assertComponentExist(ON.text('15'));
    let date = await driver.findComponent(ON.text('15'));
    await date.click();
    await driver.delayMs(DELAY_MS);
    // 切换到月视图
    await driver.assertComponentExist(ON.id('month'));
    let month = await driver.findComponent(ON.id('month'));
    await month.click();
    await driver.delayMs(DELAY_MS);
    // 断言是否包含日期15
    await driver.assertComponentExist(ON.text('15'));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 9.在月视图或周视图上点击选中一个日期，然后切换到年视图，查看显示对应的年视图（动效需手工用例进行测试）
   */
  it(CASE + '在月视图或周视图上点击选中一个日期，然后切换到年视图，查看显示对应的年视图', 0, async (done: Function) => {
    let monthView = await driver.findComponent(ON.id('monthView'));
    let rect = await monthView.getBounds();
    // 循环往左滑，滑到1月时，说明是下一年了，点击1月的一个日期，然后切换到年视图，查看年份是否正确
    while (true) {
      // 往左切一次
      await driver.swipe(rect.left + 700, rect.top, rect.left + 10, rect.top, 2000);
      await driver.delayMs(1000);
      // 查看月份是否是1月
      if (month === 1) {
        break;
      }
    }
    // 点击任意一个日期，比如日期20
    await driver.assertComponentExist(ON.text('20'));
    let date = await driver.findComponent(ON.text('20'));
    await date.click();
    await driver.delayMs(DELAY_MS);
    // 切换到年视图
    await driver.assertComponentExist(ON.id('year'));
    let year = await driver.findComponent(ON.id('year'));
    await year.click();
    await driver.delayMs(1000);
    // 断言月视图选择日期时对应的年和切换到年视图的年(年视图中Grid的id为年)是否一致
    await driver.assertComponentExist(ON.id(selectYear.toString()));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 10.日程提醒功能（只做基础操作断言,实际功能需手工用例进行测试）
   */
  it(CASE + '日程提醒功能', 0, async (done: Function) => {
    // 切换到月视图
    await driver.assertComponentExist(ON.id('month'));
    let month = await driver.findComponent(ON.id('month'));
    await month.click();
    await driver.delayMs(DELAY_MS);
    // 点击新建日程
    await driver.assertComponentExist(ON.id('schedulePoint'));
    let date = await driver.findComponent(ON.id('schedulePoint'));
    await date.click();
    await driver.delayMs(1000);
    // 输入标题
    let title = await driver.findComponent(ON.id('title'));
    await title.inputText('aaa');
    await driver.delayMs(DELAY_MS);
    // 输入地点
    let location = await driver.findComponent(ON.id('location'));
    await location.inputText('bbb');
    await driver.delayMs(DELAY_MS);
    // 点击开始时间
    await driver.assertComponentExist(ON.id('startTime'));
    let startTime = await driver.findComponent(ON.id('startTime'));
    await startTime.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('确定'));
    let startTimeYesBtn = await driver.findComponent(ON.text('确定'));
    await startTimeYesBtn.click();
    await driver.delayMs(DELAY_MS);
    // 点击结束时间
    await driver.assertComponentExist(ON.id('endTime'));
    let endTime = await driver.findComponent(ON.id('endTime'));
    await endTime.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('确定'));
    let endTimeYesBtn = await driver.findComponent(ON.text('确定'));
    await endTimeYesBtn.click();
    await driver.delayMs(DELAY_MS);
    // 提醒时间选择1分钟前
    await driver.assertComponentExist(ON.id('reminderTime'));
    let reminderTime = await driver.findComponent(ON.id('reminderTime'));
    await reminderTime.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('1分钟前'));
    let time = await driver.findComponent(ON.text('1分钟前'));
    await time.click();
    await driver.delayMs(DELAY_MS);
    // 输入说明
    let describe = await driver.findComponent(ON.id('describe'));
    await describe.inputText('ccc');
    await driver.delayMs(DELAY_MS);
    // 点击添加
    await driver.assertComponentExist(ON.text('添加'));
    let add = await driver.findComponent(ON.text('添加'));
    await add.click();
    await driver.delayMs(2000);
    // 断言应用是否添加日程信息
    expect(true).assertEqual(isAdd);
    done();
  })

  exit('日历切换案例');
}