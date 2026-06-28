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

const CASE: string = 'BarChart';
const TAG: string = '[BarChart_Test]';
const DELAY_MS: number = 500;

/**
 * 【MpChart图表实现案例】自动化测试用例
 * 主要功能：MpChart是一个包含各种类型图表的三方图表库，主要用于业务数据汇总，例如销售数据走势图，股价走势图等场景中使用，方便开发者快速实现图表UI。
 * 本案例使用三方库MpChart实现柱状图UI效果。如堆叠数据类型显示，Y轴是否显示，左Y轴位置，右Y轴位置，是否显示X轴，是否绘制背景色，是否设置MarkerView等。
 * 执行步骤：
 * 1.查看MpChart图表中不同数据类型的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 2.查看MpChart图表中不同X轴位置的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 3.查看MpChart图表中X轴是否显示的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 4.查看MpChart图表中左Y轴是否显示的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 5.查看MpChart图表中左Y轴表外/左Y轴表内的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 6.查看MpChart图表中左Y轴LimitLine是否在数据后的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 7.查看MpChart图表中左Y轴LimitLine位置的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 8.查看MpChart图表中右Y轴是否显示的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 9.查看MpChart图表中右Y轴表外/右Y轴表内的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 10.查看MpChart图表中是否绘制背景色的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 * 11.查看MpChart图表中是否设置MarkerView的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
 */
