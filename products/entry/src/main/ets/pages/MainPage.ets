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
import { WideDoctorResidentPage } from '../component/wide/WideDoctorResidentPage';
import { WideDoctorCasesPage } from '../component/wide/WideDoctorCasesPage';
import { WideCaregiverTitleActions } from '../component/wide/WideCaregiverTitleActions';
import { WideAdminWorkspace } from '../component/wide/WideAdminWorkspace';
import { WideDoctorAdmissionForm } from '../component/wide/WideDoctorAdmissionForm';
import { WideAssessmentAgentPage } from '../component/wide/WideAssessmentAgentPage';
import { WideAssessmentReportPage } from '../component/wide/WideAssessmentReportPage';
import { AssessmentAgentSession } from '../network/AssessmentAgentApi';
import { WideDoctorBedsPage } from '../component/wide/WideDoctorBedsPage';
import { WideDoctorTasksPage } from '../component/wide/WideDoctorTasksPage';
import { WideDoctorAlertsPage } from '../component/wide/WideDoctorAlertsPage';
import { WideDoctorAssessmentsPage } from '../component/wide/WideDoctorAssessmentsPage';
import { WideDoctorBillsPage } from '../component/wide/WideDoctorBillsPage';
import { WideDoctorTitleActions } from '../component/wide/WideDoctorTitleActions';
import { WideDoctorAiPage } from './WideDoctorAiPage';
import { AiChatPage } from '../pages/AiChatPage';
import { MineDetailPage } from '../pages/MineDetailPage';
import { WideKnowledgeCreatePage, KBCreatePageParam } from '../component/wide/WideKnowledgeCreatePage';
import { WideRagDocumentsPage, RagDocsPageParam } from '../component/wide/WideRagDocumentsPage';
import { ResidentDetailPage } from '../pages/ResidentDetailPage';
import { StorageKey } from '../common/CommonConstants';
import { MedicationProgress, ResidentData, VitalSign } from '../model/DetailTypes';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { PAGE_SCROLLER_MAP, PageKeyEnum, TabsBarModel } from '../model/TabsBarModel';
import { TAB_PAGE_CONFIGS, TabPageConfig } from '../model/TabPageModel';
import Logger from '../util/Logger';
import { BreakpointUtil } from '../util/BreakpointSystem';
import { WindowUtil } from '../util/WindowUtil';
import { PreferenceManager } from '../util/PreferenceManager';
import AuthStore from '../network/AuthStore';
import { BusinessStore } from '../network/BusinessStore';
import { Alert, Elder, HealthRecord, Schedule, WsEvent } from '../network/Dto';
import { WsClient } from '../network/WsClient';

const TAG: string = '[MainPage]';
const CAREGIVER_FULL_WORKSPACE_MIN_WIDTH: number = 1180;
const DOCTOR_FULL_WORKSPACE_MIN_WIDTH: number = 1180;
const CAREGIVER_TEXT_NAVIGATION_MIN_WIDTH: number = 680;
const WIDE_TITLE_BAR_HEIGHT: number = 56;
const CAREGIVER_AI_HISTORY_COLLAPSED_KEY: string = 'caregiver_ai_history_collapsed';
const DOCTOR_AI_HISTORY_COLLAPSED_KEY: string = 'doctor_ai_history_collapsed';

// Doctor quick-function module ids map to dedicated immersive route pages.
function doctorQuickRouteName(moduleId: string): string {
  switch (moduleId) {
    case 'beds': return 'DoctorBedsPage';
    case 'alerts': return 'DoctorAlertsPage';
    case 'assessment': return 'DoctorAssessmentsPage';
    case 'billing': return 'DoctorBillsPage';
    case 'cases': return 'DoctorCasesPage';
    default: return '';
  }
}

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

