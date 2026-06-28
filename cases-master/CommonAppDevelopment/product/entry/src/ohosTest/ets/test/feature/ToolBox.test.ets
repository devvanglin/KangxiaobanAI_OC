import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Component, Driver, ON } from "@ohos.UiTest";
import { it } from "@ohos/hypium";
import { Point } from "@ohos.UiTest";
import exit from "../common/Exit.test";


/**
 * 【悬浮工具箱案例】自动化测试用例
 * 1.点击悬浮球，工具栏动效展开
 * 2.拖拽悬浮球，悬浮球跟随手势滑动
 * 3.长按悬浮球，禁用/启用悬浮球，不再响应/再次响应悬浮球本身的点击事件
 */
export default function toolBoxTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('悬浮工具箱案例');

  const driver = Driver.create();

  /**
   * 关联用例: 点击悬浮球，工具栏动效展开/关闭
   * 执行步骤:
   * 1. 点击悬浮球
   * 2. 通过查看工具栏是否存在/不存在进行验证
   */
  it("单击悬浮工具箱", 0, async (done: Function) => {
    let button: Component = await driver.findComponent(ON.id("button"));
    await button.click();
    await driver.delayMs(1000);
    await driver.assertComponentExist(ON.id("1"));
    await driver.delayMs(1000);
    await button.click();
    const toolBox = await driver.findComponent(ON.id("1"));
    await driver.delayMs(1000);
    console.log(`单击悬浮窗, ${toolBox}`);
    if (toolBox !== null) {
      throw new Error("测试用例出错");
    }
    await driver.delayMs(500);
    done();
  })

  /**
   * 关联用例: 长按悬浮球，禁用/启用悬浮球，不再响应/再次响应悬浮球本身的点击事件
   * 执行步骤:
   * 1. 长按悬浮球
   * 2. 通过单击悬浮球查看工具栏是否响应/不响应进行验证
   */
  it("长按悬浮工具箱", 0, async (done: Function) => {
    let button: Component = await driver.findComponent(ON.id("button"));
    await button.longClick();
    await driver.delayMs(500);
    await button.click();
    let toolBox: Component = await driver.findComponent(ON.id("1"));
    if (toolBox !== null) {
      throw new Error("测试用例出错");
    }
    button = await driver.findComponent(ON.id("button"));
    await button.click();
    await driver.delayMs(500);
    button = await driver.findComponent(ON.id("button"));
    await button.longClick();
    await driver.delayMs(500);
    await button.click();
    await driver.assertComponentExist(ON.id("1"));
    await driver.delayMs(500);
    done();
  })

  /**
   * 关联用例: 拖拽悬浮球，悬浮球跟随手势滑动
   * 执行步骤:
   * 1. 拖拽悬浮球
   * 2. 通过查看拖拽前后悬浮球位置之差是否在精度范围内验证
   */
  it("拖拽悬浮工具箱", 0, async (done: Function) => {
    let button: Component = await driver.findComponent(ON.id("button"));
    let beforeCenter: Point = await button.getBoundsCenter();
    await driver.swipe(beforeCenter.x, beforeCenter.y, beforeCenter.x + 600, beforeCenter.y + 600);
    await driver.delayMs(500);
    button = await driver.findComponent(ON.id("button"));
    let afterCenter = await button.getBoundsCenter();
    console.log(`${beforeCenter.x}, ${beforeCenter.y}, ${afterCenter.x}, ${afterCenter.y}`)
    if (!isPointEqual(beforeCenter, afterCenter, 600)) {
      throw new Error("测试用例出错")
    }
    await driver.delayMs(500);
    done();
  })

  exit('悬浮工具箱案例')
}

function isPointEqual(obj1: Point, obj2: Point, offset: number): boolean {
  // 给定5个像素作为误差
  return equals(obj1.x + offset, obj2.x, 8) &&
  equals(obj1.y + offset, obj2.y, 8);
}

function equals(obj1: number, obj2: number, epsilon: number = Number.EPSILON): boolean {
  return Math.abs(obj1 - obj2) < epsilon;
}