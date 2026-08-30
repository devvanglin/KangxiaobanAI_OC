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

import { AppStorageV2, curves, LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  hdsMaterial,
  HdsListItemCard,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  IconSize,
  IconStyleMode,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixText,
  TextStyleMode,
  TitleBarContentOptions,
  TitleBarStyleOptions,
} from '@kit.UIDesignKit';
import { TabPageView } from '../component/TabPageView';
import {
  CaregiverMaterialScrollerOwner,
  WideCaregiverWorkspace
} from '../component/wide/WideCaregiverWorkspace';
import { WideCaregiverTitleActions } from '../component/wide/WideCaregiverTitleActions';
import { WideDoctorWorkspace } from '../component/wide/WideDoctorWorkspace';
import { WideDoctorAdmission } from '../component/wide/WideDoctorAdmission';
import { WideAdminWorkspace } from '../component/wide/WideAdminWorkspace';
import { AI_BRAND_NAME } from '../component/AiTitleLabel';
import { AiChatPage } from '../pages/AiChatPage';
import { MineDetailPage } from '../pages/MineDetailPage';
import { ResidentDetailPage } from '../pages/ResidentDetailPage';
import { StorageKey } from '../common/CommonConstants';
import { MedicationProgress, ResidentData, VitalSign } from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PAGE_SCROLLER_MAP, PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import { TAB_PAGE_CONFIGS, TabPageConfig } from '../model/TabPageModel';
import Logger from '../util/Logger';
import { BreakpointUtil } from '../util/BreakpointSystem';
import { WindowUtil } from '../util/WindowUtil';
import AuthStore from '../network/AuthStore';
import { BusinessStore } from '../network/BusinessStore';
import { Schedule, WsEvent } from '../network/Dto';
import { WsClient } from '../network/WsClient';

const TAG: string = '[MainPage]';
const CAREGIVER_FULL_WORKSPACE_MIN_WIDTH: number = 1180;
const CAREGIVER_TEXT_NAVIGATION_MIN_WIDTH: number = 680;
const WIDE_TITLE_BAR_HEIGHT: number = 56;

interface WideNavItem {
  label: ResourceStr;
  symbol: Resource;
  badge?: string;
  tabIndex?: number;
  action?: () => void;
}

interface WideNavGroup {
  label: string;
  items: WideNavItem[];
}

