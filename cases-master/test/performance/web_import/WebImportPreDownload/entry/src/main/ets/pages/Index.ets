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
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column({space: 10}) {
      Web({ src: 'https://www.baidu.com', controller: this.controller })
        .onPageEnd((event) => {
          // TODO: 在确定即将跳转的页面时开启预加载
          this.controller.prefetchPage('https://www.taobao.com');
        })
        .width('100%')
        .height('100%')
      Button('下一页')
        .onClick(() => {
          // 跳转下一页
          this.controller.loadUrl('https://www.taobao.com');
        })
        .width(300)
        .height(30)
    }
    .width('100%')
  }
}