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

import { FollowerListModel, FollowerModel } from '../model/FollowerListModel';
import { FollowerAvatar } from './CommonView';

/**
 * Followers horizontal list - Display on small-screen devices
 */
@ComponentV2
export struct HorizontalContacts {
  @Local followerListModel: FollowerListModel = new FollowerListModel();
  @Local followerList: FollowerModel[] = [];

  aboutToAppear(): void {
    this.followerList = this.followerListModel.loadFollowerList();
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.all_attention'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.font_title'))
        Blank()
        Row() {
          Text($r('app.string.more'))
            .fontSize(14)
            .fontColor($r('app.color.font_tertiary'))
            .margin({ right: 4 })
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize($r('sys.float.Body_L'))
            .fontColor([$r('app.color.font_tertiary')])
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .height(44)

      // List of followers (horizontal)
      List({ space: 24 }) {
        ForEach(this.followerList, (follower: FollowerModel, index: number) => {
          ListItem() {
            FollowerAvatar(follower.avatar, follower.name, follower.isOnline)
          }
          .padding({ left: index === 0 ? 16 : 0, right: index === this.followerList.length - 1 ? 16 : 0 })
        }, (follower: FollowerModel, index: number) => JSON.stringify(follower.id) + index)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
    }
    .height(115)
    .backgroundColor($r('app.color.background_primary'))
  }
}