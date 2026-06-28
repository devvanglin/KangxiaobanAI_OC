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
import { CommentItemModel } from '../model/CommentModel';

/**
 * Secondary Comment Section.
 */
@Builder
export function SubReplyItem(subContent: ResourceStr) {
  Column({ space: 4 }) {
    Text(subContent)
      .fontSize(12)
      .fontColor($r('app.color.font_primary'))
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })

    Text($r('app.string.vie_wall_replies'))
      .fontWeight(FontWeight.Medium)
      .fontSize(12)
      .fontColor($r('app.color.font_emphasize'))
      .margin({ top: 4 })
  }
  .alignItems(HorizontalAlign.Start)
  .width('100%')
  .backgroundColor($r('app.color.font_color_secondary'))
  .borderRadius(8)
  .margin({ top: 8 })
  .padding({
    top: 12,
    right: 16,
    bottom: 12,
    left: 16
  })
}

/**
 * The follower avatar component with an online status indicator.
 */
@Builder
export function FollowerAvatar(avatar: Resource, name: ResourceStr, isOnline: boolean) {
  Column() {
    Stack() {
      Image(avatar)
        .width(40)
        .height(40)
        .borderRadius(20)
        .objectFit(ImageFit.Cover)
        .border({ width: 2, color: $r('app.color.border_secondary') })

      // Online status indicator
      if (isOnline) {
        Circle()
          .width(12)
          .height(12)
          .fill($r('app.color.font_emphasize'))
          .stroke($r('app.color.border_secondary'))
          .strokeWidth(2)
          .position({ x: 28, y: 28 })
      }
    }
    .width(40)
    .height(40)

    Text(name)
      .width(40)
      .height(24)
      .maxLines(2)
      .fontSize(10)
      .fontColor($r('app.color.font_contacts_subhead'))
      .textOverflow({ overflow: TextOverflow.None })
      .textAlign(TextAlign.Center)
      .margin({ top: 4 })
  }
  .width(40)
}

/**
 * Content in the comment section.
 */
@Builder
export function CommentItem(comment: CommentItemModel) {
  Column() {
    // Commenter information row - Profile picture, username, number of likes
    Row({ space: 8 }) {
      Image(comment.userAvatar)
        .width(32)
        .height(32)
        .draggable(false)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)

      Text(comment.userName)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.font_title'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // Number of Likes.
      Row({ space: 4 }) {
        Text(comment.likeCount.toString())
          .fontSize(12)
          .fontColor($r('app.color.font_tertiary'))

        SymbolGlyph($r('sys.symbol.heart'))
          .fontSize(12)
          .fontColor([comment.isLiked ? $r('app.color.color_danger') : $r('app.color.font_tertiary')])
      }
    }
    .width('100%')

    Text(comment.content)
      .fontSize(16)
      .fontColor($r('app.color.font_title'))
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .margin({ top: 8 })

    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
      Text() {
        Span(`${comment.time} `)
        Span($r('app.string.be_from'))
        Span(comment.location)
      }
      .fontSize(12)
      .height(24)
      .fontColor($r('app.color.font_tertiary'))

      if (comment.replyCount > 0) {
        Row() {
          Text() {
            Span(`${comment.replyCount} `)
            Span($r('app.string.reply'))
          }
          .fontSize(12)
          .height(24)
          .alignSelf(ItemAlign.Center)
          .fontColor($r('app.color.font_secondary'))
        }
        .alignItems(VerticalAlign.Center)
        .padding({
          left: 6,
          right: 6,
        })
        .backgroundColor($r('app.color.font_color_secondary'))
        .borderRadius(13)
      } else {
        Text($r('app.string.reply'))
          .fontSize(12)
          .height(24)
          .fontColor($r('app.color.font_primary'))
          .alignSelf(ItemAlign.Center)
          .fontWeight(FontWeight.Medium)
      }
    }
    .width('100%')
    .padding({ left: 2 })

    // Secondary reply (displayed only for the first comment)
    if (comment.replyCount !== 0) {
      SubReplyItem(comment.subContent)
    }
  }
  .width('100%')
  .justifyContent(FlexAlign.Start)
  .padding({ bottom: 20 })
}

/**
 * Content in the comment section.
 */
@Builder
export function BottomTabs() {
  Row() {
    TextInput({ placeholder: $r('app.string.write_comment') })
      .focusable(false)
      .placeholderColor($r('app.color.font_tertiary'))
      .fontColor($r('app.color.font_primary'))
      .placeholderFont({ size: 14, weight: 400 })
      .caretColor($r('app.color.font_emphasize'))
      .width(122)
      .height(40)
      .margin(20)
      .fontSize(14)
      .margin({ left: 0 })
      .borderRadius(50)
    Image($r('app.media.ellipsis_message'))
      .width(24)
      .height(24)
      .fillColor($r('app.color.icon_primary'))
    Image($r('app.media.star'))
      .width(24)
      .height(24)
      .fillColor($r('app.color.icon_primary'))
    Image($r('app.media.heart'))
      .width(24)
      .height(24)
      .fillColor($r('app.color.icon_primary'))
    Image($r('app.media.share'))
      .width(24)
      .height(24)
      .fillColor($r('app.color.icon_primary'))
  }
  .width('100%')
  .justifyContent(FlexAlign.SpaceBetween)
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
}
