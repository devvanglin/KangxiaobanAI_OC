/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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
import { uiObserver } from '@kit.ArkUI';
import { PostModel } from '../model/PostModel';

/**
 * The component for the comment area at the bottom of the waterfall card.
 */
@Builder
export function IconCount(image: Resource, count: number) {
  Row() {
    Image(image)
      .width(20)
      .height(20)
      .fillColor($r('app.color.icon_primary'))
    Text(count.toString())
      .fontSize(14)
      .fontColor($r('app.color.icon_primary'))
      .margin({ left: 4 })
  }
}

/**
 * The bottom interaction bar component of the card.
 */
@Builder
export function InteractionBar(shareCount: number, commentCount: number, likeCount: number) {

  Row() {
    IconCount($r('app.media.share'), shareCount)
    IconCount($r('app.media.ellipsis_message'), commentCount)
    IconCount($r('app.media.heart'), likeCount)
  }
  .width('100%')
  .height(44)
  .justifyContent(FlexAlign.SpaceBetween)
  .padding({ left: 16, right: 16 })
}

/**
 * Community Detail Page - Content - Author Info Area
 */
@ComponentV2
export struct AuthorInfo {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Param @Require postInfo: PostModel;

  build() {
    Row() {
      Image(this.postInfo.authorAvatar)
        .width(38)
        .height(38)
        .borderRadius(24)
        .objectFit(ImageFit.Cover)

      Column() {
        Text(this.postInfo.authorName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_title'))

        Text(this.postInfo.authorTagInfo) // Author tag information
          .fontSize(12)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('app.color.font_tertiary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      Blank()
      Button($r('app.string.attentions'))
        .fontSize(14)
        .fontColor($r('app.color.font_emphasize'))
        .backgroundColor($r('app.color.focus_background_color'))
        .height(32)
    }
    .padding({
      top: 16,
      right: 16,
      bottom: 8,
      left: 16
    })
    .width('100%')
  }
}

/**
 * Community Detail Page - Content - Work Info + Images
 */
@ComponentV2
export struct CommunityDetailsWork {
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Consumer() sideBar: boolean = false;
  @Param @Require postInfo: PostModel;
  @Param @Require breakpointCount: number;
  @Param @Require widthBreakpoint: WidthBreakpoint;
  private scroller: Scroller = new Scroller();
  // When using a 5-column layout, the first image spans 2 columns; in a 3-column layout,
  // it does not span across columns.
  private layoutOptions: GridLayoutOptions = {
    regularSize: [1, 1], // The ordinary GridItem occupies one row and one column.
    irregularIndexes: [0], // The GridItem with index 0 is irregular.
    onGetIrregularSizeByIndex: (index: number) => {
      // When using a 5-column layout, the first image spans across 2 columns.
      if (index === 0 && this.breakpointCount === 5) {
        return [1, 2]; // Occupies 1 row and spans 2 columns
      }
      return [1, 1];
    }
  };

  build() {
    Scroll() {
      Column() {
        Text(this.postInfo.content)
          .fontSize(16)
          .fontColor($r('app.color.font_title'))
          .lineHeight(24)
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 8,
            bottom: 16
          })

        Grid(this.scroller, this.layoutOptions) {
          ForEach(this.postInfo.images, (image: Resource, index: number) => {
            GridItem() {
              Image(image)
                .width('100%')
                .aspectRatio(this.breakpointCount === 5 && index === 0 ? 2 : 1)
                .objectFit(ImageFit.Cover)
                .borderRadius(4)
            }
            .onClick(() => {
              this.sideBar = false;
              this.pathStack.pushPath({ name: 'ImageDetailPage', param: image });
            })
          }, (image: Resource, index: number) => JSON.stringify(image) + index)
        }
        .scrollBar(BarState.Off)
        .cachedCount(9)
        .columnsTemplate(this.breakpointCount === 3 ? '1fr 1fr 1fr' : '1fr 1fr 1fr 1fr 1fr')
        .columnsGap(4)
        .rowsGap(4)
        .padding({
          left: 16, right: 16, bottom: this.widthBreakpoint === WidthBreakpoint.WIDTH_SM ? 0 : 0
        })
      }
      .backgroundColor($r('sys.color.background_primary'))
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }
}