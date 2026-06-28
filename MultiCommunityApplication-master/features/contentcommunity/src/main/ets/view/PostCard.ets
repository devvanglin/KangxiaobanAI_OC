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
import { InteractionBar } from './CommonView';

/**
 * Hotspot - Real-time - Single Card Cascading Flow
 */
@ComponentV2
export struct PostCard {
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local isExpanded: boolean = false; // Whether the content is expanded
  @Param @Require post: PostModel;
  @Event onCardClick: () => void = () => {
  };
  @Event onImageClick: () => void = () => {
  };

  build() {
    Column() {
      // Publisher info bar
      Row() {
        Row() {
          Image(this.post.authorAvatar)
            .width(40)
            .height(40)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)
            .draggable(false)

          Column() {
            Text(this.post.authorName)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.font_title'))

            Text(this.post.publishTime)
              .fontSize(12)
              .fontColor($r('app.color.font_tertiary'))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10 })
        }

        Blank()
        Image($r('sys.media.ohos_ic_public_more'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.icon_primary'))
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16 })

      // Image content
      if (this.post.images.length > 0) {
        Stack() {
          Image(this.post.images[0])
            .width('100%')
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .onClick(() => {
              this.onImageClick();
            })

          // Image tags
          if (this.post.tags.length > 0) {
            Row() {
              Text(this.post.tags[0])
                .fontSize(12)
                .fontColor($r('app.color.label_font_color'))

              if (this.post.tags.length > 1) {
                Divider()
                  .vertical(true)
                  .width(1)
                  .height(6)
                  .margin({ left: 4, right: 4 })
                  .color($r('app.color.label_font_color'))

                Text(this.post.tags[1])
                  .fontSize(12)
                  .fontColor($r('app.color.label_font_color'))
              }
            }
            .backgroundColor($r('app.color.mask_dark'))
            .borderRadius(14)
            .margin({ left: 12, bottom: 12 })
            .padding({
              left: 10,
              right: 10,
              top: 4,
              bottom: 4
            })
          }
        }
        .alignContent(Alignment.BottomStart)
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      // Text description
      Row() {
        Text(this.post.content)
          .fontSize(14)
          .fontColor($r('app.color.font_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (!this.isExpanded) {
          Text($r('app.string.view_all'))
            .fontWeight(FontWeight.Medium)
            .fontSize(14)
            .fontColor($r('app.color.font_emphasize'))
            .margin({ left: 4 })
            .onClick(() => {
              this.isExpanded = true;
            })
        }
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 8
      })

      // The interactive bar at the bottom of the card
      InteractionBar(this.post.shareCount, this.post.commentCount, this.post.likeCount)
    }
    .backgroundColor($r('app.color.background_primary'))
    .borderRadius(15)
    .onClick(() => {
      this.onCardClick();
    })
  }
}