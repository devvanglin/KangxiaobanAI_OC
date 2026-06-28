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

import webview from '@ohos.web.webview';
import { Constants } from '../common/Constants';
import { navDestinationTitle } from '../view/CommonView';

@Builder
export function PageThreePositiveBuilder() {
  PageThreePositive()
}

@Component
export struct PageThreePositive {
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // Web组件引擎初始化
    webview.WebviewController.initializeWebEngine();
    // 启动预连接，连接地址为即将打开的网址
    webview.WebviewController.prepareForPageLoad(Constants.SAMPLE_HTML, true, 2);
  }

  build() {
    NavDestination() {
      navDestinationTitle('3.2正例', () => {
        this.pathStack.pop();
      })
      Column() {
        Button('加载网页')
          .onClick(() => {
            this.pathStack.pushDestination({ name: 'PageThreeWebComponent' })
          })
      }
      .justifyContent(FlexAlign.Center)
      .height('90%')
      .width('100%')
    }
    .backgroundColor(Color.White)
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
