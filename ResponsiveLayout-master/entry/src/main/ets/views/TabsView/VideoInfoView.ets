/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { WidthBreakpointType } from '../../utils/WidthBreakpointType';
import { VideoViewModel } from './model/TabData';
import { WindowInfo } from '../../utils/WindowUtil';

@Component
export struct VideoInfoView {
  @ObjectLink mainWindowInfo: WindowInfo;
  @Link firstLevelIndex: number;
  @Link secondLevelIndex: number;
  private videoViewModel = new VideoViewModel();
  private iteration: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

  build() {
    Grid() {
      ForEach(this.iteration, () => {
        GridItem() {
          Column() {
            Image(this.videoViewModel.getVideo(this.secondLevelIndex))
              .objectFit(ImageFit.Fill)
              .width('100%')
              .borderRadius(12)

            Row()
              .height(16)
              .width('50%')
              .borderRadius(12)
              .backgroundColor('#1A000000')
              .margin({
                top: new WidthBreakpointType(10, 10, 12, 11).getValue(this.mainWindowInfo.widthBp),
                bottom: 6
              })

            Row()
              .height(14)
              .width('100%')
              .borderRadius(12)
              .backgroundColor('#0D000000')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.SpaceBetween)
        }
      }, (item: number, index: number) => index + JSON.stringify(item))
    }
    .visibility(this.firstLevelIndex === 0 ? Visibility.Visible : Visibility.None)
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .columnsTemplate(new WidthBreakpointType('1fr 1fr', '1fr 1fr 1fr', '1fr 1fr 1fr 1fr', '1fr 1fr 1fr')
      .getValue(this.mainWindowInfo.widthBp))
    .width('100%')
    .rowsGap(new WidthBreakpointType(12, 16, 16, 16).getValue(this.mainWindowInfo.widthBp))
    .columnsGap(new WidthBreakpointType(16, 12, 16, 16).getValue(this.mainWindowInfo.widthBp))
    .padding({
      left: new WidthBreakpointType(16, 24, 36, 24).getValue(this.mainWindowInfo.widthBp),
      right: new WidthBreakpointType(16, 24, 36, 24).getValue(this.mainWindowInfo.widthBp),
      top: 12,
      bottom: new WidthBreakpointType(6, 6, 20, 20).getValue(this.mainWindowInfo.widthBp)
    })
  }
}