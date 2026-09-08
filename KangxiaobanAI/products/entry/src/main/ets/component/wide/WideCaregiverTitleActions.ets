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

import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

@ComponentV2
export struct WideCaregiverTitleActions {
  @Param @Require currentTabIndex: number;
  @Param @Require primaryTabIndex: number;
  @Param unreadMessageCount: number = 0;
  @Param aiChatVisible: boolean = false;
  /** True while the embedded AI conversation history is collapsed. */
  @Param aiHistoryCollapsed: boolean = false;
  @Param compactWidth: boolean = false;
  @Param iconOnlyNavigation: boolean = false;
  @Event onSwitchTab: (index: number) => void = (_index: number) => {};
  @Event onOpenAiChat: () => void = () => {};
  @Event onOpenAiHistory: () => void = () => {};
  @Event onSearchAiHistory: () => void = () => {};
  @Event onNewAiConversation: () => void = () => {};
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};

  private navigationItems(): WideSlidingCapsuleItem[] {
    return [
      { title: '首页', symbol: $r('sys.symbol.house_fill'), index: 0 },
      { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
      {
        title: '消息',
        symbol: $r('sys.symbol.message_on_message_fill'),
        index: 2,
        badgeText: this.unreadMessageCount > 0 ? this.unreadMessageCount.toString() : undefined,
        badgeTextColor: $r('app.color.text_on_brand'),
        badgeBackgroundColor: $r('app.color.status_danger'),
        badgeAtCorner: true
      },
      { title: '康小伴 AI', symbol: $r('sys.symbol.AI_model'), index: 3 }
    ];
  }

  private activeTabIndex(): number {
    if (this.aiChatVisible) {
      return 3;
    }
    if (this.currentTabIndex >= 0 && this.currentTabIndex <= 2) {
      return this.currentTabIndex;
    }
    return this.primaryTabIndex >= 0 && this.primaryTabIndex <= 1 ? this.primaryTabIndex : 0;
  }

  /**
   * HDS keeps the native title in the title-bar stack and lays custom content
   * from the leading edge. Keep the collapsed-history capsule just after the
   * native "康小伴 AI" title instead of letting the action row push it to the
   * far right.
   */
  private aiHistoryCapsuleLeft(): number {
    return this.compactWidth ? 136 : 144;
  }

  @Builder
  private aiHistoryActionButton(symbol: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(19)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(36)
    .height(36)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .focusable(true)
    .focusOnTouch(true)
    .onClick(action)
  }

  /** Compact controls that remain reachable after the history pane slides away. */
  @Builder
  private aiHistoryActions() {
    Row({ space: 2 }) {
      this.aiHistoryActionButton($r('sys.symbol.open_sidebar'), '展开对话记录', () => {
        this.onOpenAiHistory();
      })
      this.aiHistoryActionButton($r('sys.symbol.magnifyingglass'), '搜索对话记录', () => {
        this.onSearchAiHistory();
      })
      this.aiHistoryActionButton($r('sys.symbol.message_badge_plus_fill'), '新建对话', () => {
        this.onNewAiConversation();
      })
    }
    .height(44)
    .padding({ left: 5, right: 5 })
    .borderRadius(22)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.08)', offsetY: 2 })
    .opacity(this.aiHistoryCollapsed ? 1 : 0)
    .scale({
      x: this.aiHistoryCollapsed ? 1 : 0.82,
      y: this.aiHistoryCollapsed ? 1 : 0.82,
      centerX: '0%',
      centerY: '50%'
    })
    .translate({ x: this.aiHistoryCollapsed ? 0 : -16 })
    .animation({ duration: 240, curve: Curve.Friction })
  }

  @Builder
  private primaryNavigation() {
    Row() {
      WideSlidingCapsule({
        items: this.navigationItems(),
        selectedIndex: this.activeTabIndex(),
        itemWidth: this.iconOnlyNavigation ? 48 : 124,
        iconOnly: this.iconOnlyNavigation,
        slideMemoryKey: 'caregiver-title-nav',
        onSelect: (index: number) => {
          if (index === 3) {
            this.onOpenAiChat();
          } else {
            this.onSwitchTab(index);
          }
        }
      })
    }
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 6 }) {
        Blank()
          .layoutWeight(1)
        this.primaryNavigation()
      }
      .width('100%')
      .height('100%')
      // 头像由 MainPage 的稳定节点承载，这里预留其宽度避免胶囊与其重叠。
      .padding({ right: (this.compactWidth ? 18 : 28) + 54 })
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)

      if (this.aiChatVisible) {
        Row() {
          this.aiHistoryActions()
        }
        // HDS owns the safe-area offset, so center against its full action slot.
        .width('100%')
        .height('100%')
        .padding({ left: this.aiHistoryCapsuleLeft() })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .zIndex(3)
        // This row spans the title bar for alignment. Keep its buttons active
        // while allowing taps elsewhere to reach the navigation underneath.
        .hitTestBehavior(this.aiHistoryCollapsed ? HitTestMode.Transparent : HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
