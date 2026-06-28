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
import { CommentViewModel } from '../viewmodel/CommentViewModel';
import { CommentItemModel } from '../model/CommentModel';
import { CommentItem } from './CommonView';

/**
 * Comment Area
 */
@ComponentV2
export struct CommentAreaView {
  @Env(SystemProperties.BREAK_POINT) breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo;
  @Local commentViewModel: CommentViewModel = new CommentViewModel();

  build() {
    Column() {
      Column() {
        // Comment title and more button - same row
        Row() {
          Text($r('app.string.comment'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_title'))
        }
        .width('100%')
        .height(56)
        .padding({ top: 8, bottom: 8 })

        ForEach(this.commentViewModel.getShuffledComments(), (comment: CommentItemModel) => {
          CommentItem(comment)
        }, (comment: CommentItemModel) => comment.id)
      }
      .padding({ bottom: this.breakpoint.widthBreakpoint !== WidthBreakpoint.WIDTH_SM ? 52 : 56 })
    }
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .padding({ right: 16, left: 8 })
    .backgroundColor($r('sys.color.background_primary'))
  }
}