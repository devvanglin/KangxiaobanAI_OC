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
import { Constants } from '../common/Constants';


@Entry
@Component
struct IndexPage {
  build() {
    Column() {
      Button({ type: ButtonType.Capsule }) {
        Text($r('app.string.single_stage_mode'))
          .fontColor(Color.White)
      }
      .width(300)
      .height(48)
      .onClick(() => {
        AppStorage.setOrCreate('photoMode', Constants.SINGLE_STAGE_MODE);
        router.pushUrl({ url: 'pages/PhotoPage' });
      })

      Button({ type: ButtonType.Capsule }) {
        Text($r('app.string.subsection_mode'))
          .fontColor(Color.White)
      }
      .margin({ top: 16 })
      .width(300)
      .height(48)
      .onClick(() => {
        AppStorage.setOrCreate('photoMode', Constants.SUBSECTION_MODE);
        router.pushUrl({ url: 'pages/PhotoPage' });
      })
    }.width(Constants.FULL_PERCENT)
    .height(Constants.FULL_PERCENT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}