export default function akiUsePracticeTest() {
  searchCaseClickIn('MpChart图表实现案例');
  let driver = Driver.create();
  logger.info(TAG, `${CASE} begin`);
  // 是否选中堆叠
  let stackChecked: boolean = false;
  // 是否打开"X轴是否显示"开关
  let xAxisChecked: boolean = false;
  // 是否打开"左Y轴是否显示"开关
  let leftYAxisChecked: boolean = false;
  // 是否选中左Y轴表内
  let inSideChartChecked: boolean = false;
  // 是否打开"左Y轴LimitLine是否在数据后"开关
  let isShowLimitLineChecked: boolean = true;
  // 是否选中Lower
  let lowerChecked: boolean = false;
  // 是否打开"右Y轴是否显示"开关
  let rightYAxisChecked: boolean = true;
  // 是否选中右Y轴表内
  let rightYAxisInSideChecked: boolean = false;
  // 是否打开"是否绘制背景色"开关
  let isDrawBackgroundChecked: boolean = true;
  // 是否打开"是否设置MarkerView"开关
  let isShowMarkerViewChecked: boolean = false;
  emitter.on({
    eventId: 0, priority: 0
  }, (data: emitter.EventData) => {
    stackChecked = data.data?.stackChecked;
    xAxisChecked = data.data?.xAxisChecked;
    leftYAxisChecked = data.data?.leftYAxisChecked;
    inSideChartChecked = data.data?.inSideChartChecked;
    isShowLimitLineChecked = data.data?.isShowLimitLineChecked;
    lowerChecked = data.data?.lowerChecked;
    rightYAxisChecked = data.data?.rightYAxisChecked;
    rightYAxisInSideChecked = data.data?.rightYAxisInSideChecked;
    isDrawBackgroundChecked = data.data?.isDrawBackgroundChecked;
    isShowMarkerViewChecked = data.data?.isShowMarkerViewChecked;
  })


  /**
   * 1.查看MpChart图表中不同数据类型的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中不同数据类型的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('normal'));
    // 点击普通
    let normal = await driver.findComponent(ON.id('normal'));
    await normal.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('gradient'));
    // 点击渐变
    let gradient = await driver.findComponent(ON.id('gradient'));
    await gradient.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('stack'));
    // 点击堆叠
    let stack = await driver.findComponent(ON.id('stack'));
    await stack.click();
    await driver.delayMs(DELAY_MS);
    // 断言是否选中堆叠选项
    expect(true).assertEqual(stackChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 2.查看MpChart图表中不同X轴位置的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中不同X轴位置的展示效果', 0, async (done: Function) => {
    // 点击X轴位置右侧下拉选项
    await driver.assertComponentExist(ON.id('xAxisLocation'));
    let xAxisLocation = await driver.findComponent(ON.id('xAxisLocation'));
    await xAxisLocation.click();
    await driver.delayMs(DELAY_MS);
    // 选择"Top"
    await driver.assertComponentExist(ON.text('Top'));
    let top = await driver.findComponent(ON.text('Top'));
    await top.click();
    await driver.delayMs(DELAY_MS);
    // 选择"Bottom"
    await xAxisLocation.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('Bottom'));
    let bottom = await driver.findComponent(ON.text('Bottom'));
    await bottom.click();
    await driver.delayMs(DELAY_MS);
    // 选择"Both Side"
    await xAxisLocation.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('Both Side'));
    let bothSide = await driver.findComponent(ON.text('Both Side'));
    await bothSide.click();
    await driver.delayMs(DELAY_MS);
    // 选择"Top InSide"
    await xAxisLocation.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('Top InSide'));
    let topInSide = await driver.findComponent(ON.text('Top InSide'));
    await topInSide.click();
    await driver.delayMs(DELAY_MS);
    // 选择"Bottom InSide"
    await xAxisLocation.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.text('Bottom InSide'));
    let bottomInSide = await driver.findComponent(ON.text('Bottom InSide'));
    await bottomInSide.click();
    await driver.delayMs(DELAY_MS);
    // 断言最后是否选择了Bottom InSide选项
    await driver.assertComponentExist(ON.text('Bottom InSide'));
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 3.查看MpChart图表中X轴是否显示的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中X轴是否显示的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('xAxisToggle'));
    // 点击关闭X轴是否显示开关
    let xAxisToggle = await driver.findComponent(ON.id('xAxisToggle'));
    await xAxisToggle.click();
    await driver.delayMs(DELAY_MS);
    // 点击打开X轴是否显示开关
    await xAxisToggle.click();
    await driver.delayMs(DELAY_MS);
    // 断言打开X轴是否显示开关
    expect(true).assertEqual(xAxisChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 4.查看MpChart图表中左Y轴是否显示的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中左Y轴是否显示的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('leftYAxisToggle'));
    // 点击关闭左Y轴是否显示开关
    let leftYAxisToggle = await driver.findComponent(ON.id('leftYAxisToggle'));
    await leftYAxisToggle.click();
    await driver.delayMs(DELAY_MS);
    // 点击打开左Y轴是否显示开关
    await leftYAxisToggle.click();
    await driver.delayMs(DELAY_MS);
    // 断言打开左Y轴是否显示开关
    expect(true).assertEqual(leftYAxisChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 5.查看MpChart图表中左Y轴表外/左Y轴表内的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中左Y轴表外/左Y轴表内的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('scroll'));
    let scroll = await driver.findComponent(ON.id('scroll'));
    // 获取Scroll边框信息
    let rect = await scroll.getBounds();
    // 滑动到左Y轴表外/左Y轴表内位置
    await driver.swipe(rect.left, rect.bottom - 100, rect.left, rect.bottom - 1200, 1000);
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('outSideChart'));
    // 点击左Y轴表外
    let outSideChart = await driver.findComponent(ON.id('outSideChart'));
    await outSideChart.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('inSideChart'));
    // 点击左Y轴表内
    let inSideChart = await driver.findComponent(ON.id('inSideChart'));
    await inSideChart.click();
    await driver.delayMs(DELAY_MS);
    // 断言是否选中左Y轴表内
    expect(true).assertEqual(inSideChartChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 6.查看MpChart图表中左Y轴LimitLine是否在数据后的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中左Y轴LimitLine是否在数据后的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('isShowLimitLine'));
    // 点击打开"左Y轴LimitLine是否在数据后"开关
    let isShowLimitLine = await driver.findComponent(ON.id('isShowLimitLine'));
    await isShowLimitLine.click();
    await driver.delayMs(DELAY_MS);
    // 点击关闭"左Y轴LimitLine是否在数据后"开关
    await isShowLimitLine.click();
    await driver.delayMs(DELAY_MS);
    // 断言关闭"左Y轴LimitLine是否在数据后"开关
    expect(false).assertEqual(isShowLimitLineChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 7.查看MpChart图表中左Y轴LimitLine位置的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中左Y轴LimitLine位置的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('both'));
    // 点击Both
    let both = await driver.findComponent(ON.id('both'));
    await both.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('none'));
    // 点击None
    let none = await driver.findComponent(ON.id('none'));
    await none.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('upper'));
    // 点击Upper
    let upper = await driver.findComponent(ON.id('upper'));
    await upper.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id('lower'));
    // 点击Lower
    let lower = await driver.findComponent(ON.id('lower'));
    await lower.click();
    await driver.delayMs(1000);
    // 断言是否选中Lower
    expect(true).assertEqual(lowerChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 8.查看MpChart图表中右Y轴是否显示的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中右Y轴是否显示的展示效果', 0, async (done: Function) => {
    // 滑动到最底部
    const scroll = await driver.findComponent(ON.id('scroll'));
    await scroll.scrollToBottom(40000)
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('rightYAxis'));
    // 点击打开"右Y轴是否显示"开关
    let rightYAxis = await driver.findComponent(ON.id('rightYAxis'));
    await rightYAxis.click();
    await driver.delayMs(DELAY_MS);
    // 点击关闭"右Y轴是否显示"开关
    await rightYAxis.click();
    await driver.delayMs(DELAY_MS);
    // 断言关闭右Y轴是否显示开关
    expect(false).assertEqual(rightYAxisChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 9.查看MpChart图表中右Y轴表外/右Y轴表内的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中右Y轴表外/右Y轴表内的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('rightYAxis'));
    // 点击打开"右Y轴是否显示"开关
    let rightYAxis = await driver.findComponent(ON.id('rightYAxis'));
    await rightYAxis.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('rightYAxisOutSide'));
    // 点击右Y轴表外
    let rightYAxisOutSide = await driver.findComponent(ON.id('rightYAxisOutSide'));
    await rightYAxisOutSide.click();
    await driver.delayMs(DELAY_MS);
    await driver.assertComponentExist(ON.id('rightYAxisInSide'));
    // 点击右Y轴表内
    let rightYAxisInSide = await driver.findComponent(ON.id('rightYAxisInSide'));
    await rightYAxisInSide.click();
    await driver.delayMs(DELAY_MS);
    // 断言是否选中右Y轴表内
    expect(true).assertEqual(rightYAxisInSideChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 10.查看MpChart图表中是否绘制背景色的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中是否绘制背景色的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('isDrawBackground'));
    // 点击打开"是否绘制背景色"开关
    let isDrawBackground = await driver.findComponent(ON.id('isDrawBackground'));
    await isDrawBackground.click();
    await driver.delayMs(DELAY_MS);
    // 点击关闭"是否绘制背景色"开关
    await isDrawBackground.click();
    await driver.delayMs(DELAY_MS);
    // 断言关闭是否绘制背景色开关
    expect(false).assertEqual(isDrawBackgroundChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  /**
   * 11.查看MpChart图表中是否设置MarkerView的展示效果。（只能做基础点击，选择等操作，实际图表效果需要手工测试）
   */
  it(CASE + '查看MpChart图表中是否设置MarkerView的展示效果', 0, async (done: Function) => {
    await driver.assertComponentExist(ON.id('isShowMarkerView'));
    // 点击关闭"是否设置MarkerView"开关
    let isShowMarkerView = await driver.findComponent(ON.id('isShowMarkerView'));
    await isShowMarkerView.click();
    await driver.delayMs(DELAY_MS);
    // 点击打开"是否设置MarkerView"开关
    await isShowMarkerView.click();
    await driver.delayMs(DELAY_MS);
    // 断言打开是否设置MarkerView开关
    expect(true).assertEqual(isShowMarkerViewChecked);
    await driver.delayMs(DELAY_MS);
    done();
  })

  exit('MpChart图表实现案例');
}