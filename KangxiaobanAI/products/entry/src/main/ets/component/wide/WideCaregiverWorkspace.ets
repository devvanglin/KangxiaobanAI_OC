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

import { WideHomePage } from './WideHomePage';
import { WideMessagePage } from './WideMessagePage';
import { WideResidentPage } from './WideResidentPage';

export type CaregiverMaterialScrollerOwner =
  'residentMaster' | 'residentDetail' | 'messageList' | 'messageChat';

@ComponentV2
export struct WideCaregiverWorkspace {
  @Param @Require currentTabIndex: number;
  @Param @Require primaryTabIndex: number;
  @Param topBarHeight: number = 0;
  @Param @Require homeScroller: Scroller;
  @Param @Require homeTaskDetailScroller: Scroller;
  @Param @Require residentMasterScroller: Scroller;
  @Param @Require residentDetailScroller: Scroller;
  @Param @Require messageListScroller: Scroller;
  @Param @Require messageChatScroller: Scroller;
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Param backRequestToken: number = 0;
  @Event onSwitchTab: (index: number) => void = (_index: number) => {};
  @Event onLocalBackStateChange: (hasLocalLayer: boolean) => void = (_hasLocalLayer: boolean) => {};
  @Event onMaterialScrollerOwnerChange: (owner: CaregiverMaterialScrollerOwner) => void =
    (_owner: CaregiverMaterialScrollerOwner) => {};
  @Event onUnreadCountChange: (count: number) => void = (_count: number) => {};
  @Event onOpenAiChat: () => void = () => {};
  @Local homeTaskPanelVisible: boolean = false;
  @Local residentDetailVisible: boolean = false;
  @Local messageDetailVisible: boolean = false;
  @Local homeBackRequestToken: number = 0;
  @Local residentBackRequestToken: number = 0;
  @Local messageBackRequestToken: number = 0;
  @Local residentMaterialScrollerOwner: CaregiverMaterialScrollerOwner = 'residentDetail';
  @Local messageMaterialScrollerOwner: CaregiverMaterialScrollerOwner = 'messageChat';
  @Local requestedResidentId: string = '';
  @Local residentSelectionRequestToken: number = 0;

  private activeTabIndex(): number {
    if (this.currentTabIndex >= 0 && this.currentTabIndex <= 2) {
      return this.currentTabIndex;
    }
    return this.primaryTabIndex >= 0 && this.primaryTabIndex <= 1 ? this.primaryTabIndex : 0;
  }

  private isActiveTab(index: number): boolean {
    return this.activeTabIndex() === index;
  }

  private pageVisibility(index: number): Visibility {
    return this.isActiveTab(index) ? Visibility.Visible : Visibility.Hidden;
  }

  @Monitor('currentTabIndex', 'primaryTabIndex', 'compactWidth')
  onWorkspaceContextChange(): void {
    this.reportActiveLocalBackState();
    this.reportMaterialScrollerOwnerForTab(this.activeTabIndex());
  }

  aboutToAppear(): void {
    this.reportActiveLocalBackState();
    this.reportMaterialScrollerOwnerForTab(this.activeTabIndex());
  }

  aboutToDisappear(): void {
    this.onLocalBackStateChange(false);
  }

  @Monitor('backRequestToken')
  onBackRequestTokenChange(): void {
    const activeIndex: number = this.activeTabIndex();
    if (activeIndex === 0) {
      this.homeBackRequestToken += 1;
    } else if (activeIndex === 1) {
      this.residentBackRequestToken += 1;
    } else if (activeIndex === 2) {
      this.messageBackRequestToken += 1;
    }
  }

  private hasLocalLayerForTab(index: number): boolean {
    if (index === 0) {
      return this.homeTaskPanelVisible;
    }
    if (index === 1) {
      return this.compactWidth && this.residentDetailVisible;
    }
    if (index === 2) {
      return this.compactWidth && this.messageDetailVisible;
    }
    return false;
  }

  private reportActiveLocalBackState(): void {
    this.onLocalBackStateChange(this.hasLocalLayerForTab(this.activeTabIndex()));
  }

