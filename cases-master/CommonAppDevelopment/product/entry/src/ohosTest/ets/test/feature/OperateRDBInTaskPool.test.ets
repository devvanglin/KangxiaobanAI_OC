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
import { logger } from 'utils';
import searchCaseClickIn from '../common/SearchCaseClickIn.test';
import exit from '../common/Exit.test';

const CASE: string = 'OperateRDBInTaskPool'; // 案例名称
const CASE_NAME: string = '在TaskPool线程中操作关系型数据库实现案例'; // 案例中文名称
const TAG: string = '[OperateRDBInTaskPool_Test]';

/**
 * 【在TaskPool线程中操作关系型数据库实现案例】自动化测试用例
 * 1. 仅第一次进入点击同步通讯录数据按钮，进入通讯录列表页
 * 2. 点击添加通讯录好友按钮，进入新增联系人页，分别输入姓名：艾森宝，电话：18855558888，邮箱：aisengbao@example.com,地址：安徽省合肥市
 *    点击“√”保存按钮，再点击弹框中的确认选项，好友添加成功并返回通讯录列表页刷新列表数据。
 * 3. 点击通讯录好友【艾伦】进入详情页
 * 4. 点击右上角菜单按钮弹出bindSheet弹窗，选中编辑项，跳转至编辑联系人页面，修改姓名：艾伦->艾斯基,电话：199999999->199998888,
 *    点击“√”保存按钮，再点击弹框中的确认选项，好友信息修改成功并返回联系人详情页且刷新数据。
 * 5. 点击右上角按钮弹出bindSheet弹窗，选中删除项，删除弹窗弹出，再点击删除项，好友信息删除成功并返回通讯录列表页刷新列表数据。
 */
