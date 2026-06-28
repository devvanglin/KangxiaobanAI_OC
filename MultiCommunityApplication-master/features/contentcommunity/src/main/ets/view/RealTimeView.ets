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
import { BreakpointType, CommonConstants } from 'commonmulticommunityapplication';
import { CommentAreaView } from 'socialcommunity';
import { PostViewModel } from '../viewmodel/PostViewModel';
import { PostModel } from '../model/PostModel';
import { PostCard } from './PostCard';

/**
 * Hotspot - Real-time Page
 */
@ComponentV2
export struct RealTimeView {
  private moduleName: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  // Use Map to store the height of the left card for each index.
  @Local leftCardHeightMap: Map<number, number> = new Map();
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Consumer() sideBar: boolean = true;
  @Local postViewModel: PostViewModel = new PostViewModel();
  @Local postList: PostModel[] = [];

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
    this.postList = this.postViewModel.postList;
  }

  // Get column count based on breakpoint
  getColumnCount(): number {
    return new BreakpointType<number>(1, 1, 2, 2).getValue(this.breakpoint.widthBreakpoint);
  }

  // Build post waterfall flow
  @Builder
  PostWaterFlow() {
    WaterFlow() {
      ForEach(this.postList, (post: PostModel, index: number) => {
        FlowItem() {
          // Select component based on breakpoint: normal card for small screens, card with comments for large screens
          if (this.breakpoint.widthBreakpoint !== WidthBreakpoint.WIDTH_SM) {
            Row() {
              // Left post card - height adapts to content
              Column() {
                PostCard({
                  post: post,
                  onCardClick: () => {
                    this.pathStack.pushPath({ name: 'CommunityDetailPage', param: post });
                  },
                  onImageClick: () => {
                    this.sideBar = false;
                    this.pathStack.pushPath({ name: 'ImageDetailPage', param: post.images[0] });
                  }
                })
              }
              .width('60%')
              .onAreaChange((oldArea, newArea) => {
                // Get the actual height of the left card
                if (newArea.height > 0) {
                  this.leftCardHeightMap.set(index, newArea.height as number);
                }
              })

              // Right comment area - height consistent with the left side
              Column() {
                // Scrollable comment list
                Scroll() {
                  CommentAreaView()
                }
                .borderRadius(15)
                .layoutWeight(1)
                .scrollBar(BarState.Off)
              }
              .width('40%')
              .height(this.leftCardHeightMap.get(index) ?? '100%')
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .backgroundColor($r('app.color.background_primary'))
            .borderRadius(15)
            .margin({
              bottom: this.postList.length - 1 === index ||
                this.postList.length - 2 === index && this.getColumnCount() === 2 ? 82 : 0
            })
          } else {
            PostCard({
              post: post,
              onCardClick: () => {
                this.pathStack.pushPath({ name: 'CommunityDetailPage', param: post });
              },
              onImageClick: () => {
                this.sideBar = false;
                this.pathStack.pushPath({ name: 'ImageDetailPage', param: post.images[0] });
              }
            })
          }
        }
      }, (post: PostModel, index: number) => JSON.stringify(post.id) + index)
    }
    .edgeEffect(EdgeEffect.None)
    .columnsTemplate(this.getColumnCount() === 1 ? '1fr' : this.getColumnCount() === 2 ? '1fr 1fr' : '1fr 1fr 1fr')
    .columnsGap(new BreakpointType(12, 12, 16, 16).getValue(this.breakpoint.widthBreakpoint))
    .rowsGap(new BreakpointType(12, 12, 16, 16).getValue(this.breakpoint.widthBreakpoint))
    .padding({
      top: new BreakpointType(12, 12, 16, 16).getValue(this.breakpoint.widthBreakpoint),
      right: new BreakpointType(12, 24, 24, 24).getValue(this.breakpoint.widthBreakpoint),
      bottom: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 0 :
        new BreakpointType(118, 34, 34, 34).getValue(this.breakpoint.widthBreakpoint),
      left: new BreakpointType(12, 24, 24, 24).getValue(this.breakpoint.widthBreakpoint)
    })
  }

  build() {
    Scroll() {
      this.PostWaterFlow()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_secondary'))
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .scrollBar(BarState.Off)
  }
}
