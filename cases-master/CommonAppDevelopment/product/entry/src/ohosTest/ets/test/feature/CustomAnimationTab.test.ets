import { it } from "@ohos/hypium";
import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Driver, ON, UiDirection } from "@kit.TestKit";
import { Point } from '@ohos.UiTest';
import { logger } from "utils";
import exit from "../common/Exit.test";

/**
 * 【自定义动效tab案例】自动化测试用例
 * 1. 快速滑动，背景条自动左右滑动
 * 2. 滑动距离不足一般，背景条自动回弹
 * 3. 滑动距离超过一半，背景条自动滑动至下一页签
 * 4. 点击页签，背景条跳转至对应页签
 * 5. 背景条跟随页签条滑动
 */
export default function customAnimationTabTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('自定义动效tab')

  const driver = Driver.create();

  /**
   * 关联用例: 快速滑动，背景条自动左右滑动
   * 执行步骤:
   * 1. 快速滑动tab页
   * 2. 通过对比背景条中心点与下一页签中心点是否相等进行验证
   */
  it("短距离脱手滑动", 0, async (done: Function) => {
    await driver.fling(UiDirection.RIGHT, 4000);
    await driver.delayMs(1000);
    // 验证背景条滑动至下一页签
    const afterTabBar = await driver.findComponent(ON.id("1"));
    const afterTabCenter = await afterTabBar.getBoundsCenter();
    const afterBackgroundBar = await driver.findComponent(ON.id("backgroundBar"));
    const afterBackgroundCenter = await afterBackgroundBar.getBoundsCenter();
    if (!isPointEqual(afterTabCenter, afterBackgroundCenter)) {
      throw new Error();
    }
    done();
  })

  /**
   * 关联用例: 滑动距离不足一般，背景条自动回弹
   * 执行步骤:
   * 1. 短距离缓慢滑动tab页并松手
   * 2. 通过对比背景条中心点与当前页签中心点是否相等进行验证
   */
  it("短距离滑动", 0, async (done: Function) => {
    await driver.swipe(1000, 1000, 600, 1000, 400);
    await driver.delayMs(1000);
    // 验证背景条回弹至当前页签
    const afterTabBar = await driver.findComponent(ON.id("1"));
    const afterTabCenter = await afterTabBar.getBoundsCenter();
    const afterBackgroundBar = await driver.findComponent(ON.id("backgroundBar"));
    const afterBackgroundCenter = await afterBackgroundBar.getBoundsCenter();
    if (!isPointEqual(afterTabCenter, afterBackgroundCenter)) {
      throw new Error();
    }
    done();
  })

  /**
   * 关联用例: 滑动距离超过一半，背景条自动滑动至下一页签
   * 执行步骤:
   * 1. 长距离缓慢滑动tab页并松手
   * 2. 通过对比背景条中心点与下一页签中心点是否相等进行验证
   */
  it("长距离滑动", 0, async (done: Function) => {
    await driver.swipe(1000, 1000, 200, 1000, 400);
    await driver.delayMs(1000);
    // 验证背景条跳转至下个页签位置
    const afterTabBar = await driver.findComponent(ON.id("2"));
    const afterTabCenter = await afterTabBar.getBoundsCenter();
    const afterBackgroundBar = await driver.findComponent(ON.id("backgroundBar"));
    const afterBackgroundCenter = await afterBackgroundBar.getBoundsCenter();
    logger.info("CustomAnimationTab",
      `left: ${afterTabCenter.x}, right: ${afterTabCenter.y}, left: ${afterBackgroundCenter.x}, right: ${afterBackgroundCenter.y}`)
    if (!isPointEqual(afterTabCenter, afterBackgroundCenter)) {
      throw new Error();
    }
    done();
  })

  /**
   * 关联用例: 背景条跟随页签条滑动
   * 执行步骤:
   * 1. 缓慢滑动页签条
   * 2. 通过对比背景条滑动距离与任一页签滑动距离是否相等进行验证
   */
  it("页签条滑动", 0, async (done: Function) => {
    // 验证背景条与页签条一起滑动
    const beforeTabBar = await driver.findComponent(ON.id("4"));
    const beforeTabCenter = await beforeTabBar.getBoundsCenter();
    const beforeBackgroundBar = await driver.findComponent(ON.id("backgroundBar"));
    const beforeBoundCenter = await beforeBackgroundBar.getBoundsCenter();
    await driver.swipe(1000, 445, 900, 445, 200);
    const afterTabBar = await driver.findComponent(ON.id("4"));
    const afterTabCenter = await afterTabBar.getBoundsCenter();
    const afterBackgroundBar = await driver.findComponent(ON.id("backgroundBar"));
    const afterBoundCenter = await afterBackgroundBar.getBoundsCenter();
    if (!equals(Math.abs(beforeBoundCenter.x - afterBoundCenter.x), Math.abs(beforeTabCenter.x - afterTabCenter.x),
      5)) {
      throw new Error();
    }
    await driver.delayMs(1000);
    done();
  })


  /**
   * 关联用例: 点击页签，背景条跳转至对应页签
   * 执行步骤:
   * 1. 点击目标页签
   * 2. 通过对比背景条中心点与目标页签中心点是否相等进行验证
   */
  it("点击页签", 0, async (done: Function) => {
    const beforeTabBar = await driver.findComponent(ON.text("三方库"));
    await beforeTabBar.click();
    await driver.delayMs(1000);
    // 验证背景条滑动至选中页签项
    const afterTabBar = await driver.findComponent(ON.id('3'));
    const afterTabCenter = await afterTabBar.getBoundsCenter();
    const afterBackgroundBar = await driver.findComponent(ON.id("backgroundBar"));
    const afterBackgroundCenter = await afterBackgroundBar.getBoundsCenter();
    if (!isPointEqual(afterTabCenter, afterBackgroundCenter)) {
      throw new Error();
    }
    done();
  })

  exit('自定义动效tab');

}

function isPointEqual(obj1: Point, obj2: Point, offset: number = 0): boolean {
  // 给定5个像素作为误差
  return equals(obj1.x + offset, obj2.x, 5) &&
  equals(obj1.y + offset, obj2.y, 5);
}

function equals(obj1: number, obj2: number, epsilon: number = Number.EPSILON): boolean {
  return Math.abs(obj1 - obj2) < epsilon;
}