  private updateLocalLayer(tabIndex: number, visible: boolean): void {
    if (tabIndex === 0) {
      this.homeTaskPanelVisible = visible;
    } else if (tabIndex === 1) {
      this.residentDetailVisible = visible;
    } else if (tabIndex === 2) {
      this.messageDetailVisible = visible;
    }
    if (this.activeTabIndex() === tabIndex) {
      this.reportActiveLocalBackState();
    }
  }

  private reportMaterialScrollerOwnerForTab(tabIndex: number): void {
    if (tabIndex === 1) {
      this.onMaterialScrollerOwnerChange(this.residentMaterialScrollerOwner);
    } else if (tabIndex === 2) {
      this.onMaterialScrollerOwnerChange(this.messageMaterialScrollerOwner);
    }
  }

  private updateMaterialScrollerOwner(owner: CaregiverMaterialScrollerOwner): void {
    const ownerTabIndex: number = owner === 'residentMaster' || owner === 'residentDetail' ? 1 : 2;
    if (ownerTabIndex === 1) {
      this.residentMaterialScrollerOwner = owner;
    } else {
      this.messageMaterialScrollerOwner = owner;
    }
    if (this.activeTabIndex() === ownerTabIndex) {
      this.onMaterialScrollerOwnerChange(owner);
    }
  }

  private switchWorkspaceTab(index: number): void {
    this.onLocalBackStateChange(this.hasLocalLayerForTab(index));
    this.reportMaterialScrollerOwnerForTab(index);
    this.onSwitchTab(index);
  }

  private openResident(residentId: string): void {
    this.requestedResidentId = residentId;
    this.residentSelectionRequestToken += 1;
    this.switchWorkspaceTab(1);
  }

  @Builder
  private persistentPages() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        WideHomePage({
          compactWidth: this.compactWidth,
          topBarHeight: this.topBarHeight,
          pageScroller: this.homeScroller,
          taskDetailScroller: this.homeTaskDetailScroller,
          naviIndicatorHeight: this.naviIndicatorHeight,
          backRequestToken: this.homeBackRequestToken,
          onOpenAiChat: () => this.onOpenAiChat(),
          onOpenResident: (residentId: string) => this.openResident(residentId),
          onTaskPanelVisibilityChange: (visible: boolean) => this.updateLocalLayer(0, visible)
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.pageVisibility(0))
      .zIndex(this.isActiveTab(0) ? 1 : 0)

      Column() {
        WideResidentPage({
          compactWidth: this.compactWidth,
          topBarHeight: this.topBarHeight,
          masterScroller: this.residentMasterScroller,
          detailScroller: this.residentDetailScroller,
          naviIndicatorHeight: this.naviIndicatorHeight,
          backRequestToken: this.residentBackRequestToken,
          requestedResidentId: this.requestedResidentId,
          residentSelectionRequestToken: this.residentSelectionRequestToken,
          onLocalDetailVisibilityChange: (visible: boolean) => this.updateLocalLayer(1, visible),
          onMasterScrollerActive: () => this.updateMaterialScrollerOwner('residentMaster'),
          onDetailScrollerActive: () => this.updateMaterialScrollerOwner('residentDetail')
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.pageVisibility(1))
      .zIndex(this.isActiveTab(1) ? 1 : 0)

      Column() {
        WideMessagePage({
          compactWidth: this.compactWidth,
          topBarHeight: this.topBarHeight,
          messageListScroller: this.messageListScroller,
          chatScroller: this.messageChatScroller,
          naviIndicatorHeight: this.naviIndicatorHeight,
          backRequestToken: this.messageBackRequestToken,
          onLocalDetailVisibilityChange: (visible: boolean) => this.updateLocalLayer(2, visible),
          onListScrollerActive: () => this.updateMaterialScrollerOwner('messageList'),
          onChatScrollerActive: () => this.updateMaterialScrollerOwner('messageChat'),
          onUnreadCountChange: (count: number) => this.onUnreadCountChange(count)
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.pageVisibility(2))
      .zIndex(this.isActiveTab(2) ? 1 : 0)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    Column() {
      this.persistentPages()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