export default function operateRDBInTaskPoolTest() {
  // 搜索并进入
  searchCaseClickIn(CASE_NAME);

  /**
   * 同步通讯录数据
   */
  it(CASE + '_Batch_Insert', 0, async (done: Function) => {
    let driver = Driver.create();
    // 点击同步通讯录数据按钮
    await driver.assertComponentExist(ON.text('点击同步通讯录数据'));
    const display = await driver.findComponent(ON.text('点击同步通讯录数据'));
    await display.click();
    await driver.delayMs(5000);

    // 判断通讯录列表是否存在，且数据是否加载
    await driver.assertComponentExist(ON.id('address_book_list'));
    await driver.assertComponentExist(ON.text('艾德里安'));
    await driver.assertComponentExist(ON.text('亚历山大'));

    done();
  })

  /**
   * 添加通讯录好友
   */
  it(CASE + '_Insert', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击添加通讯录好友按钮
    await driver.assertComponentExist(ON.id('taskpool_add_button'));
    const display = await driver.findComponent(ON.id('taskpool_add_button'));
    await display.click();
    await driver.delayMs(1000);

    // 点击“姓名”框
    logger.info(TAG, `TextInput_Name`);
    await driver.assertComponentExist(ON.id('taskpool_textinput_name'));
    const name = await driver.findComponent(ON.id('taskpool_textinput_name'));
    await name.click();
    await driver.delayMs(1000);

    // 输入姓名“艾森宝”
    await driver.assertComponentExist(ON.id('taskpool_textinput_name'));
    const textInputName = await driver.findComponent(ON.id('taskpool_textinput_name'));
    await textInputName.inputText('艾森宝');
    await driver.delayMs(1000);

    // 点击“电话”框
    logger.info(TAG, `TextInput_Phone`);
    await driver.assertComponentExist(ON.id('taskpool_textinput_phone'));
    const phone = await driver.findComponent(ON.id('taskpool_textinput_phone'));
    await phone.click();
    await driver.delayMs(1000);

    // 输入电话“18855558888”
    await driver.assertComponentExist(ON.id('taskpool_textinput_phone'));
    const textInputPhone = await driver.findComponent(ON.id('taskpool_textinput_phone'));
    await textInputPhone.inputText('18855558888');
    await driver.delayMs(1000);

    // 点击“邮箱”框
    logger.info(TAG, `TextInput_Email`);
    await driver.assertComponentExist(ON.id('taskpool_textinput_email'));
    const email = await driver.findComponent(ON.id('taskpool_textinput_email'));
    await email.click();
    await driver.delayMs(1000);

    // 输入邮箱“aisengbao@example.com”
    await driver.assertComponentExist(ON.id('taskpool_textinput_email'));
    const textInputEmail = await driver.findComponent(ON.id('taskpool_textinput_email'));
    await textInputEmail.inputText('aisengbao@example.com');
    await driver.delayMs(1000);

    // 点击“地址”框
    logger.info(TAG, `TextInput_Address`);
    await driver.assertComponentExist(ON.id('taskpool_textinput_address'));
    const address = await driver.findComponent(ON.id('taskpool_textinput_address'));
    await address.click();
    await driver.delayMs(1000);

    // 输入地址“安徽省合肥市”
    await driver.assertComponentExist(ON.id('taskpool_textinput_address'));
    const textInputAddress = await driver.findComponent(ON.id('taskpool_textinput_address'));
    await textInputAddress.inputText('安徽省合肥市');
    await driver.delayMs(1000);

    // 点击“√”保存按钮
    await driver.assertComponentExist(ON.id('taskpool_button_ok'));
    const okButton = await driver.findComponent(ON.id('taskpool_button_ok'));
    await okButton.click();
    await driver.delayMs(1000);

    // 点击弹框中的确认选项
    await driver.assertComponentExist(ON.text('确定').type('Button'));
    const primaryButton = await driver.findComponent(ON.text('确定').type('Button'));
    await primaryButton.click();
    await driver.delayMs(1000);

    // 判断添加好友功能列表是否刷新添加的数据
    await driver.assertComponentExist(ON.text('艾森宝'));
    await driver.delayMs(1000);

    done();
  })

  /**
   * 修改通讯录好友信息
   */
  it(CASE + '_Edit', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击通讯录好友【艾伦】进入详情页
    await driver.assertComponentExist(ON.text('艾伦'));
    const friendItem = await driver.findComponent(ON.text('艾伦'));
    await friendItem.click();
    await driver.delayMs(1000);

    // 点击右上角按钮
    await driver.assertComponentExist(ON.id('taskpool_button_more'));
    const moreButton = await driver.findComponent(ON.id('taskpool_button_more'));
    await moreButton.click();
    await driver.delayMs(1000);

    // 点击编辑项
    await driver.assertComponentExist(ON.text('编辑'));
    const editText = await driver.findComponent(ON.text('编辑'));
    await editText.click();
    await driver.delayMs(1000);

    // 点击“姓名”框
    logger.info(TAG, `TextInput_Name`);
    await driver.assertComponentExist(ON.id('taskpool_textinput_name'));
    const name = await driver.findComponent(ON.id('taskpool_textinput_name'));
    await name.click();
    await driver.delayMs(1000);

    // 修改姓名：艾伦->艾斯基
    await driver.assertComponentExist(ON.id('taskpool_textinput_name'));
    const textInputName = await driver.findComponent(ON.id('taskpool_textinput_name'));
    await textInputName.inputText('艾斯基');
    await driver.delayMs(2000);

    // 点击“电话”框
    logger.info(TAG, `TextInput_Phone`);
    await driver.assertComponentExist(ON.id('taskpool_textinput_phone'));
    const phone = await driver.findComponent(ON.id('taskpool_textinput_phone'));
    await phone.click();
    await driver.delayMs(1000);

    // 修改电话：199999999->199998888
    await driver.assertComponentExist(ON.id('taskpool_textinput_phone'));
    const textInputPhone = await driver.findComponent(ON.id('taskpool_textinput_phone'));
    await textInputPhone.inputText('199998888');
    await driver.delayMs(2000);

    // 点击“√”保存按钮
    await driver.assertComponentExist(ON.id('taskpool_button_ok'));
    const okButton = await driver.findComponent(ON.id('taskpool_button_ok'));
    await okButton.click();
    await driver.delayMs(1000);

    // 点击弹框中的确认选项
    await driver.assertComponentExist(ON.text('确定').type('Button'));
    const primaryButton = await driver.findComponent(ON.text('确定').type('Button'));
    await primaryButton.click();
    await driver.delayMs(1000);

    // 判断好友信息修改名字是否修改成功
    await driver.assertComponentExist(ON.text('艾斯基'));
    await driver.delayMs(1000);

    // 判断好友信息修改电话号码是否修改成功
    await driver.assertComponentExist(ON.text('199998888'));
    await driver.delayMs(1000);

    // 退出页面
    await driver.pressBack();
    await driver.delayMs(1000);

    done()
  })

  /**
   * 删除通讯录好友
   */
  it(CASE + '_Delete', 0, async (done: Function) => {
    let driver = Driver.create();

    // 点击通讯录好友【艾伦】进入详情页
    await driver.assertComponentExist(ON.text('艾伦'));
    const friendItem = await driver.findComponent(ON.text('艾伦'));
    await friendItem.click();
    await driver.delayMs(1000);

    // 点击右上角按钮
    await driver.assertComponentExist(ON.id('taskpool_button_more'));
    const moreButton = await driver.findComponent(ON.id('taskpool_button_more'));
    await moreButton.click();
    await driver.delayMs(1000);

    // 点击删除项
    await driver.assertComponentExist(ON.text('删除'));
    const deleteText = await driver.findComponent(ON.text('删除'));
    await deleteText.click();
    await driver.delayMs(1000);

    // 点击弹框中的确认选项
    await driver.assertComponentExist(ON.text('删除').type('Button'));
    const deleteButton = await driver.findComponent(ON.text('删除').type('Button'));
    await deleteButton.click();
    await driver.delayMs(1000);

    // 判断好友删除成功
    const deleteItem = await driver.findComponent(ON.text('艾伦'));
    expect(deleteItem).assertEqual(null);

    done();
  })
  // 退出案例
  exit(CASE_NAME);
}