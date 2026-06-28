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
import { PostViewModel } from '../viewmodel/PostViewModel';
import { PostModel } from '../model/PostModel';
import { PostCard } from './PostCard';

/**
 * Two-column layout: Left follower list + Right post waterfall
 */
@ComponentV2
export struct FollowerPostsView {
  private moduleName: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Consumer() sideBar: boolean = true;
  @Local postViewModel: PostViewModel = new PostViewModel();
  @Local postList: PostModel[] = [];
  @Event onCardClick: () => void = () => {
  };
  @Event onImageClick: () => void = () => {
  };

  aboutToAppear(): void {
    this.moduleName = this.context.abilityInfo.moduleName;
    this.postList = this.postViewModel.postList;
  }

  // Get column count based on breakpoint
  getColumnCount(): number {
    return new BreakpointType(1, 1, 2, 2).getValue(this.breakpoint.widthBreakpoint);
  }

  // Get the card spacing
  getSpace(): number {
    return new BreakpointType(12, 12, 16, 16).getValue(this.breakpoint.widthBreakpoint);
  }

  @Builder
  WaterfallCards() {
    Column() {
      // Post waterfall flow
      Scroll() {
        WaterFlow() {
          // Post list
          ForEach(this.postList, (post: PostModel, index: number) => {
            FlowItem() {
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
            .margin({
              bottom: this.postList.length - 1 === index ||
                this.postList.length - 2 === index && this.getColumnCount() === 2 ? 82 : 0
            })
          }, (post: PostModel) => post.id.toString())
        }
        .columnsTemplate(this.getColumnCount() === 1 ? '1fr' : '1fr 1fr')
        .columnsGap(this.getSpace())
        .rowsGap(this.getSpace())
        .padding({
          left: this.getSpace(),
          right: this.getSpace(),
          top: this.getSpace()
        })
      }
      .padding({ bottom: this.moduleName === CommonConstants.DEVICE_TYPE_PC ? 0 : 30 })
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
    }
    .backgroundColor($r('app.color.background_secondary'))
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    this.WaterfallCards()
  }
}

@Builder
export function FollowerPostsBuilder() {
  FollowerPostsView();
}