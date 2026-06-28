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

import { WindowInfo } from '../../utils/WindowUtil';
import { HomeConstants } from '../../constants/ConversationConstants';
import { ConversationList } from './ConversationList'

@Component
export struct ConversationNavBarView {
  @ObjectLink mainWindowInfo: WindowInfo;
  pageInfos: NavPathStack = new NavPathStack();
  pathStack: NavPathStack = new NavPathStack();
  @State currentContactUserName: string = '';
  @State currentContactUserIcon: Resource = HomeConstants.DEFAULT_AVATAR;
  @Provide({ allowOverride:'currentConversationUserName'}) currentConversationUserName: Resource = $r('app.string.default_username');

  build() {
    Column() {
      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center }) {
        ConversationList({
          mainWindowInfo: this.mainWindowInfo,
          currentContactUserName: $currentConversationUserName,
          pageInfos: this.pageInfos,
          pathStack: this.pathStack,
        })
          .flexGrow(1)
          .width('100%')
      }
      .height('100%')
    }
  }
}
