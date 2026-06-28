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
import { BreakpointType } from 'commonmulticommunityapplication';
import { AuthorInfo, CommunityDetailsWork } from './CommonView';
import { PostModel } from '../model/PostModel';

/**
 * Community Detail Page - Content
 */
@ComponentV2
export struct CommunityDetailContent {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Consumer() pathStack: NavPathStack = new NavPathStack();
  @Param @Require postInfo: PostModel;

  build() {
    Scroll() {
      Column() {
        AuthorInfo({ postInfo: this.postInfo })
        CommunityDetailsWork({
          postInfo: this.postInfo,
          breakpointCount: new BreakpointType<number>(3, 3, 5, 5).getValue(this.breakpoint.widthBreakpoint),
          widthBreakpoint: this.breakpoint.widthBreakpoint
        })
      }
      .height(this.breakpoint.widthBreakpoint === WidthBreakpoint.WIDTH_SM ? 'auto' : '100%')
      .justifyContent(FlexAlign.Start)
      .backgroundColor($r('sys.color.background_primary'))
    }
    .enableScrollInteraction(false)
    .backgroundColor($r('app.color.background_primary'))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }
}