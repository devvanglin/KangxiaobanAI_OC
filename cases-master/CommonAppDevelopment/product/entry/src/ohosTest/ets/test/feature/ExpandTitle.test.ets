import searchCaseClickIn from "../common/SearchCaseClickIn.test";
import { Driver, ON } from "@ohos.UiTest";
import { expect, it } from "@ohos/hypium";
import exit from "../common/Exit.test";

/**
 * 【标题下拉缩放案例】自动化测试用例
 * 1. 下拉列表至一定距离并松手，根据滑动距离执行回弹
 * 2. 下拉列表至一定距离并松手，根据滑动距离执行展开
 */
export default function expandTitleTest() {
  // 引入common文件中通用脚本
  searchCaseClickIn('标题下拉缩放案例');

  const driver = Driver.create();

  /**
   * 关联用例: 下拉列表至一定距离并松手，根据滑动距离执行回弹
   * 执行步骤:
   * 1. 短距离下拉列表
   * 2. 通过列表拉动前后的标题高度是否相等进行验证
   */
  it("短距离下拉列表", 0, async (done: Function) => {
    const beforeTitle = await driver.findComponent(ON.id("title"));
    const beforeBounds = await beforeTitle.getBounds();
    const beforeHeight = beforeBounds.bottom - beforeBounds.top;
    await driver.swipe(500, 600, 500, 680, 200);
    const afterTitle = await driver.findComponent(ON.id("title"));
    const afterBounds = await afterTitle.getBounds();
    const afterHeight = afterBounds.bottom - afterBounds.top;
    console.log(`beforeHeight: ${beforeHeight}, afterHeight: ${afterHeight}`);
    expect(afterHeight > beforeHeight).assertEqual(true); // 断言短距离下拉列表后标题高度是否大于初始高度
    done();
  })

  /**
   * 关联用例: 下拉列表至一定距离并松手，根据滑动距离执行展开
   * 执行步骤:
   * 1. 长距离下拉列表
   * 2. 通过列表拉动前后的标题高度是否存在一定差异进行验证
   */
  it("长距离下拉列表", 0, async (done: Function) => {
    const beforeTitle = await driver.findComponent(ON.id("title"));
    const beforeBounds = await beforeTitle.getBounds();
    const beforeHeight = beforeBounds.bottom - beforeBounds.top;
    await driver.swipe(500, 800, 500, 1800, 200);
    const afterTitle = await driver.findComponent(ON.id("title"));
    const afterBounds = await afterTitle.getBounds();
    const afterHeight = afterBounds.bottom - afterBounds.top;
    console.log(`beforeHeight: ${beforeHeight}, afterHeight: ${afterHeight}`);
    expect(afterHeight === beforeHeight).assertEqual(true); // 断言长距离下拉列表后标题高度不变

    done();
  })

  exit('标题下拉缩放案例');
}
