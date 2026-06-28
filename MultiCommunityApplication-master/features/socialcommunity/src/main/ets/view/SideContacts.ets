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
import { common } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { CommonConstants } from 'commonmulticommunityapplication';
import { FollowerListModel, FollowerModel } from '../model/FollowerListModel';

/**
 * All Followed List on the Left Side.
 */
@ComponentV2
export struct SideContacts {
  private moduleName: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Local followerListModel: FollowerListModel = new FollowerListModel();
  @Local followerList: FollowerModel[] = [];

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
    this.followerList = this.followerListModel.loadFollowerList();
  }

  build() {
    Column() {
      // Follower list
      List() {
        ListItem() {
          // All Following title
          Row() {
            Row()
              .width(40)
              .height(40)
              .borderRadius(40)
              .backgroundColor($r('app.color.contacts_icon'))
            Row() {
              Text($r('app.string.all_attention'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.font_title'))
            }
            .margin({ left: 12 })
          }
          .width('100%')
          .height(72)
          .padding({
            left: 24
          })
        }

        ForEach(this.followerList, (follower: FollowerModel) => {
          ListItem() {
            Row({ space: 12 }) {
              Stack() {
                Image(follower.avatar)
                  .width(40)
                  .height(40)
                  .draggable(false)
                  .borderRadius(20)
                  .objectFit(ImageFit.Cover)

                // Online status indicator
                if (follower.isOnline) {
                  Circle()
                    .width(10)
                    .height(10)
                    .fill($r('app.color.font_emphasize'))
                    .stroke($r('app.color.border_secondary'))
                    .strokeWidth(2)
                    .position({ x: 30, y: 30 })
                }
              }
              .width(40)
              .height(40)

              Column() {
                Text(follower.name)
                  .fontSize(14)
                  .fontColor($r('app.color.font_title'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(follower.bio)
                  .fontSize(12)
                  .fontColor($r('app.color.font_tertiary'))
                  .margin({ top: 2 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.None })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .height(56)
            .backgroundColor($r('app.color.background_primary'))
            .padding({ left: 24 })
          }
        }, (follower: FollowerModel, index: number) => JSON.stringify(follower.id) + index)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
    .padding({ bottom: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 56 : 32 })
  }
}
