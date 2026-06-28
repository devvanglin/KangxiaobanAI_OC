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
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  title: string = 'TaskPool Sample';
  @State message: string = '';

  build() {
    Row() {
      Column({ space: 12 }) {
        Blank()
        Button('Sample1')
          .height(40)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: "pages/sample1/Sample1" });
          })

        Button('Sample2')
          .height(40)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: "pages/sample2/Sample2" });
          })

        Button('Sample3')
          .height(40)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: "pages/sample3/Sample3" });
          })

        Button('Sample4')
          .height(40)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: "pages/sample4/Sample4" });
          })

        Button('Sample5')
          .height(40)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: "pages/sample5/Sample5" });
          })

        Button('Sample6')
          .height(40)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: "pages/sample6/Sample6" });
          })
      }
      .height('100%')
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}