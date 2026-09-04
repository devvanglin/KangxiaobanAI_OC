import { KeyCode } from '@kit.InputKit';
import ApiClient from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Bed, CareTask, Elder, HealthRecord, Room, Schedule } from '../../network/Dto';
import { WideRoleManagement } from './WideRoleManagement';
import { WideUserManagement } from './WideUserManagement';
import { WideAreaManagement } from './WideAreaManagement';
import { WideCarePackageManagement } from './WideCarePackageManagement';
import { WideModelManagement } from './WideModelManagement';
import { WideDeviceManagement } from './WideDeviceManagement';
import { WideDoctorCharts } from './WideDoctorCharts';
import { WideDoctorSchedule } from './WideDoctorSchedule';
import { WideDoctorQuickPanel } from './WideDoctorQuickPanel';

interface AdminNavItem {
  id: string;
  label: string;
  symbol: Resource;
  badge?: string;
}

interface AdminMetric {
  label: string;
  value: string;
  note: string;
  symbol: Resource;
  tone: string;
}

interface AdminEvent {
  id: string;
  alertId: number;
  title: string;
  detail: string;
  owner: string;
  time: string;
  status: string;
  tone: string;
}

interface DoctorQuickFunction {
  id: string;
  label: string;
  symbol: Resource;
  tone: string;
  target: string;
}

interface AdminOccupancy {
  id: string;
  label: string;
  used: number;
  total: number;
  percent: number;
}

interface AlertHandleRequest {
  note?: string;
}

const WIDE_TITLE_BAR_HEIGHT: number = 56;

@ComponentV2
export struct WideAdminWorkspace {
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  // The doctor console reuses this exact visual surface but does not have
  // admin:all/task:write permission to mutate alert state.  Keep the action
  // affordance in the shared layout while allowing the caller to make it
  // read-only without forking the UI.
  @Param canHandleAlerts: boolean = true;
  @Param isDoctor: boolean = false;
  @Param managementScroller: Scroller = new Scroller();
  @Param managementNavIndex: number = 0;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onOpenAdmission: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Event onManagementNavSelect: (index: number) => void = (_index: number) => {};
  @Local selectedNavId: string = 'overview';
  @Local isSidebarCollapsed: boolean = false;
  @Local selectedPeriod: number = 0;
  @Local hoveredId: string = '';
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  // The store is shared across mounted roots. Keep a component-owned signal
  // so the first workbench render is invalidated when the initial snapshot
  // completes, even when this component appeared after the request started.
  @Local coreLoadReady: boolean = false;
  @Local metricSnapshot: AdminMetric[] = [];
  @Local metricSnapshotVersion: number = 0;
  @Local chartEldersSnapshot: Elder[] = [];
  @Local chartHealthSnapshot: HealthRecord[] = [];
  @Local dashboardHeight: number = 0;
  @Local metricsHeight: number = 0;
  @Local doctorQuickModule: string = '';

  private navItemsForRole(): AdminNavItem[] {
    if (this.isDoctor) {
      return [
        { id: 'overview', label: '临床工作台', symbol: $r('sys.symbol.square_grid_2x2') },
        { id: 'residents', label: '长者档案', symbol: $r('sys.symbol.person_2_fill') },
        { id: 'ai', label: '康小伴 AI', symbol: $r('sys.symbol.AI_model') }
      ];
    }
    return [
      { id: 'overview', label: '总览', symbol: $r('sys.symbol.square_grid_2x2') },
      { id: 'roles', label: '角色管理', symbol: $r('sys.symbol.key_shield_badge_person_crop_circle_fill') },
      { id: 'users', label: '用户', symbol: $r('sys.symbol.person_crop_circle_fill') },
      { id: 'areas', label: '区域', symbol: $r('sys.symbol.square_grid_2x2') },
      { id: 'plans', label: '计划', symbol: $r('sys.symbol.calendar_badge_clock') },
      { id: 'models', label: '大模型', symbol: $r('sys.symbol.AI_model') },
      { id: 'assets', label: '设备', symbol: $r('sys.symbol.beacon_tower_fill') }
    ];
  }

