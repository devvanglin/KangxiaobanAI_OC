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
import { ConversationNavBarView } from './ConversationNavBarView';
import { ConversationDetail } from './ConversationDetail';
import ConversationDetailNone from  './ConversationDetailNone'
import { ProductPage } from './ProductPage'

@Component
export struct ConversationNavView {
  @ObjectLink mainWindowInfo: WindowInfo;
  @State isShowingSidebar: boolean = false;
  @State isNavFullScreen: boolean = false;
  pageInfos: NavPathStack = new NavPathStack();
  pathStack: NavPathStack = new NavPathStack();

  // [Start ConversationView]
  @Builder
  PageMap(name: string) {
    if (name === 'conversationDetail') {
      ConversationDetail({
        // [StartExclude ConversationView]
        currentFeatureIndex: 1,
        mainWindowInfo: this.mainWindowInfo,
        isNavFullScreen: this.isNavFullScreen,
        pathStack: this.pathStack,
        // [EndExclude ConversationView]
      })
    } else if (name === 'conversationDetailNone') {
      ConversationDetailNone();
    } else if (name === 'productPage') {
      ProductPage({
        // [StartExclude ConversationView]
        mainWindowInfo: this.mainWindowInfo,
        isNavFullScreen: this.isNavFullScreen,
        pathStack: this.pathStack,
        // [EndExclude ConversationView]
      })
    }
  }

  build() {
    Navigation(this.pathStack) {
      ConversationNavBarView({
        mainWindowInfo: this.mainWindowInfo,
        pageInfos: this.pageInfos,
        pathStack: this.pathStack,
      })
    }
    .mode(this.getNavMode())
    // [StartExclude ConversationView]
    .width('100%')
    .height('100%')
    .hideToolBar(true)
    .navBarWidth('50%')
    // [EndExclude ConversationView]
    .navDestination(this.PageMap)
  }

  getNavMode(): NavigationMode {
    if (!this.isNavFullScreen && this.mainWindowInfo.widthBp !== WidthBreakpoint.WIDTH_SM) {
      return NavigationMode.Split;
    }
    return NavigationMode.Stack
  }
  // [End ConversationView]

}