@Entry
@ComponentV2
struct MainPage {
  @Provider('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ?? new GlobalInfoModel();
  private controller: HdsTabsController = new HdsTabsController();
  private tabsBar: BottomTabBarStyle[] = TabsBarModel.getTabBarByPage(PageKeyEnum.ADAPTIVE_TAB) ?? [];
  private pageConfigs: TabPageConfig[] = TAB_PAGE_CONFIGS;
  @Local currentTabIndex: number = 0;
  @Local primaryTabIndex: number = 0;
  @Local isSidebarCollapsed: boolean = false;
  @Local isAiChatShow: boolean = false;
  @Local aiHistoryCollapsed: boolean = false;
  @Local aiHistoryOpenRequestToken: number = 0;
  @Local aiHistorySearchRequestToken: number = 0;
  @Local aiNewConversationRequestToken: number = 0;
  @Local isResidentDetailShow: boolean = false;
  @Local selectedResident: ResidentData = {
    id: '',
    name: '',
    age: 0,
    gender: 'male',
    room: '',
    bed: '',
    level: 'normal',
    status: '',
    emergencyContact: '',
    emergencyPhone: '',
    admissionDate: '',
    careLevel: '',
    diagnosis: [],
    allergies: [],
    deviceIds: [],
    avatarText: ''
  } as ResidentData;
  @Local selectedResidentVitalSign: VitalSign = {
    heartRate: 0,
    systolic: 0,
    diastolic: 0,
    oxygen: 0,
    temperature: 0,
    respiratory: 0,
    steps: 0,
    sleepHours: 0,
    measuredAt: '--',
    riskLevel: 'normal',
    riskSummary: ''
  };
  @Local selectedResidentMedicationProgress: MedicationProgress = { done: 0, total: 0 };
  @Local selectedResidentGeometryId: string = '';
  @Local caregiverHasLocalBackLayer: boolean = false;
  @Local caregiverBackRequestToken: number = 0;
  @Local caregiverUnreadMessageCount: number = 0;
  @Local caregiverMaterialScrollerOwner: CaregiverMaterialScrollerOwner = 'residentDetail';
  @Local phoneDoctorAdmissionDirty: boolean = false;
  private wideHomeScroller: Scroller = new Scroller();
  private wideHomeTaskDetailScroller: Scroller = new Scroller();
  private wideResidentMasterScroller: Scroller = new Scroller();
  private wideResidentDetailScroller: Scroller = new Scroller();
  private wideMessageListScroller: Scroller = new Scroller();
  private wideMessageChatScroller: Scroller = new Scroller();
  private wideAiChatScroller: ListScroller = new ListScroller();
  private businessWsClient: WsClient = new WsClient();

  aboutToAppear(): void {
    if (AuthStore.getToken().length === 0) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      } catch (_error) {
        Logger.error(TAG, 'Redirect to login failed');
      }
      return;
    }
    BusinessStore.getShared().load();
    this.businessWsClient.connect((payload: string): void => {
      this.handleBusinessEvent(payload);
    });
    WindowUtil.setImmersiveMode(true);
  }

  aboutToDisappear(): void {
    this.businessWsClient.close();
    this.caregiverHasLocalBackLayer = false;
    WindowUtil.setImmersiveMode(false);
  }

  private handleBusinessEvent(payload: string): void {
    try {
      const event: WsEvent<Object> = JSON.parse(payload) as WsEvent<Object>;
      if (event.type === 'admission.submitted' || event.type === 'task.updated' ||
        event.type === 'vital.record' || event.type === 'vital.abnormal' ||
        event.type === 'alert.new' || event.type === 'alert.escalated') {
        BusinessStore.getShared().load(true);
      }
    } catch (_error) {
      Logger.warn(TAG, 'ignored malformed business event');
    }
  }

  @Styles
  pcIconNormalStyle() {
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Styles
  pcIconPressedStyle() {
    .backgroundColor($r('sys.color.interactive_pressed'))
  }

  private getCurrentPageTitle(): ResourceStr {
    return this.pageConfigs[this.currentTabIndex]?.title ?? $r('app.string.tab_home');
  }

  private wideCaregiverActiveTabIndex(): number {
    if (this.currentTabIndex >= 0 && this.currentTabIndex <= 2) {
      return this.currentTabIndex;
    }
    return this.primaryTabIndex >= 0 && this.primaryTabIndex <= 1 ? this.primaryTabIndex : 0;
  }

  private wideCaregiverPageTitle(): string {
    if (this.isAiChatShow) {
      return AI_BRAND_NAME;
    }
    const titles: string[] = ['首页', '长者', '消息'];
    return titles[this.wideCaregiverActiveTabIndex()] ?? titles[0];
  }

  private wideCaregiverBackLabel(): string {
    if (this.isAiChatShow) {
      return '返回首页';
    }
    const labels: string[] = ['返回首页', '返回长者列表', '返回会话列表'];
    return labels[this.wideCaregiverActiveTabIndex()] ?? labels[0];
  }

  private useIconOnlyCaregiverNavigation(): boolean {
    return this.globalInfoModel.deviceWidth > 0 &&
      this.globalInfoModel.deviceWidth < CAREGIVER_TEXT_NAVIGATION_MIN_WIDTH;
  }

  private showCaregiverLocalBackButton(): boolean {
    return this.isCaregiverWideWorkspace() &&
      this.pathStack.size() === 0 &&
      (this.useCompactCaregiverWorkspace() && this.caregiverHasLocalBackLayer);
  }

  private wideCaregiverTitleBarPadding(): number {
    return this.useCompactCaregiverWorkspace() ? 16 : 24;
  }

  private wideCaregiverTopBarHeight(): number {
    return WIDE_TITLE_BAR_HEIGHT + this.globalInfoModel.statusBarHeight;
  }

  private immersiveTitleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
  }

  private navigationTitleBarOptions(): HdsNavigationTitleBarOptions {
    if (this.isCaregiverWideWorkspace()) {
      const horizontalPadding: number = this.wideCaregiverTitleBarPadding();
      const content: TitleBarContentOptions = {
        title: {
          mainTitle: this.wideCaregiverPageTitle()
        },
        menu: { value: [] },
        stackBuilder: (): void => this.wideCaregiverTitleActions()
      };
      if (this.showCaregiverLocalBackButton()) {
        content.backIcon = {
          label: this.wideCaregiverBackLabel(),
          icon: $r('sys.symbol.chevron_left'),
          type: IconStyleMode.SMALL,
          isEnabled: true,
          action: (): void => {
            this.caregiverBackRequestToken += 1;
          }
        };
      }
      return {
        padding: {
          start: LengthMetrics.vp(horizontalPadding),
          end: LengthMetrics.vp(horizontalPadding)
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false,
        content: content,
        style: this.immersiveTitleBarStyle()
      };
    }
    if (!this.isWideLayout() && this.globalInfoModel.role === '医师') {
      return {
        padding: {
          start: LengthMetrics.vp(16),
          end: LengthMetrics.vp(12)
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false,
        content: {
          title: {
            mainTitle: '入住评估'
          },
          menu: { value: [] },
          stackBuilder: (): void => this.phoneDoctorTitleActions()
        },
        style: this.immersiveTitleBarStyle()
      };
    }
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: this.getCurrentPageTitle(),
        },
        menu: { value: [] },
      },
      style: this.immersiveTitleBarStyle()
    };
  }

  private navigationScrollers(): Scroller[] {
    if (!this.isWideLayout()) {
      if (this.globalInfoModel.role === '医师') {
        return [];
      }
      return PAGE_SCROLLER_MAP.get(PageKeyEnum.ADAPTIVE_TAB) ?? [];
    }
    if (this.isCaregiverWideWorkspace()) {
      if (this.isAiChatShow) {
        return [this.wideAiChatScroller];
      }
      const activeTabIndex: number = this.wideCaregiverActiveTabIndex();
      if (activeTabIndex === 0) {
        return [this.wideHomeScroller];
      }
      if (activeTabIndex === 1) {
        if (!this.useCompactCaregiverWorkspace()) {
          return [this.caregiverMaterialScrollerOwner === 'residentMaster' ?
            this.wideResidentMasterScroller : this.wideResidentDetailScroller];
        }
        return this.caregiverHasLocalBackLayer ?
          [this.wideResidentDetailScroller] : [this.wideResidentMasterScroller];
      }
      if (activeTabIndex === 2) {
        if (!this.useCompactCaregiverWorkspace()) {
          return [this.caregiverMaterialScrollerOwner === 'messageList' ?
            this.wideMessageListScroller : this.wideMessageChatScroller];
        }
        return this.caregiverHasLocalBackLayer ?
          [this.wideMessageChatScroller] : [this.wideMessageListScroller];
      }
    }
    return [];
  }

  private updateTabSelection(index: number): void {
    if (index === 0 || index === 1) {
      this.primaryTabIndex = index;
    }
    this.currentTabIndex = index;
  }

  private switchTab(index: number): void {
    if (this.isWideLayout()) {
      this.isAiChatShow = false;
      this.updateTabSelection(index);
    } else {
      this.controller.changeIndex(index);
    }
  }

  private isRoleAdapted(): boolean {
    return this.globalInfoModel.role === '护工' || this.globalInfoModel.role === '医师' ||
      (this.globalInfoModel.role === '管理' && this.isWideLayout());
  }

  @Builder
  private roleWipPanel() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.hammer_fill'))
        .fontSize(56)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(`${this.globalInfoModel.role}端`)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text('适配中')
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_secondary'))
      Text('该角色页面正在开发中，敬请期待')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.globalInfoModel.statusBarHeight })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }

  private isWideLayout(): boolean {
    return BreakpointUtil.usesWideWorkspace(
      this.globalInfoModel.deviceWidth,
      this.globalInfoModel.widthBreakpoint
    );
  }

  private async handleLogout(): Promise<void> {
    try {
      this.businessWsClient.close();
      AuthStore.clear();
      BusinessStore.getShared().clear();
      await WindowUtil.setImmersiveMode(false);
      await this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
    } catch (error) {
      await WindowUtil.setImmersiveMode(true);
      Logger.error(TAG, `logout failed: ${JSON.stringify(error)}`);
    }
  }

  private sidebarWidth(): number {
    return this.isSidebarCollapsed ? 72 : 288;
  }

  private isNavActive(item: WideNavItem): boolean {
    return item.tabIndex !== undefined && this.currentTabIndex === item.tabIndex;
  }

  private handleNavClick(item: WideNavItem): void {
    if (item.tabIndex !== undefined) {
      this.updateTabSelection(item.tabIndex);
    } else if (item.action) {
      item.action();
    }
  }

  private toggleSidebar(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.isSidebarCollapsed = !this.isSidebarCollapsed;
    });
  }

  private openAiChat(): void {
    this.aiHistoryCollapsed = false;
    // Re-open the embedded history pane when a new AI workspace is shown.
    this.aiHistoryOpenRequestToken += 1;
    this.isAiChatShow = true;
  }

  private closeAiChat(): void {
    this.isAiChatShow = false;
    this.aiHistoryCollapsed = false;
  }

  private updateAiHistoryCollapsed(collapsed: boolean): void {
    this.aiHistoryCollapsed = collapsed;
  }

  private requestAiHistoryOpen(): void {
    this.aiHistoryOpenRequestToken += 1;
  }

  private requestAiHistorySearch(): void {
    this.aiHistorySearchRequestToken += 1;
  }

  private requestNewAiConversation(): void {
    this.aiNewConversationRequestToken += 1;
  }

  private openResidentDetail(resident: ResidentData, vitalSign: VitalSign,
    medicationProgress: MedicationProgress, geometryId: string): void {
    this.selectedResident = resident;
    this.selectedResidentVitalSign = vitalSign;
    this.selectedResidentMedicationProgress = medicationProgress;
    this.selectedResidentGeometryId = geometryId;
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 328, 36)
    }, () => {
      this.isResidentDetailShow = true;
    })
  }

  private closeResidentDetail(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.isResidentDetailShow = false;
    })
  }

  private isCaregiverWideWorkspace(): boolean {
    return this.isWideLayout() && this.globalInfoModel.role === '护工';
  }

  private useCompactCaregiverWorkspace(): boolean {
    return BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint) ||
      (this.globalInfoModel.deviceWidth > 0 &&
        this.globalInfoModel.deviceWidth < CAREGIVER_FULL_WORKSPACE_MIN_WIDTH);
  }

  onBackPress(): boolean {
    if (this.isAiChatShow) {
      this.closeAiChat();
      return true;
    }
    if (this.isResidentDetailShow) {
      this.closeResidentDetail();
      return true;
    }
    if (this.isCaregiverWideWorkspace() && this.pathStack.size() === 0 && this.caregiverHasLocalBackLayer) {
      this.caregiverBackRequestToken += 1;
      return true;
    }
    if (this.isWideLayout() && this.pathStack.size() === 0 && this.currentTabIndex !== 0) {
      this.switchTab(0);
      return true;
    }
    return false;
  }

  private wideNavGroups(): WideNavGroup[] {
    return [
      {
        label: '业务',
        items: [
          { label: $r('app.string.tab_home'), symbol: $r('sys.symbol.house_fill'), tabIndex: 0 },
          { label: $r('app.string.tab_music'), symbol: $r('sys.symbol.person_2_fill'), tabIndex: 1 },
          { label: $r('app.string.tab_message'), symbol: $r('sys.symbol.message_on_message_fill'), tabIndex: 2 },
        ]
      },
      {
        label: '管理',
        items: [
          { label: '排班', symbol: $r('sys.symbol.calendar_badge_clock') },
          { label: '服务记录', symbol: $r('sys.symbol.doc_text') },
        ]
      },
      {
        label: '系统',
        items: [
          { label: '帮助', symbol: $r('sys.symbol.questionmark_circle') },
        ]
      },
    ];
  }

  // ==================== PC 侧边栏 ====================

  @Builder
  private pcSidebar() {
    Column() {
      this.pcSidebarHeader()

      Scroll() {
        Column({ space: 20 }) {
          ForEach(this.wideNavGroups(), (group: WideNavGroup, groupIndex: number) => {
            this.pcNavGroup(group, groupIndex)
          }, (group: WideNavGroup, groupIndex: number) => `${groupIndex}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)

      this.pcSidebarFooter()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.globalInfoModel.statusBarHeight })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private pcSidebarHeader() {
    Row() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.house_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.brand_blue')])

        if (!this.isSidebarCollapsed) {
          Column({ space: 2 }) {
            Text('康小伴')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('移动智慧养老')
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
      .layoutWeight(this.isSidebarCollapsed ? 0 : 1)
      .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
      .width(this.isSidebarCollapsed ? '100%' : undefined)
      .alignItems(VerticalAlign.Center)

      if (!this.isSidebarCollapsed) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(14)
            .fontColor([$r('sys.color.font_tertiary')])
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .stateStyles({
          normal: this.pcIconNormalStyle,
          pressed: this.pcIconPressedStyle
        })
        .focusable(true)
        .onClick(() => {
          this.toggleSidebar();
        })
      }
    }
    .width('100%')
    .height(68)
    .padding({ left: this.isSidebarCollapsed ? 0 : 20, right: this.isSidebarCollapsed ? 0 : 12 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private pcSidebarFooter() {
    Column() {
      if (this.isSidebarCollapsed) {
        HdsListItemCard({
          prefixItem: new PrefixIcon({
            iconSize: IconSize.SYSTEM_ICON,
            iconValue: {
              symbol: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill'))
                .fontColor([$r('sys.color.icon_secondary')])
            }
          }),
          cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          cardHeight: 56,
          cardBorderRadius: 12,
          cardPrefixMargin: 0,
          cardSuffixMargin: 0
        })
      } else {
        HdsListItemCard({
          prefixItem: new PrefixIcon({
            iconSize: IconSize.SYSTEM_ICON,
            iconValue: {
              symbol: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill'))
                .fontColor([$r('sys.color.icon_secondary')])
            }
          }),
          textItem: {
            primaryText: { text: this.currentUserDisplayName() },
            secondaryText: { text: this.currentUserWorkLabel() }
          },
          suffixItem: new SuffixArrow(),
          cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          cardHeight: 56,
          cardBorderRadius: 12,
          cardPrefixMargin: 0,
          cardSuffixMargin: 0
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
  }

  private currentUserDisplayName(): string {
    const user = AuthStore.getUser();
    return user?.real_name || user?.username || '当前用户';
  }

  private currentUserRoleLabel(): string {
    const user = AuthStore.getUser();
    if (!user || user.roles.length === 0) {
      return '未分配角色';
    }
    return user.roles.map((role) => role.name || role.code).join('、');
  }

  private currentDateValue(): string {
    const now: Date = new Date();
    return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${
      now.getDate().toString().padStart(2, '0')}`;
  }

  private currentUserWorkLabel(): string {
    const user = AuthStore.getUser();
    const schedule: Schedule | undefined = BusinessStore.getShared().schedules.find((item: Schedule) =>
      item.work_date === this.currentDateValue() &&
      (item.staff === user?.real_name || item.staff === user?.username));
    if (!schedule) {
      return this.currentUserRoleLabel();
    }
    const scope: string = schedule.room_scope && schedule.room_scope.length > 0 ? ` · ${schedule.room_scope}` : '';
    return `${this.currentUserRoleLabel()} · ${schedule.shift}${scope}`;
  }

  @Builder
  private pcNavGroup(group: WideNavGroup, groupIndex: number) {
    Column({ space: 6 }) {
      if (!this.isSidebarCollapsed) {
        Text(group.label)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8, top: 4, bottom: 2 })
      }
      Column({ space: 2 }) {
        ForEach(group.items, (item: WideNavItem, index: number) => {
          if (this.isSidebarCollapsed) {
            this.pcNavItemCollapsed(item, this.isNavActive(item))
          } else {
            this.pcNavItemExpanded(item, this.isNavActive(item))
          }
        }, (item: WideNavItem, index: number) => `${groupIndex}-${index}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private pcNavItemExpanded(item: WideNavItem, isActive: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(item.symbol)
            .fontColor([isActive ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        }
      }),
      textItem: {
        primaryText: {
          text: item.label
        }
      },
      suffixItem: item.badge ? new SuffixText({ text: item.badge }) : new SuffixArrow(),
      cardBackgroundColor: isActive ? $r('sys.color.comp_background_emphasize') :
        $r('sys.color.ohos_id_color_background_transparent'),
      cardHeight: 48,
      cardBorderRadius: 12,
      cardPrefixMargin: 4,
      cardSuffixMargin: 0
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.handleNavClick(item);
    })
  }

  @Builder
  private pcNavItemCollapsed(item: WideNavItem, isActive: boolean) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier(item.symbol)
            .fontColor([isActive ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        }
      }),
      cardBackgroundColor: isActive ? $r('sys.color.comp_background_emphasize') :
        $r('sys.color.ohos_id_color_background_transparent'),
      cardHeight: 48,
      cardBorderRadius: 12,
      cardPrefixMargin: 0,
      cardSuffixMargin: 0
    })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.handleNavClick(item);
    })
  }

  // ==================== PC 顶部栏 ====================

  @Builder
  private pcTopBar() {
    Row({ space: 16 }) {
      Row({ space: 12 }) {
        if (this.isSidebarCollapsed) {
          Row() {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize($r('sys.float.Title_S'))
              .fontColor([$r('sys.color.font_primary')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .stateStyles({
            normal: this.pcIconNormalStyle,
            pressed: this.pcIconPressedStyle
          })
          .focusable(true)
          .onClick(() => {
            this.toggleSidebar();
          })
        }

        Column({ space: 2 }) {
          Text(this.getCurrentPageTitle())
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('移动智慧养老 · 半山敬老院')
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Row({ space: 8 }) {
        this.pcTopBarIcon($r('sys.symbol.bell'), true)
        this.pcTopBarIcon($r('sys.symbol.gearshape'), false)
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(36)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(64)
    .padding({ left: 24, right: 24 })
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
    .margin({ top: this.globalInfoModel.statusBarHeight })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private pcTopBarIcon(symbol: Resource, hasBadge: boolean) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        SymbolGlyph(symbol)
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: this.pcIconNormalStyle,
        pressed: this.pcIconPressedStyle
      })
      .focusable(true)

      if (hasBadge) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.status_danger'))
          .margin({ top: 6, right: 6 })
      }
    }
    .width(40)
    .height(40)
  }

  // ==================== 手机端（原样保留） ====================

  private phoneFloatingBarWidth(): number {
    const windowWidth: number = this.globalInfoModel.deviceWidth;
    if (windowWidth <= 0) {
      return 328;
    }
    return Math.max(240, Math.min(328, windowWidth - 32));
  }

  @Builder
  private phoneTabs() {
    HdsTabs({ controller: this.controller, index: this.currentTabIndex }) {
      TabContent() {
        TabPageView({
          currentTabIndex: 0,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[0],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          },
          onOpenResidentDetail: (resident: ResidentData, vitalSign: VitalSign,
            medicationProgress: MedicationProgress, geometryId: string) => {
            this.openResidentDetail(resident, vitalSign, medicationProgress, geometryId);
          }
        })
      }
      .tabBar(this.tabsBar[0])

      TabContent() {
        TabPageView({
          currentTabIndex: 1,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[1],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          },
          onOpenResidentDetail: (resident: ResidentData, vitalSign: VitalSign,
            medicationProgress: MedicationProgress, geometryId: string) => {
            this.openResidentDetail(resident, vitalSign, medicationProgress, geometryId);
          }
        })
      }
      .tabBar(this.tabsBar[1])

      TabContent() {
        TabPageView({
          currentTabIndex: 2,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[2],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          },
          onOpenResidentDetail: (resident: ResidentData, vitalSign: VitalSign,
            medicationProgress: MedicationProgress, geometryId: string) => {
            this.openResidentDetail(resident, vitalSign, medicationProgress, geometryId);
          }
        })
      }
      .tabBar(this.tabsBar[2])

      TabContent() {
        TabPageView({
          currentTabIndex: 3,
          pageKey: PageKeyEnum.ADAPTIVE_TAB,
          config: this.pageConfigs[3],
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onOpenAiChat: () => {
            this.openAiChat();
          },
          onOpenResidentDetail: (resident: ResidentData, vitalSign: VitalSign,
            medicationProgress: MedicationProgress, geometryId: string) => {
            this.openResidentDetail(resident, vitalSign, medicationProgress, geometryId);
          }
        })
      }
      .tabBar(this.tabsBar[3])
    }
    .barMode(BarMode.Fixed)
    .barHeight(56)
    .barOverlap(true)
    .vertical(false)
    .scrollable(false)
    .onAnimationStart((_index: number, targetIndex: number, _event: TabsAnimationEvent) => {
      if (this.currentTabIndex !== targetIndex) {
        this.updateTabSelection(targetIndex);
      }
    })
    .onChange((index: number) => {
      if (this.currentTabIndex !== index) {
        this.updateTabSelection(index);
      }
    })
    .barPosition(BarPosition.End)
    .barFloatingStyle({
      barWidth: {
        smallWidth: this.phoneFloatingBarWidth(),
        mediumWidth: this.phoneFloatingBarWidth(),
        largeWidth: this.phoneFloatingBarWidth()
      },
      barSideMargin: 16,
      barBottomMargin: this.globalInfoModel.naviIndicatorHeight > 0 ? this.globalInfoModel.naviIndicatorHeight :
        $r('sys.float.padding_level8'),
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .width('100%')
    .height('100%')
    .onAttach(() => {
      try {
        this.controller.preloadItems([0, 1, 2, 3]);
      } catch (error) {
        Logger.error(TAG, 'OnAttach preloadItems failed');
      }
    })
  }

  @Builder
  private phoneDoctorProfileMenu() {
    Menu() {
      MenuItem({ content: '退出登录' })
        .height(46)
        .contentFont({ size: 14, weight: FontWeight.Medium })
        .contentFontColor($r('app.color.status_danger'))
        .onClick(() => this.requestPhoneDoctorLogout())
    }
    .width(180)
    .radius(14)
  }

  @Builder
  private phoneDoctorTitleActions() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(30)
          .fontColor([$r('app.color.brand_blue')])
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .accessibilityText('打开账户菜单')
      .bindMenu(this.phoneDoctorProfileMenu, {
        placement: Placement.BottomRight,
        enableArrow: true,
        offset: { x: 0, y: 6 }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ right: 8 })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  private requestPhoneDoctorLogout(): void {
    if (!this.phoneDoctorAdmissionDirty) {
      this.handleLogout();
      return;
    }
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.doctor_admission_leave_title'),
        message: $r('app.string.doctor_admission_leave_message'),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        buttons: [
          {
            value: $r('app.string.doctor_admission_leave_stay'),
            action: () => {
            }
          },
          {
            value: $r('app.string.doctor_admission_leave_discard'),
            fontColor: $r('app.color.status_danger'),
            action: () => {
              this.phoneDoctorAdmissionDirty = false;
              this.handleLogout();
            }
          }
        ]
      });
    } catch (_error) {
      Logger.warn(TAG, 'Doctor admission logout dialog unavailable');
    }
  }

  @Builder
  private phoneDoctorAdmission() {
    WideDoctorAdmission({
      compactWidth: true,
      standaloneMode: true,
      contentTopInset: WIDE_TITLE_BAR_HEIGHT + this.globalInfoModel.statusBarHeight,
      naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
      onDirtyChange: (dirty: boolean) => {
        this.phoneDoctorAdmissionDirty = dirty;
      },
      onExit: () => {
        this.handleLogout();
      }
    })
  }

  // ==================== 平板 / PC 共用工作台 ====================

  @Builder
  private wideCaregiverTitleActions() {
    WideCaregiverTitleActions({
      currentTabIndex: this.currentTabIndex,
      primaryTabIndex: this.primaryTabIndex,
      unreadMessageCount: this.caregiverUnreadMessageCount,
      aiChatVisible: this.isAiChatShow,
      aiHistoryCollapsed: this.aiHistoryCollapsed,
      compactWidth: this.useCompactCaregiverWorkspace(),
      iconOnlyNavigation: this.useIconOnlyCaregiverNavigation(),
      onSwitchTab: (index: number) => {
        this.switchTab(index);
      },
      onOpenAiChat: () => {
        this.openAiChat();
      },
      onOpenAiHistory: () => {
        this.requestAiHistoryOpen();
      },
      onSearchAiHistory: () => {
        this.requestAiHistorySearch();
      },
      onNewAiConversation: () => {
        this.requestNewAiConversation();
      },
      onOpenAbout: () => {
        this.pathStack.pushPath({ name: 'AboutPage' });
      },
      onOpenGeneral: () => {
        this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
      },
      onLogout: () => {
        this.handleLogout();
      }
    })
  }

  @Builder
  private wideShell() {
    if (this.globalInfoModel.role === '管理') {
      WideAdminWorkspace({
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        compactWidth: BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint),
        onOpenAbout: () => {
          this.pathStack.pushPath({ name: 'AboutPage' });
        },
        onOpenGeneral: () => {
          this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
        },
        onLogout: () => {
          this.handleLogout();
        }
      })
    } else if (this.globalInfoModel.role === '医师') {
      WideDoctorWorkspace({
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        compactWidth: BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint),
        admissionCompactWidth: this.globalInfoModel.widthBreakpoint !== WidthBreakpoint.WIDTH_XL,
        onOpenAbout: () => {
          this.pathStack.pushPath({ name: 'AboutPage' });
        },
        onOpenGeneral: () => {
          this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
        },
        onLogout: () => {
          this.handleLogout();
        }
      })
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        WideCaregiverWorkspace({
          currentTabIndex: this.currentTabIndex,
          primaryTabIndex: this.primaryTabIndex,
          topBarHeight: this.wideCaregiverTopBarHeight(),
          homeScroller: this.wideHomeScroller,
          homeTaskDetailScroller: this.wideHomeTaskDetailScroller,
          residentMasterScroller: this.wideResidentMasterScroller,
          residentDetailScroller: this.wideResidentDetailScroller,
          messageListScroller: this.wideMessageListScroller,
          messageChatScroller: this.wideMessageChatScroller,
          naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
          compactWidth: this.useCompactCaregiverWorkspace(),
          backRequestToken: this.caregiverBackRequestToken,
          onSwitchTab: (index: number) => {
            this.switchTab(index);
          },
          onLocalBackStateChange: (hasLocalLayer: boolean) => {
            this.caregiverHasLocalBackLayer = hasLocalLayer;
          },
          onMaterialScrollerOwnerChange: (owner: CaregiverMaterialScrollerOwner) => {
            this.caregiverMaterialScrollerOwner = owner;
          },
          onUnreadCountChange: (count: number) => {
            this.caregiverUnreadMessageCount = count;
          },
          onOpenAiChat: () => {
            this.openAiChat();
          }
        })
        .width('100%')
        .height('100%')
        .visibility(this.isAiChatShow ? Visibility.Hidden : Visibility.Visible)
        .zIndex(this.isAiChatShow ? 0 : 1)

        AiChatPage({
          caregiverWideImmersive: false,
          embeddedCaregiverWide: true,
          embeddedListScroller: this.wideAiChatScroller,
          historyOpenRequestToken: this.aiHistoryOpenRequestToken,
          historySearchRequestToken: this.aiHistorySearchRequestToken,
          newConversationRequestToken: this.aiNewConversationRequestToken,
          onHistoryCollapsedChange: (collapsed: boolean) => {
            this.updateAiHistoryCollapsed(collapsed);
          },
          onClose: () => {
            this.closeAiChat();
          }
        })
        .width('100%')
        .height('100%')
        .visibility(this.isAiChatShow ? Visibility.Visible : Visibility.Hidden)
        .zIndex(this.isAiChatShow ? 1 : 0)
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private destinationBuilder(name: string, param?: ESObject) {
    if (name === 'AboutPage') {
      MineDetailPage({ pageType: 'about' })
    } else if (name === 'GeneralSettingsPage') {
      MineDetailPage({ pageType: 'general' })
    }
  }

  @Builder
  private aiChatCover() {
    AiChatPage({
      caregiverWideImmersive: this.isCaregiverWideWorkspace(),
      embeddedListScroller: this.wideAiChatScroller,
      onClose: () => {
        this.closeAiChat();
      }
    })
  }

  @Builder
  private residentDetailCover() {
    ResidentDetailPage({
      resident: this.selectedResident,
      vitalSignData: this.selectedResidentVitalSign,
      medicationProgress: this.selectedResidentMedicationProgress,
      geometryId: this.selectedResidentGeometryId,
      onClose: () => {
        this.closeResidentDetail();
      }
    })
  }

  build() {
    Stack() {
      if (this.isRoleAdapted()) {
        HdsNavigation(this.pathStack) {
          if (this.isWideLayout()) {
            this.wideShell()
          } else if (this.globalInfoModel.role === '医师') {
            this.phoneDoctorAdmission()
          } else {
            this.phoneTabs()
          }
        }
        .mode(NavigationMode.Stack)
        .navDestination(this.destinationBuilder)
        .titleBar(this.navigationTitleBarOptions())
        .bindToScrollable(this.navigationScrollers())
        .hideBackButton(!this.showCaregiverLocalBackButton())
        .hideTitleBar(this.isWideLayout() && !this.isCaregiverWideWorkspace(), true)
        .titleMode(HdsNavigationTitleMode.MINI)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.background_secondary'))
      } else {
        this.roleWipPanel()
      }

      if (this.isAiChatShow && !this.isCaregiverWideWorkspace()) {
        this.aiChatCover()
      }

      if (this.isResidentDetailShow) {
        this.residentDetailCover()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