  @Monitor('managementNavIndex')
  onManagementNavIndexChange(): void {
    const ids: string[] = this.isDoctor ?
      ['overview', 'residents', 'ai'] :
      ['overview', 'roles', 'users', 'areas', 'plans', 'models', 'assets'];
    if (this.managementNavIndex >= 0 && this.managementNavIndex < ids.length) {
      this.selectedNavId = ids[this.managementNavIndex];
      setTimeout((): void => { this.managementScroller.scrollEdge(Edge.Top); }, 0);
    }
  }

  @Monitor('businessStore.coreVersion', 'businessStore.loaded')
  onBusinessDataChange(): void {
    this.coreLoadReady = this.businessStore.loaded;
    this.refreshMetricSnapshot();
  }

  private async awaitCoreLoad(): Promise<void> {
    await this.businessStore.load();
    this.coreLoadReady = this.businessStore.loaded;
    this.refreshMetricSnapshot();
  }

  aboutToAppear(): void {
    this.onManagementNavIndexChange();
    this.coreLoadReady = this.businessStore.loaded;
    this.refreshMetricSnapshot();
    void this.awaitCoreLoad();
  }

  private isDataLoading(): boolean {
    return !this.coreLoadReady && !this.businessStore.loaded;
  }

  private currentDateValue(): string {
    const now: Date = new Date();
    return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${
      now.getDate().toString().padStart(2, '0')}`;
  }

  private metrics(): AdminMetric[] {
    // Keep this computed node tied to the component-owned completion signal.
    // The shared store can finish before a nested builder has registered its
    // field reads; the scalar guarantees a fresh metric calculation.
    const beds: Bed[] = this.coreLoadReady ? this.businessStore.beds : [];
    const elders: Elder[] = this.coreLoadReady ? this.businessStore.elders : [];
    const tasks: CareTask[] = this.coreLoadReady ? this.businessStore.tasks : [];
    const alerts: Alert[] = this.coreLoadReady ? this.businessStore.alerts : [];
    const schedules: Schedule[] = this.coreLoadReady ? this.businessStore.schedules : [];
    const totalBeds: number = beds.length;
    const occupiedBeds: number = beds.filter((item: Bed) => item.status === 'occupied').length;
    const occupancy: number = totalBeds > 0 ? Math.round(occupiedBeds / totalBeds * 1000) / 10 : 0;
    const todaySchedules: number = schedules.filter((item: Schedule) =>
      item.work_date === this.currentDateValue()).length;
    const totalTasks: number = tasks.length;
    const doneTasks: number = tasks.filter((item) => item.status === 'done').length;
    const completion: number = totalTasks > 0 ? Math.round(doneTasks / totalTasks * 1000) / 10 : 0;
    const openAlerts: Alert[] = alerts.filter((item: Alert) =>
      item.status !== 'handled' && item.status !== 'closed');
    const emergencyAlerts: number = openAlerts.filter((item: Alert) => item.level === 'emergency').length;
    if (this.isDoctor) {
      const focusElders: number = elders.filter((elder) =>
        openAlerts.some((alert: Alert) => alert.elder_id === elder.id)).length;
      const activeElders = elders.filter((item) => item.status === 2);
      const remainingBeds: number = beds.filter((item: Bed) => item.status === 'free').length;
      return [
        { label: '在住老人', value: activeElders.length.toString(), note: `当前在院 ${activeElders.length} 位`,
          symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
        { label: '剩余床位', value: remainingBeds.toString(), note: `共 ${beds.length} 张床位`,
          symbol: $r('sys.symbol.bed_double_fill'), tone: 'success' },
        { label: '重点关注', value: focusElders.toString(), note: '存在未闭环风险的老人',
          symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
        { label: '预警', value: openAlerts.length.toString(), note: `${emergencyAlerts} 项紧急预警`,
          symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger' },
      ];
    }
    return [
      { label: '在院长者', value: elders.filter((item) => item.status === 2).length.toString(),
        note: `床位使用率 ${occupancy}%`, symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
      { label: '今日排班', value: todaySchedules.toString(), note: '来自服务器排班记录',
        symbol: $r('sys.symbol.person_crop_circle_fill'), tone: 'warning' },
      { label: '任务完成率', value: `${completion}%`, note: `${doneTasks}/${totalTasks} 项已完成`,
        symbol: $r('sys.symbol.checkmark_circle_fill'), tone: 'success' },
      { label: '待闭环风险', value: openAlerts.length.toString(), note: `${emergencyAlerts} 项紧急告警`,
        symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger' }
    ];
  }

  private refreshMetricSnapshot(): void {
    this.metricSnapshotVersion += 1;
    // Pass a component-owned array to the imperative chart. Reading the
    // shared store directly from a nested Canvas builder can miss the first
    // V2 invalidation when the store commits its snapshot off-screen.
    this.chartEldersSnapshot = this.coreLoadReady ? this.businessStore.elders.slice() : [];
    this.chartHealthSnapshot = this.coreLoadReady ? this.businessStore.healthRecords.slice() : [];
    this.metricSnapshot = this.metrics();
  }

  @Builder
  private metricsGrid(coreReady: boolean) {
    GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
      ForEach(this.metricSnapshot, (metric: AdminMetric) => {
        GridCol({ span: this.compactWidth ? 6 : 3 }) { this.metricCard(metric) }
      }, (metric: AdminMetric) => `${metric.label}-${coreReady ? 'ready' : 'loading'}-${this.metricSnapshotVersion}`)
    }.width('100%')
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.updateMetricsHeight(newValue.height);
      })
  }

  private events(): AdminEvent[] {
    const alerts: Alert[] = this.coreLoadReady ? this.businessStore.alerts : [];
    return alerts.map((item: Alert): AdminEvent => ({
      id: `alert-${item.id}`,
      alertId: item.id,
      title: item.type || '风险告警',
      detail: item.content,
      owner: item.handled_by || '未分配',
      time: item.create_time.length >= 16 ? item.create_time.slice(11, 16) : '--',
      status: this.isDoctor ? (item.status === 'closed' ? '已复核' : item.status === 'handled' ? '复核中' : '待复核') :
        (item.status === 'closed' ? '已闭环' : item.status === 'handled' ? '跟进中' : '待处理'),
      tone: item.level === 'emergency' ? 'danger' : item.level === 'important' ? 'warning' : 'neutral'
    }));
  }

  private occupancyRows(): AdminOccupancy[] {
    const rows: AdminOccupancy[] = [];
    if (!this.coreLoadReady) {
      return rows;
    }
    for (let index: number = 0; index < this.businessStore.rooms.length; index++) {
      const room: Room = this.businessStore.rooms[index];
      const beds: Bed[] = this.businessStore.beds.filter((item: Bed) => item.room_id === room.id);
      if (beds.length === 0) {
        continue;
      }
      const used: number = beds.filter((item: Bed) => item.status === 'occupied').length;
      rows.push({ id: `room-${room.id}`, label: `${room.building}${room.floor}F-${room.room_no}`,
        used: used, total: beds.length, percent: Math.round(used / beds.length * 100) });
    }
    return rows;
  }

  private async handleAlert(item: AdminEvent): Promise<void> {
    if (!this.canHandleAlerts) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '当前账号没有告警处置权限' });
      } catch (_error) {
        // The permission boundary is still enforced if the prompt service is unavailable.
      }
      return;
    }
    try {
      const request: AlertHandleRequest = {};
      const response = await ApiClient.patch<Object>(`/alerts/${item.alertId}/handle?close=0`, request);
      if (response.code === 0) {
        await this.businessStore.load(true);
      }
    } catch (_error) {
    }
  }

  private sidebarWidth(): number {
    if (this.isSidebarCollapsed) {
      return 72;
    }
    return this.compactWidth ? 220 : 248;
  }

  private contentTopPadding(): number {
    return WIDE_TITLE_BAR_HEIGHT + this.statusBarHeight + 20;
  }

  /**
   * Keep only the live gesture/navigation inset below the dashboard cards.
   * The dashboard already owns a full-height scroll viewport, so an extra
   * decorative bottom margin would leave an avoidable strip below both cards.
   * A small fallback keeps the cards from touching the edge on devices that
   * report no navigation indicator area.
   */
  private dashboardBottomPadding(): number {
    return Math.max(12, this.naviIndicatorHeight);
  }

  private lengthValue(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return parseFloat(value);
    }
    return 0;
  }

  private lowerRowHeight(): number {
    if (this.dashboardHeight <= 0 || this.metricsHeight <= 0) {
      return 500;
    }
    const bottomInset: number = this.dashboardBottomPadding();
    const errorInset: number = this.businessStore.error.length > 0 ? 48 : 0;
    const measured: number = this.dashboardHeight - this.contentTopPadding() -
      this.metricsHeight - 20 - bottomInset - errorInset;
    return Math.max(320, measured);
  }

  private updateDashboardHeight(value: Length): void {
    const next: number = this.lengthValue(value);
    if (next > 0 && Math.abs(next - this.dashboardHeight) > 0.5) {
      this.dashboardHeight = next;
    }
  }

  private updateMetricsHeight(value: Length): void {
    const next: number = this.lengthValue(value);
    if (next > 0 && Math.abs(next - this.metricsHeight) > 0.5) {
      this.metricsHeight = next;
    }
  }

  private toneColor(tone: string): ResourceColor {
    if (tone === 'danger') return $r('app.color.doctor_workspace_danger');
    if (tone === 'warning') return $r('app.color.doctor_workspace_warning');
    if (tone === 'success') return $r('app.color.doctor_workspace_success');
    if (tone === 'focus') return $r('app.color.doctor_workspace_focus');
    return $r('app.color.doctor_workspace_text_secondary');
  }

  private isOccupancyWarning(percent: number): boolean {
    const threshold: number = this.businessStore.operationPolicy.occupancy_warning_percent;
    return threshold > 0 && percent >= threshold;
  }

  private title(): string {
    return this.navItemsForRole().find((item: AdminNavItem) => item.id === this.selectedNavId)?.label ??
      (this.isDoctor ? '临床工作台' : '总览');
  }

  private workspaceTitle(): string {
    return this.isDoctor ? '医师工作台' : '总览';
  }

  private workspaceSubtitle(): string {
    return this.isDoctor ? '围绕长者档案与康小伴 AI 开展今日工作' :
      '掌握机构运营、床位使用与实时风险';
  }

  private doctorQuickFunctions(): DoctorQuickFunction[] {
    return [
      { id: 'admission', label: '办理入住', symbol: $r('sys.symbol.person_badge_plus'), tone: 'focus', target: 'overview' },
      { id: 'beds', label: '床位预览', symbol: $r('sys.symbol.bed_double_fill'), tone: 'success', target: 'residents' },
      { id: 'tasks', label: '护理任务', symbol: $r('sys.symbol.checkmark_circle_fill'), tone: 'warning', target: 'overview' },
      { id: 'alerts', label: '告警处理', symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger', target: 'overview' },
      { id: 'assessment', label: '健康评估', symbol: $r('sys.symbol.heart_fill'), tone: 'focus', target: 'residents' },
      { id: 'billing', label: '账单管理', symbol: $r('sys.symbol.doc_text'), tone: 'success', target: 'residents' },
      { id: 'schedule', label: '日常总览', symbol: $r('sys.symbol.calendar_badge_clock'), tone: 'focus', target: 'overview' }
    ];
  }

  private openDoctorQuickFunction(item: DoctorQuickFunction): void {
    if (this.isDoctor && item.id === 'admission') {
      this.onOpenAdmission();
      return;
    }
    const ids: string[] = ['overview', 'residents', 'ai'];
    const index: number = ids.indexOf(item.target);
    if (this.isDoctor) {
      this.doctorQuickModule = item.id;
      this.selectedNavId = 'overview';
      return;
    }
    this.selectedNavId = index >= 0 ? item.target : 'overview';
    if (index >= 0) {
      this.onManagementNavSelect(index);
    } else {
      try { this.getUIContext().getPromptAction().showToast({ message: `${item.label}将在对应业务模块中展开` }); } catch (_error) {}
    }
  }

  private activate(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down && (event.keyCode === KeyCode.KEYCODE_ENTER ||
      event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  private navIndex(itemId: string): number {
    const items: AdminNavItem[] = this.navItemsForRole();
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].id === itemId) {
        return index;
      }
    }
    return -1;
  }

  private selectNavItem(item: AdminNavItem): void {
    this.doctorQuickModule = '';
    this.selectedNavId = item.id;
    const index: number = this.navIndex(item.id);
    if (index >= 0) {
      this.onManagementNavSelect(index);
    }
  }

  @Builder
  private navItem(item: AdminNavItem) {
    Row({ space: 12 }) {
      SymbolGlyph(item.symbol)
        .fontSize(19)
        .fontColor([this.selectedNavId === item.id ?
          $r('app.color.doctor_workspace_accent') : $r('app.color.doctor_workspace_text_secondary')])
      if (!this.isSidebarCollapsed) {
        Text(item.label)
          .layoutWeight(1)
          .fontSize(13)
          .fontWeight(this.selectedNavId === item.id ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .maxLines(1)
        if (item.badge) {
          Text(item.badge)
            .fontSize(10)
            .fontColor(this.selectedNavId === item.id ? $r('app.color.doctor_workspace_accent') :
              $r('app.color.doctor_workspace_text_secondary'))
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
        }
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: this.isSidebarCollapsed ? 14 : 14, right: 12 })
    .borderRadius(12)
    .backgroundColor(this.selectedNavId === item.id ? $r('app.color.doctor_workspace_accent_soft') :
      (this.hoveredId === item.id ? $r('app.color.doctor_workspace_surface_hover') : Color.Transparent))
    .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .accessibilityText(item.label)
    .onHover((hover: boolean) => this.hoveredId = hover ? item.id : '')
    .onKeyEvent((event: KeyEvent) => this.activate(event, () => this.selectNavItem(item)))
    .onClick(() => this.selectNavItem(item))
  }

  @Builder
  private sidebar() {
    Column() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.building_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.doctor_workspace_accent')])
        if (!this.isSidebarCollapsed) {
          Column({ space: 2 }) {
            Text(this.isDoctor ? '医师工作台' : '机构管理端')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text(this.isDoctor ? '长者健康评估与照护协作' : '康小伴养老养护平台')
              .fontSize(9)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          }.alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .height(64)
      .padding({ left: this.isSidebarCollapsed ? 25 : 18 })
      .alignItems(VerticalAlign.Center)
      Column({ space: 6 }) {
        ForEach(this.navItemsForRole(), (item: AdminNavItem) => this.navItem(item), (item: AdminNavItem) => item.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 10, right: 10, top: 12 })
      Column({ space: 6 }) {
        if (!this.isSidebarCollapsed) {
          Button('系统设置')
            .width('100%').height(36).fontSize(11).borderRadius(10)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .backgroundColor(Color.Transparent).onClick(() => this.onOpenGeneral())
          Button('退出登录')
            .width('100%').height(36).fontSize(11).borderRadius(10)
            .fontColor($r('app.color.doctor_workspace_danger'))
            .backgroundColor(Color.Transparent).onClick(() => this.onLogout())
        }
        Button() {
          SymbolGlyph(this.isSidebarCollapsed ? $r('sys.symbol.open_sidebar') : $r('sys.symbol.close_sidebar'))
            .fontSize(18).fontColor([$r('app.color.doctor_workspace_text_secondary')])
        }
        .width('100%').height(38).borderRadius(10)
        .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
        .accessibilityText(this.isSidebarCollapsed ? '展开侧栏' : '收起侧栏')
        .onClick(() => this.isSidebarCollapsed = !this.isSidebarCollapsed)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 10 + this.naviIndicatorHeight })
    }
    .width(this.sidebarWidth())
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: { right: 0.5 }, color: { right: $r('app.color.doctor_workspace_border_soft') } })
  }

  @Builder
  private metricCard(metric: AdminMetric) {
    Column({ space: this.isDoctor ? 6 : 8 }) {
      if (!this.isDoctor) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).borderRadius(10).backgroundColor($r('app.color.doctor_workspace_surface_hover'))
            SymbolGlyph(metric.symbol).fontSize(17).fontColor([this.toneColor(metric.tone)])
          }
          Blank()
          Text('实时').fontSize(9).fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.width('100%')
      }
      Text(metric.label).fontSize(this.isDoctor ? 16 : 12)
        .fontColor($r('app.color.doctor_workspace_text_secondary')).width('100%')
      Text(metric.value).fontSize(this.isDoctor ? 40 : 30).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary')).width('100%')
      if (!this.isDoctor) {
        Text(metric.note).fontSize(13).fontColor(this.toneColor(metric.tone)).width('100%')
      }
    }
    .width('100%').height(this.isDoctor ? 108 : 144).padding(16).borderRadius(14)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(this.isDoctor ? FlexAlign.Center : FlexAlign.Start)
  }

  @Builder
  private eventRow(item: AdminEvent) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(item.title).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary')).maxLines(1).width('100%')
        Text(item.detail).fontSize(10).fontColor($r('app.color.doctor_workspace_text_secondary'))
          .maxLines(1).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) {
        Text(item.status).fontSize(10).fontColor(this.toneColor(item.tone))
        Text(`${item.owner} · ${item.time}`).fontSize(9).fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.alignItems(HorizontalAlign.End)
      Button(this.isDoctor ? '仅供查看' :
        (item.status === '已闭环' || item.status === '跟进中' ? item.status : '标记跟进'))
        .height(32).fontSize(10).borderRadius(9)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
        // Keep the visual affordance identical across roles. Doctor clicks
        // are handled by the guarded method above and never reach the admin
        // mutation endpoint.
        .enabled(this.isDoctor ? true : item.status !== '已闭环' && item.status !== '跟进中')
        .onClick(() => this.handleAlert(item))
    }
    .width('100%').height(68).padding({ left: 14, right: 12 })
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('app.color.doctor_workspace_border_soft') } })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private occupancyPanel() {
    Column({ space: 16 }) {
      Row() {
        Text(this.isDoctor ? '照护区域入住情况' : '区域床位使用').fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text(this.isDoctor ? `共 ${this.businessStore.elders.filter((item) => item.status === 2).length} 位` :
          `共 ${this.businessStore.beds.length} 张`).fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      if (this.occupancyRows().length === 0) {
        Text(this.isDataLoading() ? (this.isDoctor ? '正在加载长者入住数据' : '正在加载床位数据') :
          (this.isDoctor ? '暂无长者入住数据' : '暂无床位数据'))
          .width('100%')
          .padding({ top: 48, bottom: 48 })
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.occupancyRows(), (row: AdminOccupancy) => {
          this.progressRow(row.label, row.used, row.total, row.percent)
        }, (row: AdminOccupancy) => row.id)
      }
    }
    .width('100%').constraintSize({ minHeight: 258 }).padding(18).borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private doctorQuickFunctionButton(item: DoctorQuickFunction) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        // Keep quick-action symbols in the system's adaptive monochrome icon color.
        SymbolGlyph(item.symbol).fontSize(20).fontColor([$r('sys.color.icon_primary')])
        Text(item.label).fontSize(14).fontColor($r('app.color.doctor_workspace_text_primary'))
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 10 })
    .borderRadius(12)
    .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
    .accessibilityText(item.label)
    .onClick(() => this.openDoctorQuickFunction(item))
  }

  @Builder
  private commonFunctionsPanel() {
    Column({ space: 14 }) {
      Row() {
        Text('常用功能').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text('快速进入').fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      GridRow({ columns: 12, gutter: { x: 10, y: 10 } }) {
        ForEach(this.doctorQuickFunctions(), (item: DoctorQuickFunction) => {
          GridCol({ span: 6 }) {
            this.doctorQuickFunctionButton(item)
          }
        }, (item: DoctorQuickFunction) => item.id)
      }.width('100%')
    }
    .width('100%')
    .padding(18)
    .constraintSize({ minHeight: this.compactWidth ? 0 : 250 })
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private progressRow(label: string, used: number, total: number, percent: number) {
    Column({ space: 7 }) {
      Row() {
        Text(label).fontSize(11).fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text(`${used}/${total} · ${percent}%`).fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
      }.width('100%')
      if (!this.isDoctor) {
        Progress({ value: percent, total: 100, type: ProgressType.Linear })
          .width('100%').height(6).color(this.isOccupancyWarning(percent) ? $r('app.color.doctor_workspace_warning') :
            $r('app.color.doctor_workspace_focus')).backgroundColor($r('app.color.doctor_workspace_surface_hover'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dashboard() {
    Stack() {
      Scroll(this.managementScroller) {
      Column({ space: 20 }) {
        if (!this.isDoctor) {
          Row() {
            Column({ space: 5 }) {
              Text(this.workspaceTitle()).fontSize(this.compactWidth ? 26 : 30).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
              Text(this.workspaceSubtitle()).fontSize(11)
                .fontColor($r('app.color.doctor_workspace_text_secondary'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('实时数据')
              .fontSize(10)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .borderRadius(10)
              .backgroundColor($r('app.color.doctor_workspace_surface'))
          }.width('100%').alignItems(VerticalAlign.Center)
        }
        if (this.businessStore.error.length > 0) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.info_circle')).fontSize(15)
              .fontColor([$r('app.color.doctor_workspace_warning')])
            Text('部分数据暂未同步，请检查网络后重试').fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
            .accessibilityText('部分数据暂未同步，请检查网络后重试')
        }
        this.metricsGrid(this.coreLoadReady)
        GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
          GridCol({ span: this.compactWidth ? 12 : 5 }) {
            if (this.isDoctor) {
              Column({ space: 16 }) {
                this.commonFunctionsPanel()
                WideDoctorSchedule({
                  elders: this.businessStore.elders,
                  beds: this.businessStore.beds,
                  rooms: this.businessStore.rooms,
                  tasks: this.businessStore.tasks,
                  schedules: this.businessStore.schedules,
                  loading: this.isDataLoading(),
                  compactWidth: this.compactWidth
                })
                .layoutWeight(1)
              }.width('100%').height(this.compactWidth ? 'auto' : '100%')
                .alignItems(HorizontalAlign.Start)
            } else {
              this.occupancyPanel()
            }
          }.height(this.compactWidth ? 'auto' : '100%')
          GridCol({ span: this.compactWidth ? 12 : 7 }) {
            if (this.isDoctor) {
              WideDoctorCharts({
                elders: this.chartEldersSnapshot,
                healthRecords: this.chartHealthSnapshot,
                dataVersion: this.metricSnapshotVersion,
                compactWidth: this.compactWidth
              })
              .height(this.compactWidth ? 'auto' : '100%')
            } else {
              Column() {
                Row() {
                  Text('今日运营关注').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.doctor_workspace_text_primary'))
                  Blank()
                  Text(`${this.events().length} 项`).fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
                }.width('100%').height(52).padding({ left: 16, right: 16 })
                if (this.events().length === 0) {
                  Text(this.isDataLoading() ? '正在加载告警数据' : '暂无运营关注事项')
                    .width('100%')
                    .padding({ top: 56, bottom: 56 })
                    .fontSize(11)
                    .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                    .textAlign(TextAlign.Center)
                } else {
                  ForEach(this.events(), (item: AdminEvent) => this.eventRow(item), (item: AdminEvent) => item.id)
                }
              }.width('100%').borderRadius(16).backgroundColor($r('app.color.doctor_workspace_surface'))
                .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            }
          }.height(this.compactWidth ? 'auto' : '100%')
        }
        .width('100%')
        // The compact layout stacks the two columns and must keep intrinsic
        // heights.  Only the wide layout receives the measured remainder.
        .height(this.compactWidth ? 'auto' : this.lowerRowHeight())
        .constraintSize({ minHeight: this.compactWidth ? 0 : this.lowerRowHeight() })
      }
      .width('100%').padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: this.dashboardBottomPadding() }).alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.doctor_workspace_background'))
    // Measure the viewport wrapper, not the Scroll content. Measuring the
    // content creates a feedback loop and leaves the bottom of the workbench
    // unused when the cards are sized from their own intrinsic height.
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateDashboardHeight(newValue.height);
    })
  }

  @Builder
  private modulePlaceholder() {
    Column({ space: 14 }) {
      SymbolGlyph(this.navItemsForRole().find((item: AdminNavItem) => item.id === this.selectedNavId)?.symbol ??
        $r('sys.symbol.square_grid_2x2'))
        .fontSize(42).fontColor([$r('app.color.doctor_workspace_accent')])
      Text(this.title()).fontSize(26).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(this.isDoctor ? '该医师工作模块尚未开放服务器业务接口。' : '该模块尚未开放业务接口。')
        .fontSize(12).fontColor($r('app.color.doctor_workspace_text_secondary'))
      Button(this.isDoctor ? '返回医师工作台' : '返回总览').height(40).borderRadius(12).fontSize(12)
        .fontColor($r('app.color.doctor_workspace_background'))
        .backgroundColor($r('app.color.doctor_workspace_text_primary'))
        .onClick(() => this.selectedNavId = 'overview')
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private workspaceContent() {
    Column() {
      if (this.selectedNavId === 'overview') {
        if (this.isDoctor) {
          if (this.doctorQuickModule.length > 0) {
            WideDoctorQuickPanel({ kind: this.doctorQuickModule, compactWidth: this.compactWidth, onBack: () => this.doctorQuickModule = '' })
          } else {
            this.dashboard()
          }
        } else {
          this.dashboard()
        }
      } else if (!this.isDoctor && this.selectedNavId === 'roles') {
        WideRoleManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight
        })
      } else if (!this.isDoctor && this.selectedNavId === 'users') {
        WideUserManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight
        })
      } else if (!this.isDoctor && this.selectedNavId === 'areas') {
        WideAreaManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight,
          managementScroller: this.managementScroller
        })
      } else if (!this.isDoctor && this.selectedNavId === 'plans') {
        WideCarePackageManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight
        })
      } else if (!this.isDoctor && this.selectedNavId === 'models') {
        WideModelManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight
        })
      } else if (!this.isDoctor && this.selectedNavId === 'assets') {
        WideDeviceManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight,
          managementScroller: this.managementScroller
        })
      } else if (this.isDoctor) {
        this.modulePlaceholder()
      } else {
        this.modulePlaceholder()
      }
    }
    .layoutWeight(1)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.doctor_workspace_background'))
  }

  build() {
    this.workspaceContent()
  }
}