type DoctorResidentScrollerOwner = 'residentMaster' | 'residentDetail';

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
  /** 护工端标题胶囊的选中索引（含 AI=3）：内容索引 currentTabIndex 不含 AI 态，
   * 两者仅在 AI 会话打开期间分叉。 */
  @Local caregiverNavIndex: number = 0;
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
  @Local managementNavIndex: number = 0;
  /** 主导航栏是否可见：推入任意 NavDestination 二级页时为 false。
   * pathStack.size() 不是响应式状态，push/pop 不会触发重渲染，
   * 标题动作覆盖层/头像的显隐必须靠这个回调驱动。 */
  @Local navBarVisible: boolean = true;
  @Local adminHasLocalNavLayer: boolean = false;
  @Local adminBackRequestToken: number = 0;
  @Local doctorResidentDetailVisible: boolean = false;
  /** 医师选中的长者：提升到 MainPage，离开「长者」页再回来时保留选中。 */
  @Local doctorSelectedResidentId: string = '';
  @Local doctorResidentBackRequestToken: number = 0;
  @Local doctorResidentScrollerOwner: DoctorResidentScrollerOwner = 'residentDetail';
  @Local doctorAiHistoryCollapsed: boolean = false;
  @Local doctorAiHistoryOpenRequestToken: number = 0;
  @Local doctorAiHistorySearchRequestToken: number = 0;
  @Local doctorAiNewConversationRequestToken: number = 0;
  @Local workspaceClockTime: string = '--:--';
  /** 标题栏账户菜单显隐：头像与面板都挂在页面自身树上，不受 stackBuilder 重建影响。 */
  @Local titleAccountMenuVisible: boolean = false;
  @Local titleAccountPressed: boolean = false;
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  private wideHomeScroller: Scroller = new Scroller();
  private wideHomeTaskDetailScroller: Scroller = new Scroller();
  private wideResidentMasterScroller: Scroller = new Scroller();
  private wideResidentDetailScroller: Scroller = new Scroller();
  private wideDoctorResidentMasterScroller: Scroller = new Scroller();
  private wideDoctorResidentDetailScroller: Scroller = new Scroller();
  private wideMessageListScroller: Scroller = new Scroller();
  private wideMessageChatScroller: Scroller = new Scroller();
  private wideManagementScroller: Scroller = new Scroller();
  private workspaceClockTimerId: number = -1;
  private wideAiChatScroller: ListScroller = new ListScroller();
  private wideDoctorAiChatScroller: ListScroller = new ListScroller();
  private businessWsClient: WsClient = new WsClient();
  private preferenceManager: PreferenceManager = PreferenceManager.getInstance();

  aboutToAppear(): void {
    if (AuthStore.getToken().length === 0) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      } catch (_error) {
        Logger.error(TAG, 'Redirect to login failed');
      }
      return;
    }
    this.aiHistoryCollapsed = this.preferenceManager.getValue<boolean>(
      CAREGIVER_AI_HISTORY_COLLAPSED_KEY,
      JSON.stringify(false)
    ) ?? false;
    this.doctorAiHistoryCollapsed = this.preferenceManager.getValue<boolean>(
      DOCTOR_AI_HISTORY_COLLAPSED_KEY,
      JSON.stringify(false)
    ) ?? false;
    BusinessStore.getShared().load();
    this.refreshWorkspaceClock();
    this.businessWsClient.connect((payload: string): void => {
      this.handleBusinessEvent(payload);
    });
    WindowUtil.setImmersiveMode(true);
  }

  aboutToDisappear(): void {
    this.businessWsClient.close();
    this.stopWorkspaceClock();
    this.caregiverHasLocalBackLayer = false;
    WindowUtil.setImmersiveMode(false);
  }

  private formatCurrentTime(): string {
    const now: Date = new Date();
    return `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  }

  private refreshWorkspaceClock(): void {
    // 标题栏 options 每变化一次，HdsNavigation 都会整体销毁重建标题栏内容
    // （导航胶囊曾挂在那里，动画被打断、点击被吞的根源）。秒级时钟曾让这件事
    // 每秒发生。标题只保留到分钟，且文本真正变化时才赋值，把重建频率降到
    // 1 次/分钟。
    const next: string = this.formatCurrentTime();
    if (next !== this.workspaceClockTime) {
      this.workspaceClockTime = next;
    }
    this.stopWorkspaceClock();
    const now: Date = new Date();
    const msToNextMinute: number = 60000 - now.getSeconds() * 1000 - now.getMilliseconds() + 50;
    this.workspaceClockTimerId = setTimeout((): void => {
      this.workspaceClockTimerId = -1;
      this.refreshWorkspaceClock();
    }, msToNextMinute);
  }

  private stopWorkspaceClock(): void {
    if (this.workspaceClockTimerId !== -1) {
      clearTimeout(this.workspaceClockTimerId);
      this.workspaceClockTimerId = -1;
    }
  }

  private handleBusinessEvent(payload: string): void {
    try {
      const event: WsEvent<Object> = JSON.parse(payload) as WsEvent<Object>;
      if (event.type === 'admission.submitted' || event.type === 'task.updated' ||
        event.type === 'vital.record' || event.type === 'vital.abnormal' ||
        event.type === 'alert.new' || event.type === 'alert.escalated' ||
        event.type === 'assessment.package.assigned') {
        // Coalesce bursts of realtime events so a refresh never keeps the
        // global loading state alive indefinitely.
        BusinessStore.getShared().requestRefresh();
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

  /** 标题胶囊的选中来源：唯一事实来源是 caregiverNavIndex（switchTab/openAiChat/
   * closeAiChat 都同步维护它），胶囊组件据此渲染高亮与滑块位置。 */
  private caregiverTitleNavIndex(): number {
    return this.caregiverNavIndex >= 0 && this.caregiverNavIndex <= 3 ? this.caregiverNavIndex : 0;
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

  private isManagementWideWorkspace(): boolean {
    return this.isWideLayout() && (this.workspaceCode() === 'doctor' || this.workspaceCode() === 'admin');
  }

  private isDoctorResidentWorkspace(): boolean {
    return this.isManagementWideWorkspace() && this.workspaceCode() === 'doctor' && this.managementNavIndex === 1;
  }

  private isDoctorAiWorkspace(): boolean {
    return this.isManagementWideWorkspace() && this.workspaceCode() === 'doctor' && this.managementNavIndex === 2;
  }

  private showDoctorResidentBackButton(): boolean {
    return this.isDoctorResidentWorkspace() && this.useCompactDoctorWorkspace() &&
      this.doctorResidentDetailVisible && this.pathStack.size() === 0;
  }

  private useCompactDoctorWorkspace(): boolean {
    return BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint) ||
      (this.globalInfoModel.deviceWidth > 0 &&
        this.globalInfoModel.deviceWidth < DOCTOR_FULL_WORKSPACE_MIN_WIDTH);
  }

  private wideDoctorTopBarHeight(): number {
    return WIDE_TITLE_BAR_HEIGHT + this.globalInfoModel.statusBarHeight;
  }

  private updateManagementNav(index: number): void {
    if (this.managementNavIndex === 1 && index !== 1) {
      this.doctorResidentDetailVisible = false;
      this.doctorResidentScrollerOwner = 'residentDetail';
    }
    // 选中与内容同帧立即切换：胶囊挂在页面稳定节点上，不受标题栏重建影响，
    // 不再需要"先播动画后切内容"的让帧延迟。
    this.managementNavIndex = index;
  }

  /**
   * 标题栏账户入口 + 菜单：头像本体放在页面自身树上——标题栏 stackBuilder
   * 每次重建都会销毁其内节点和弹层（点击有动画但菜单被吞的根因），
   * 因此头像与菜单都由这个稳定节点承载，菜单为自绘面板 + 点外关闭层。
   */
  private toggleTitleAccountMenu(): void {
    this.titleAccountMenuVisible = !this.titleAccountMenuVisible;
  }

  private closeTitleAccountMenu(): void {
    this.titleAccountMenuVisible = false;
  }

  private titleAccountAnchorX(buttonWidth: number): number {
    const edgePadding: number = this.isCaregiverWideWorkspace() && this.useCompactCaregiverWorkspace() ? 18 : 28;
    return this.globalInfoModel.deviceWidth - edgePadding - buttonWidth;
  }

  private titleAccountPanelWidth(): number {
    return this.isCaregiverWideWorkspace() ? 280 : 220;
  }

  @Builder
  private titleAccountMenuAnchor() {
    if (this.isRoleAdapted() && this.isWideLayout() && this.navBarVisible && !this.isResidentDetailShow) {
      if (this.titleAccountMenuVisible) {
        // 点外关闭层：盖住整窗，点击任意处收起菜单。
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.closeTitleAccountMenu())
      }
      if (this.isCaregiverWideWorkspace()) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(42)
        .height(42)
        .padding(0)
        .borderRadius(21)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .accessibilityText(`${this.currentUserDisplayName()}，${this.currentUserRoleLabel()}，打开账户菜单`)
        .onClick(() => this.toggleTitleAccountMenu())
        .scale({
          x: this.titleAccountPressed ? 0.9 : 1,
          y: this.titleAccountPressed ? 0.9 : 1
        })
        .animation({ duration: 160, curve: Curve.Friction })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.titleAccountPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.titleAccountPressed = false;
          }
        })
        .position({
          x: this.titleAccountAnchorX(42),
          y: this.globalInfoModel.statusBarHeight + 7
        })
      } else {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(42)
        .height(42)
        .padding(0)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .accessibilityText(this.workspaceCode() === 'doctor' ? '医师账户' : '管理端账户')
        .onClick(() => this.toggleTitleAccountMenu())
        .scale({
          x: this.titleAccountPressed ? 0.9 : 1,
          y: this.titleAccountPressed ? 0.9 : 1
        })
        .animation({ duration: 160, curve: Curve.Friction })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.titleAccountPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.titleAccountPressed = false;
          }
        })
        .position({
          x: this.titleAccountAnchorX(42),
          y: this.globalInfoModel.statusBarHeight + 7
        })
      }
      if (this.titleAccountMenuVisible) {
        this.titleAccountMenuPanel()
      }
    }
  }

  @Builder
  private titleAccountMenuItem(symbol: Resource, label: string, danger: boolean, action: () => void) {
    Row({ space: 10 }) {
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor([danger ? $r('app.color.status_danger') : $r('sys.color.icon_primary')])
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(danger ? $r('app.color.status_danger') : $r('sys.color.font_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .borderRadius(10)
    .onClick(() => {
      this.closeTitleAccountMenu();
      action();
    })
  }

  @Builder
  private titleAccountMenuPanel() {
    Column({ space: 2 }) {
      if (this.isCaregiverWideWorkspace()) {
        Column({ space: 4 }) {
          Text(this.currentUserDisplayName())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(this.currentUserRoleLabel())
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 8 })
        .alignItems(HorizontalAlign.Start)

        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ bottom: 4 })
      }
      this.titleAccountMenuItem($r('sys.symbol.gearshape'), '通用设置', false, (): void => {
        this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
      })
      this.titleAccountMenuItem($r('sys.symbol.info_circle'), '关于我们', false, (): void => {
        this.pathStack.pushPath({ name: 'AboutPage' });
      })
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ top: 4, bottom: 4 })
      this.titleAccountMenuItem($r('sys.symbol.xmark'), '退出登录', true, (): void => {
        this.handleLogout();
      })
    }
    .width(this.titleAccountPanelWidth())
    .padding({ top: 6, bottom: 6 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .animation({ duration: 180, curve: Curve.EaseOut })
        .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
        .combine(TransitionEffect.translate({ y: -6 })),
      TransitionEffect.OPACITY
        .animation({ duration: 140, curve: Curve.EaseIn })
    ))
    .position({
      x: this.globalInfoModel.deviceWidth - this.titleAccountPanelWidth() - 12,
      y: this.globalInfoModel.statusBarHeight + 56 + 8
    })
  }

  /**
   * 宽屏标题动作（导航胶囊 / AI 历史快捷键）挂在页面自身的稳定节点上。
   * 此前它们挂在 HdsNavigation 标题栏 stackBuilder 里：options 变化、滚动绑定
   * 变化都会把 stackBuilder 内容整体销毁重建，反复造成滑块动画中途消失、
   * 闪现落点、高亮回弹、点击被吞。头像入口已用同一方案修复点击被吞。
   * 容器全部 hitTestBehavior(None)（自身不测试、子节点不受影响），
   * 只有真正的交互控件接收点击，其余区域透传给原生标题栏（返回键等）。
   */
  @Builder
  private wideTitleActionsOverlay() {
    if ((this.isCaregiverWideWorkspace() || this.isManagementWideWorkspace()) &&
      this.navBarVisible && !this.isResidentDetailShow) {
      Column() {
        if (this.isCaregiverWideWorkspace()) {
          this.wideCaregiverTitleActions()
        } else {
          this.wideDoctorTitleActions()
        }
      }
      .width('100%')
      .height(this.globalInfoModel.statusBarHeight + WIDE_TITLE_BAR_HEIGHT)
      .padding({ top: this.globalInfoModel.statusBarHeight })
      // 根 Stack 默认居中对齐，必须显式钉在左上角，否则覆盖层会落在屏幕中央。
      .position({ x: 0, y: 0 })
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private wideDoctorTitleActions() {
    WideDoctorTitleActions({
      selectedIndex: this.managementNavIndex,
      isDoctor: this.workspaceCode() === 'doctor',
      compactWidth: BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint),
      aiHistoryCollapsed: this.doctorAiHistoryCollapsed,
      onSelect: (index: number) => {
        this.updateManagementNav(index);
      },
      onOpenAiHistory: () => this.requestDoctorAiHistoryOpen(),
      onSearchAiHistory: () => this.requestDoctorAiHistorySearch(),
      onNewAiConversation: () => this.requestNewDoctorAiConversation(),
      onOpenAbout: () => this.pathStack.pushPath({ name: 'AboutPage' }),
      onOpenGeneral: () => this.pathStack.pushPath({ name: 'GeneralSettingsPage' }),
      onLogout: () => this.handleLogout()
    })
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
          mainTitle: this.workspaceClockTime
        },
        menu: { value: [] }
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
    if (this.isManagementWideWorkspace()) {
      const content: TitleBarContentOptions = {
        title: { mainTitle: this.workspaceClockTime },
        menu: { value: [] }
      };
      if (this.showDoctorResidentBackButton()) {
        content.backIcon = {
          label: '返回长者列表',
          icon: $r('sys.symbol.chevron_left'),
          type: IconStyleMode.SMALL,
          isEnabled: true,
          action: (): void => {
            this.doctorResidentBackRequestToken += 1;
          }
        };
      }
      return {
        padding: {
          start: LengthMetrics.vp(16),
          end: LengthMetrics.vp(16)
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false,
        content: content,
        style: this.immersiveTitleBarStyle()
      };
    }
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: this.workspaceClockTime,
        },
        menu: { value: [] },
      },
      style: this.immersiveTitleBarStyle()
    };
  }

  private navigationScrollers(): Scroller[] {
    if (!this.isWideLayout()) {
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
    if (this.isDoctorResidentWorkspace()) {
      if (!this.useCompactDoctorWorkspace()) {
        return [this.doctorResidentScrollerOwner === 'residentMaster' ?
          this.wideDoctorResidentMasterScroller : this.wideDoctorResidentDetailScroller];
      }
      return this.doctorResidentDetailVisible ?
        [this.wideDoctorResidentDetailScroller] : [this.wideDoctorResidentMasterScroller];
    }
    if (this.isDoctorAiWorkspace()) {
      return [this.wideDoctorAiChatScroller];
    }
    if (this.isManagementWideWorkspace()) {
      return [this.wideManagementScroller];
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
      // 胶囊挂在页面稳定节点上，标题栏重建不再打断补间；选中与内容同帧生效。
      this.isAiChatShow = false;
      this.caregiverNavIndex = index;
      this.updateTabSelection(index);
    } else {
      this.controller.changeIndex(index);
    }
  }

  private isRoleAdapted(): boolean {
    // The doctor and administrator roles share the same responsive shell,
    // while the wide workspace supplies role-specific labels and data views.
    // Doctors also get a compact read-only summary on phones; administrators
    // remain wide-only until their mobile operations workflow is implemented.
    return this.workspaceCode() === 'caregiver' || this.workspaceCode() === 'doctor' ||
      (this.workspaceCode() === 'admin' && this.isWideLayout());
  }

  private roleWipTitle(): string {
    if (this.workspaceCode() === 'doctor') {
      return '医师工作台';
    }
    return this.workspaceCode() === 'admin' ? '管理端' : `${this.globalInfoModel.role}端`;
  }

  private roleWipMessage(): string {
    return this.workspaceCode() === 'doctor' ? '医师端移动工作区正在适配中' : '该角色页面正在开发中，敬请期待';
  }

  private doctorElderName(elderId: number): string {
    return this.businessStore.elders.find((item: Elder) => item.id === elderId)?.name ?? '未知长者';
  }

  @Builder
  private doctorPhonePanel() {
    Column() {
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 5 }) {
            Text('医师工作台').fontSize(25).fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('查看长者健康、风险与评估进度').fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }.width('100%').alignItems(HorizontalAlign.Start)

          Row({ space: 10 }) {
            this.doctorPhoneMetric('重点风险', this.businessStore.alerts.filter((item: Alert) =>
              item.status !== 'handled' && item.status !== 'closed').length.toString(),
              $r('app.color.doctor_workspace_warning'))
            this.doctorPhoneMetric('在院长者', this.businessStore.elders.filter((item: Elder) => item.status === 2).length.toString(),
              $r('app.color.doctor_workspace_focus'))
          }.width('100%')

          Column({ space: 8 }) {
            Text('风险复核').fontSize(17).fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary')).width('100%')
            if (this.businessStore.alerts.length === 0) {
              Text('暂无待复核风险事件').fontSize(13).fontColor($r('sys.color.font_secondary'))
                .padding({ top: 24, bottom: 24 }).width('100%').textAlign(TextAlign.Center)
            } else {
              ForEach(this.businessStore.alerts.slice(-8).reverse(), (item: Alert) => {
                Row({ space: 8 }) {
                  Text(item.level === 'emergency' ? '紧急' : item.level === 'important' ? '重要' : '提示')
                    .fontSize(11).fontColor(item.level === 'emergency' ? '#FF5D6C' : '#FFB547')
                  Text(item.content).fontSize(12).layoutWeight(1).maxLines(2)
                    .fontColor($r('sys.color.font_primary'))
                }.width('100%').padding(11).borderRadius(10)
                  .backgroundColor($r('sys.color.comp_background_secondary'))
              }, (item: Alert) => `doctor-phone-alert-${item.id}`)
            }
          }.width('100%').alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('最近体征').fontSize(17).fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary')).width('100%')
            ForEach(this.businessStore.healthRecords.slice(-6).reverse(), (record: HealthRecord) => {
              Row({ space: 8 }) {
                Text(this.doctorElderName(record.elder_id)).fontSize(12).layoutWeight(1)
                  .fontColor($r('sys.color.font_primary'))
                Text(`心率 ${record.heart_rate ?? '--'} · 血氧 ${record.spo2 ?? '--'}`)
                  .fontSize(11).fontColor(record.is_abnormal ? '#FFB547' : $r('sys.color.font_secondary'))
              }.width('100%').padding(11)
                .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(10)
            }, (record: HealthRecord) => `doctor-phone-health-${record.id}`)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding({ left: 16, right: 16, top: this.globalInfoModel.statusBarHeight + 20,
          bottom: this.globalInfoModel.naviIndicatorHeight + 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private doctorPhoneMetric(label: string, value: string, color: ResourceColor) {
    Column({ space: 5 }) {
      Text(label).fontSize(12).fontColor($r('sys.color.font_secondary'))
      Text(value).fontSize(26).fontWeight(FontWeight.Bold).fontColor(color)
    }.layoutWeight(1).padding(14).borderRadius(12)
      .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  private roleWipPanel() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.hammer_fill'))
        .fontSize(56)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(this.roleWipTitle())
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text('适配中')
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_secondary'))
      Text(this.roleWipMessage())
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

  private workspaceCode(): string {
    const code: string = AuthStore.getWorkspaceCode();
    if (code === 'admin' || code === 'doctor' || code === 'caregiver') { return code; }
    return this.globalInfoModel.role === '医师' ? 'doctor' : this.globalInfoModel.role === '管理' ? 'admin' : 'caregiver';
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
    this.caregiverNavIndex = 3;
    this.isAiChatShow = true;
  }

  private closeAiChat(): void {
    this.isAiChatShow = false;
    this.caregiverNavIndex = this.wideCaregiverActiveTabIndex();
  }

  private updateAiHistoryCollapsed(collapsed: boolean): void {
    this.aiHistoryCollapsed = collapsed;
    this.preferenceManager.setValue<boolean>(CAREGIVER_AI_HISTORY_COLLAPSED_KEY, collapsed);
  }

  private updateDoctorAiHistoryCollapsed(collapsed: boolean): void {
    this.doctorAiHistoryCollapsed = collapsed;
    this.preferenceManager.setValue<boolean>(DOCTOR_AI_HISTORY_COLLAPSED_KEY, collapsed);
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

  private requestDoctorAiHistoryOpen(): void {
    this.doctorAiHistoryOpenRequestToken += 1;
  }

  private requestDoctorAiHistorySearch(): void {
    this.doctorAiHistorySearchRequestToken += 1;
  }

  private requestNewDoctorAiConversation(): void {
    this.doctorAiNewConversationRequestToken += 1;
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
    return this.isWideLayout() && this.workspaceCode() === 'caregiver';
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
    if (this.showDoctorResidentBackButton()) {
      this.doctorResidentBackRequestToken += 1;
      return true;
    }
    if (this.isCaregiverWideWorkspace() && this.pathStack.size() === 0 && this.caregiverHasLocalBackLayer) {
      this.caregiverBackRequestToken += 1;
      return true;
    }
    if (this.pathStack.size() > 0) {
      this.pathStack.pop();
      return true;
    }
    if (this.isManagementWideWorkspace() && this.managementNavIndex === 0 && this.adminHasLocalNavLayer) {
      this.adminBackRequestToken += 1;
      return true;
    }
    if (this.isManagementWideWorkspace() && this.managementNavIndex !== 0) {
      this.updateManagementNav(0);
      return true;
    }
    if (this.currentTabIndex !== 0) {
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

  // ==================== 平板 / PC 共用工作台 ====================

  @Builder
  private wideCaregiverTitleActions() {
    WideCaregiverTitleActions({
      // 必须传立即索引而不是 currentTabIndex：让胶囊高亮与滑块在点按同帧即
      // 反映最新选中，不等内容索引追上。
      currentTabIndex: this.caregiverTitleNavIndex(),
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
    if (this.workspaceCode() === 'admin' || this.workspaceCode() === 'doctor') {
      if (this.isDoctorResidentWorkspace()) {
        WideDoctorResidentPage({
          compactWidth: this.useCompactDoctorWorkspace(),
          topBarHeight: this.wideDoctorTopBarHeight(),
          masterScroller: this.wideDoctorResidentMasterScroller,
          detailScroller: this.wideDoctorResidentDetailScroller,
          naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
          backRequestToken: this.doctorResidentBackRequestToken,
          selectedResidentId: this.doctorSelectedResidentId,
          onSelectResident: (id: string) => {
            this.doctorSelectedResidentId = id;
          },
          onLocalDetailVisibilityChange: (visible: boolean) => {
            this.doctorResidentDetailVisible = visible;
          },
          onMasterScrollerActive: () => {
            this.doctorResidentScrollerOwner = 'residentMaster';
          },
          onDetailScrollerActive: () => {
            this.doctorResidentScrollerOwner = 'residentDetail';
          }
        })
      } else if (this.isDoctorAiWorkspace()) {
        WideDoctorAiPage({
          doctorWideImmersive: false,
          embeddedDoctorWide: true,
          embeddedListScroller: this.wideDoctorAiChatScroller,
          historyCollapsed: this.doctorAiHistoryCollapsed,
          historyOpenRequestToken: this.doctorAiHistoryOpenRequestToken,
          historySearchRequestToken: this.doctorAiHistorySearchRequestToken,
          newConversationRequestToken: this.doctorAiNewConversationRequestToken,
          onHistoryCollapsedChange: (collapsed: boolean) => {
            this.updateDoctorAiHistoryCollapsed(collapsed);
          },
          onClose: () => {
            this.updateManagementNav(0);
          }
        })
      } else {
        // The shared management tree keeps doctor and administrator modules
        // aligned while server permissions remain the authorization boundary.
        WideAdminWorkspace({
          statusBarHeight: this.globalInfoModel.statusBarHeight,
          naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
          compactWidth: BreakpointUtil.isTablet(this.globalInfoModel.widthBreakpoint),
          managementScroller: this.wideManagementScroller,
          managementNavIndex: this.managementNavIndex,
          adminBackRequestToken: this.adminBackRequestToken,
          onLocalNavLayerChange: (hasLayer: boolean) => {
            this.adminHasLocalNavLayer = hasLayer;
          },
          onOpenQuickFunction: (moduleId: string) => {
            const routeName: string = doctorQuickRouteName(moduleId);
            if (routeName.length > 0) {
              this.pathStack.pushPath({ name: routeName });
            }
          },
          onManagementNavSelect: (index: number) => {
            this.updateManagementNav(index);
          },
          canHandleAlerts: AuthStore.hasPermission('alert:handle'),
          isDoctor: this.workspaceCode() === 'doctor',
          onOpenAbout: () => {
            this.pathStack.pushPath({ name: 'AboutPage' });
          },
          onOpenGeneral: () => {
            this.pathStack.pushPath({ name: 'GeneralSettingsPage' });
          },
          onOpenAdmission: () => {
            this.pathStack.pushPath({ name: 'AdmissionPage' });
          },
          onLogout: () => {
            this.handleLogout();
          }
        })
      }
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
          historyCollapsed: this.aiHistoryCollapsed,
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
      MineDetailPage({
        pageType: 'about',
        onOpenArticle: (id: string) => {
          this.pathStack.pushPath({ name: 'AboutArticlePage', param: id });
        }
      })
    } else if (name === 'AboutArticlePage') {
      MineDetailPage({
        pageType: 'article',
        articleId: (param as string) ?? '',
        onOpenArticle: (id: string) => {
          this.pathStack.pushPath({ name: 'AboutArticlePage', param: id });
        }
      })
    } else if (name === 'GeneralSettingsPage') {
      MineDetailPage({ pageType: 'general' })
    } else if (name === 'AdmissionPage') {
      WideDoctorAdmissionForm({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        },
        onStartAssessment: (session: AssessmentAgentSession) => {
          this.pathStack.replacePath({ name: 'AssessmentAgentPage', param: session });
        }
      })
    } else if (name === 'AssessmentAgentPage') {
      WideAssessmentAgentPage({
        session: param as AssessmentAgentSession,
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        },
        onViewReport: (assessmentId: number) => {
          this.pathStack.replacePath({ name: 'AssessmentReportPage', param: assessmentId });
        }
      })
    } else if (name === 'AssessmentReportPage') {
      WideAssessmentReportPage({
        assessmentId: param as number,
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => { this.pathStack.pop(); }
      })
    } else if (name === 'DoctorBedsPage') {
      WideDoctorBedsPage({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        }
      })
    } else if (name === 'DoctorTasksPage') {
      WideDoctorTasksPage({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        }
      })
    } else if (name === 'DoctorAlertsPage') {
      WideDoctorAlertsPage({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        }
      })
    } else if (name === 'DoctorCasesPage') {
      WideDoctorCasesPage({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        },
        onStartAssessment: (session: AssessmentAgentSession) => {
          this.pathStack.pushPath({ name: 'AssessmentAgentPage', param: session });
        }
      })
    } else if (name === 'DoctorAssessmentsPage') {
      WideDoctorAssessmentsPage({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        },
        onOpenReport: (assessmentId: number) => {
          this.pathStack.pushPath({ name: 'AssessmentReportPage', param: assessmentId });
        }
      })
    } else if (name === 'DoctorBillsPage') {
      WideDoctorBillsPage({
        compactWidth: this.useCompactDoctorWorkspace(),
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight,
        onClose: () => {
          this.pathStack.pop();
        }
      })
    } else if (name === 'KnowledgeCreatePage') {
      WideKnowledgeCreatePage({
        files: (param as KBCreatePageParam).files,
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight
      })
    } else if (name === 'RagDocumentsPage') {
      WideRagDocumentsPage({
        datasetId: (param as RagDocsPageParam).datasetId,
        datasetName: (param as RagDocsPageParam).datasetName,
        statusBarHeight: this.globalInfoModel.statusBarHeight,
        naviIndicatorHeight: this.globalInfoModel.naviIndicatorHeight
      })
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
          } else if (this.workspaceCode() === 'doctor') {
            this.doctorPhonePanel()
          } else {
            this.phoneTabs()
          }
        }
        .mode(NavigationMode.Stack)
        .navDestination(this.destinationBuilder)
        .titleBar(this.navigationTitleBarOptions())
        .bindToScrollable(this.navigationScrollers())
        .hideBackButton(!this.showCaregiverLocalBackButton())
        .hideTitleBar(this.isWideLayout() && !this.isCaregiverWideWorkspace() && !this.isManagementWideWorkspace(), true)
        .titleMode(HdsNavigationTitleMode.MINI)
        .onNavBarStateChange((visible: boolean) => {
          this.navBarVisible = visible;
        })
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

      this.wideTitleActionsOverlay()
      this.titleAccountMenuAnchor()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

