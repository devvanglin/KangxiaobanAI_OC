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
import dataPreferences from '@ohos.data.preferences';
import { BusinessError } from '@ohos.base';
import { common } from '@kit.AbilityKit';
import { promptAction, ShowDialogSuccessResponse } from '@kit.ArkUI';

const MYSTORE = 'myStore'; // Preferences实例名称
const STARTUP = 'startup'; // 写入与读取数据的key值
const CHANGE = 'change'; // 事件类型，固定为change

/**
 * 功能说明: 本示例介绍使用NavDestination组件的onBackPressed回调对返回事件进行拦截，提示用户保存编辑内容，并使用preferences实例持久化保存内容
 *
 * 推荐场景: 返回上一页面时需要保存当前编辑内容的场景，如：记事本返回保存内容等
 *
 * 核心组件:
 * 1. SideslipIntercept.textArea
 *
 * 实现步骤：
 * 1. 生命周期函数onBackPress只能在@Entry组件中使用，因此使用navigation来管理页面
 * 2. 使用NavDestination组件的onBackPressed回调对返回事件进行拦截
 * 2. 触发返回弹出弹窗，选择保存时，将数据写入到preferences实例中
 * 3. 在页面加载时读取存储在preferences实例中的数据
 */
@Component
export struct SideslipIntercept {
  controller: TextAreaController = new TextAreaController();
  @State text: string = '';
  @Provide pageStackForComponentSharedPages: NavPathStack = new NavPathStack();
  @State context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  @State isBack: boolean = true; // 是否允许返回
  callBack: () => void = () => {
  };

  aboutToAppear() {
    let preferences: dataPreferences.Preferences | null = null;
    dataPreferences.getPreferences(this.context, MYSTORE, (err: BusinessError, val: dataPreferences.Preferences) => {
      preferences = val;
      // TODO：知识点：进入页面通过preferences.getSync()方法读取存储在preferences实例中的数据
      const value: dataPreferences.ValueType = preferences.getSync(STARTUP, this.text);
      this.text = value.toString();
    })
  }

  @Builder
  textArea(name: string) {
    // TODO：知识点：功能是以har的形式集成在主工程中，没有@Entry修饰的组件，无法使用@Entry组件的onBackPress生命周期函数；而在NavDestination中实现，原因是有onBackPressed回调。
    NavDestination() {
      Column() {
        TextArea({
          text: this.text,
          placeholder: 'input your word...',
          controller: this.controller
        })
          .id('sideSlipInterceptTextArea')
          .width($r('app.integer.sideslipintercept_text_area_width'))
          .height($r('app.integer.sideslipintercept_text_area_height'))
          .margin($r('app.integer.sideslipintercept_text_area_margin'))
          .fontSize($r('app.integer.sideslipintercept_text_area_font_size'))
          .onChange((value: string) => {
            if (this.text === value) {
              this.isBack = true;
            } else {
              this.isBack = false;
            }
            this.text = value;
          })
      }
      .justifyContent(FlexAlign.Start)
      .width('100%')
      .height('100%')
    }
    // TODO：知识点：返回时通过弹窗拦截，点击弹窗不保存按钮直接返回主界面，点击保存按钮将数据写入到preferences实例中，持久化存储数据
    .onBackPressed(() => {
      if (this.isBack) {
        // 返回到主页面
        this.callBack();
        return true;
      }
      promptAction.showDialog({
        message: $r('app.string.sideslipintercept_edit_prompt'),
        alignment: DialogAlignment.Center,
        buttons: [
          {
            text: $r('app.string.sideslipintercept_unsave_edit'),
            color: $r('app.color.sideslipintercept_button_text_color')
          },
          {
            text: $r('app.string.sideslipintercept_save_edit'),
            color: $r('app.color.sideslipintercept_button_text_color')
          }
        ]
      }).then((data: ShowDialogSuccessResponse) => {
        // 操作菜单的响应结果,选中按钮在buttons数组中的索引，从0开始,第二个索引为1
        // 点击不保存按钮
        if (data.index === 0) {
          // 返回到主页面
          this.callBack();
        }
        // 点击保存按钮，保存编辑返回主界面
        if (data.index === 1) {
          let preferences: dataPreferences.Preferences | null = null;
          dataPreferences.getPreferences(this.context, MYSTORE,
            (err: BusinessError, val: dataPreferences.Preferences) => {
              preferences = val;
              // 订阅数据变更需要指定observer作为回调方法
              const observer = (key: string): void => {
                return;
              }
              preferences.on(CHANGE, observer);
              // TODO：知识点：触发返回后点击保存通过preferences.put()方法将数据写入到preferences实例中，持久化存储数据
              preferences.put(STARTUP, this.text, (err: BusinessError) => {
                // 数据持久化
                if (preferences !== null) {
                  preferences.flush((err: BusinessError) => {
                    if (err) {
                      return;
                    }
                    promptAction.showToast({
                      message: $r('app.string.sideslipintercept_edit_toast')
                    })
                  })
                }
              })
            })
          // 返回到主页面
          this.callBack();
        }
      }).catch((err: object) => {
        return err
      })
      // 上述回到主页面需要return true放行
      return true
    })
  }

  // 上层navigation用来管理页面,navigation是空的，在onAppear回调时直接跳转到主页面
  build() {
    // 应用主页用NavDestination承载，用于显示Navigation的内容区
    Navigation(this.pageStackForComponentSharedPages) {
    }
    .onAppear(() => {
      this.pageStackForComponentSharedPages.pushPathByName("MainPage", null, false);
    })
    // 创建NavDestination组件，需使用此组件的onBackPressed回调拦截返回事件
    .navDestination(this.textArea)
  }
}
