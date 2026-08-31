import { KeyCode } from '@kit.InputKit';
import ApiClient from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Bed, CareTask, Elder, HealthRecord, Room, Schedule } from '../../network/Dto';
import { WideDoctorAdmission } from './WideDoctorAdmission';
import { WideServerMonitor } from './WideServerMonitor';
import { WideRoleManagement } from './WideRoleManagement';
import { WideUserManagement } from './WideUserManagement';
import { WideBedManagement } from './WideBedManagement';
import { WideModelManagement } from './WideModelManagement';
import { WideDeviceManagement } from './WideDeviceManagement';
import { WideDoctorCharts } from './WideDoctorCharts';
import { WideDoctorSchedule } from './WideDoctorSchedule';

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
  @Event onLogout: () => void = () => {};
  @Event onManagementNavSelect: (index: number) => void = (_index: number) => {};
  @Local selectedNavId: string = 'overview';
  @Local isSidebarCollapsed: boolean = false;
  @Local selectedPeriod: number = 0;
  @Local hoveredId: string = '';
  @Local businessStore: BusinessStore = BusinessStore.getShared();

  private navItemsForRole(): AdminNavItem[] {
    if (this.isDoctor) {
      return [
        { id: 'overview', label: '临床工作台', symbol: $r('sys.symbol.square_grid_2x2') },
        { id: 'residents', label: '长者档案', symbol: $r('sys.symbol.person_2_fill') },
        { id: 'ai', label: '康小伴 AI', symbol: $r('sys.symbol.AI_model') }
      ];
    }
    return [
      { id: 'overview', label: '服务器监控', symbol: $r('sys.symbol.desktop_fill') },
      { id: 'roles', label: '角色管理', symbol: $r('sys.symbol.key_shield_badge_person_crop_circle_fill') },
      { id: 'users', label: '用户', symbol: $r('sys.symbol.person_crop_circle_fill') },
      { id: 'quality', label: '床位', symbol: $r('sys.symbol.bed_double_fill') },
      { id: 'risk', label: '大模型', symbol: $r('sys.symbol.AI_model') },
      { id: 'assets', label: '设备', symbol: $r('sys.symbol.beacon_tower_fill') }
    ];
  }

  @Monitor('managementNavIndex')
  onManagementNavIndexChange(): void {
    const ids: string[] = this.isDoctor ?
      ['overview', 'residents', 'ai'] :
      ['overview', 'roles', 'users', 'quality', 'risk', 'assets'];
    if (this.managementNavIndex >= 0 && this.managementNavIndex < ids.length) {
      this.selectedNavId = ids[this.managementNavIndex];
      setTimeout((): void => { this.managementScroller.scrollEdge(Edge.Top); }, 0);
    }
  }

  aboutToAppear(): void {
    this.onManagementNavIndexChange();
    this.businessStore.load();
  }

  private currentDateValue(): string {
    const now: Date = new Date();
    return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${
      now.getDate().toString().padStart(2, '0')}`;
  }

  private metrics(): AdminMetric[] {
    const totalBeds: number = this.businessStore.beds.length;
    const occupiedBeds: number = this.businessStore.beds.filter((item: Bed) => item.status === 'occupied').length;
    const occupancy: number = totalBeds > 0 ? Math.round(occupiedBeds / totalBeds * 1000) / 10 : 0;
    const todaySchedules: number = this.businessStore.schedules.filter((item: Schedule) =>
      item.work_date === this.currentDateValue()).length;
    const totalTasks: number = this.businessStore.tasks.length;
    const doneTasks: number = this.businessStore.tasks.filter((item) => item.status === 'done').length;
    const completion: number = totalTasks > 0 ? Math.round(doneTasks / totalTasks * 1000) / 10 : 0;
    const openAlerts: Alert[] = this.businessStore.alerts.filter((item: Alert) =>
      item.status !== 'handled' && item.status !== 'closed');
    const emergencyAlerts: number = openAlerts.filter((item: Alert) => item.level === 'emergency').length;
    if (this.isDoctor) {
      const focusElders: number = this.businessStore.elders.filter((elder) =>
        openAlerts.some((alert: Alert) => alert.elder_id === elder.id)).length;
      const activeElders = this.businessStore.elders.filter((item) => item.status === 2);
      const remainingBeds: number = this.businessStore.beds.filter((item: Bed) => item.status === 'free').length;
      return [
        { label: '在住老人', value: activeElders.length.toString(), note: `当前在院 ${activeElders.length} 位`,
          symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
        { label: '剩余床位', value: remainingBeds.toString(), note: `共 ${this.businessStore.beds.length} 张床位`,
          symbol: $r('sys.symbol.bed_double_fill'), tone: 'success' },
        { label: '重点关注', value: focusElders.toString(), note: '存在未闭环风险的老人',
          symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
        { label: '预警', value: openAlerts.length.toString(), note: `${emergencyAlerts} 项紧急预警`,
          symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger' },
      ];
    }
    return [
      { label: '在院长者', value: this.businessStore.elders.filter((item) => item.status === 2).length.toString(),
        note: `床位使用率 ${occupancy}%`, symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
      { label: '今日排班', value: todaySchedules.toString(), note: '来自服务器排班记录',
        symbol: $r('sys.symbol.person_crop_circle_fill'), tone: 'warning' },
      { label: '任务完成率', value: `${completion}%`, note: `${doneTasks}/${totalTasks} 项已完成`,
        symbol: $r('sys.symbol.checkmark_circle_fill'), tone: 'success' },
      { label: '待闭环风险', value: openAlerts.length.toString(), note: `${emergencyAlerts} 项紧急告警`,
        symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger' }
    ];
  }

  private events(): AdminEvent[] {
    return this.businessStore.alerts.map((item: Alert): AdminEvent => ({
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
        this.getUIContext().getPromptAction().showToast({ message: '医师端当前仅支持查看风险记录' });
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
      (this.isDoctor ? '临床工作台' : '服务器监控');
  }

  private workspaceTitle(): string {
    return this.isDoctor ? '医师工作台' : '服务器监控';
  }

  private workspaceSubtitle(): string {
    return this.isDoctor ? '围绕长者档案与康小伴 AI 开展今日工作' :
      '查看当前后端主机、进程与磁盘资源状态';
  }

  private doctorQuickFunctions(): DoctorQuickFunction[] {
    return [
      { id: 'admission', label: '入住/退住管理', symbol: $r('sys.symbol.person_badge_plus'), tone: 'focus', target: 'quality' },
      { id: 'beds', label: '床位预览', symbol: $r('sys.symbol.bed_double_fill'), tone: 'success', target: 'residents' },
      { id: 'tasks', label: '护理任务', symbol: $r('sys.symbol.checkmark_circle_fill'), tone: 'warning', target: 'staff' },
      { id: 'alerts', label: '告警处理', symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger', target: 'risk' }
    ];
  }

  private openDoctorQuickFunction(item: DoctorQuickFunction): void {
    const ids: string[] = ['overview', 'residents', 'ai', 'quality', 'staff', 'risk'];
    const index: number = ids.indexOf(item.target);
    this.selectedNavId = item.target;
    if (index >= 0) {
      this.onManagementNavSelect(index);
    }
  }

  private doctorElderName(elderId: number): string {
    return this.businessStore.elders.find((item: Elder) => item.id === elderId)?.name ?? '未知长者';
  }

  private activate(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down && (event.keyCode === KeyCode.KEYCODE_ENTER ||
      event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
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
    .onKeyEvent((event: KeyEvent) => this.activate(event, () => this.selectedNavId = item.id))
    .onClick(() => this.selectedNavId = item.id)
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
    Column({ space: this.isDoctor ? 8 : 12 }) {
      if (!this.isDoctor) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(38).height(38).borderRadius(12).backgroundColor($r('app.color.doctor_workspace_surface_hover'))
            SymbolGlyph(metric.symbol).fontSize(20).fontColor([this.toneColor(metric.tone)])
          }
          Blank()
          Text('服务器数据').fontSize(9)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.width('100%')
      }
      Text(metric.label).fontSize(12).fontColor($r('app.color.doctor_workspace_text_secondary')).width('100%')
      Text(metric.value).fontSize(28).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary')).width('100%')
      Text(metric.note).fontSize(10).fontColor(this.toneColor(metric.tone)).width('100%')
    }
    .width('100%').height(this.isDoctor ? 124 : 176).padding(16).borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private eventRow(item: AdminEvent) {
    Row({ space: 12 }) {
      if (!this.isDoctor) {
        Row().width(4).height(42).borderRadius(2).backgroundColor(this.toneColor(item.tone))
      }
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
        Text(this.businessStore.loading ? (this.isDoctor ? '正在加载长者入住数据' : '正在加载床位数据') :
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
        SymbolGlyph(item.symbol).fontSize(18).fontColor([this.toneColor(item.tone)])
        Text(item.label).fontSize(12).fontColor($r('app.color.doctor_workspace_text_primary'))
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
        Text('常用功能').fontSize(16).fontWeight(FontWeight.Bold)
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
            Text('部分数据暂未同步，正在自动重试').fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
            .accessibilityText('部分数据暂未同步，正在自动重试')
        }
        GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
          ForEach(this.metrics(), (metric: AdminMetric) => {
            GridCol({ span: this.compactWidth ? 6 : 3 }) { this.metricCard(metric) }
          }, (metric: AdminMetric) => metric.label)
        }.width('100%')
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
                  loading: this.businessStore.loading,
                  compactWidth: this.compactWidth
                })
              }.width('100%').alignItems(HorizontalAlign.Start)
            } else {
              this.occupancyPanel()
            }
          }
          GridCol({ span: this.compactWidth ? 12 : 7 }) {
            if (this.isDoctor) {
              WideDoctorCharts({
                elders: this.businessStore.elders,
                compactWidth: this.compactWidth
              })
            } else {
              Column() {
                Row() {
                  Text('今日运营关注').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.doctor_workspace_text_primary'))
                  Blank()
                  Text(`${this.events().length} 项`).fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
                }.width('100%').height(52).padding({ left: 16, right: 16 })
                if (this.events().length === 0) {
                  Text(this.businessStore.loading ? '正在加载告警数据' : '暂无运营关注事项')
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
          }
        }.width('100%')
      }
      .width('100%').padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: 36 + this.naviIndicatorHeight }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
  }

  @Builder
  private modulePlaceholder() {
    Column({ space: 14 }) {
      SymbolGlyph(this.navItemsForRole().find((item: AdminNavItem) => item.id === this.selectedNavId)?.symbol ??
        $r('sys.symbol.square_grid_2x2'))
        .fontSize(42).fontColor([$r('app.color.doctor_workspace_accent')])
      Text(this.title()).fontSize(26).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(this.isDoctor ? '该医师工作模块尚未开放服务器业务接口。' : '该模块尚未开放服务器业务接口。')
        .fontSize(12).fontColor($r('app.color.doctor_workspace_text_secondary'))
      Button(this.isDoctor ? '返回医师工作台' : '返回服务器监控').height(40).borderRadius(12).fontSize(12)
        .fontColor($r('app.color.doctor_workspace_background'))
        .backgroundColor($r('app.color.doctor_workspace_text_primary'))
        .onClick(() => this.selectedNavId = 'overview')
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private doctorRiskModule() {
    Scroll(this.managementScroller) {
      Column({ space: 12 }) {
        this.moduleHeader('风险复核', '查看服务端生成的风险事件；医师端不直接关闭或处置告警')
        if (this.events().length === 0) {
          this.moduleEmpty('暂无待复核风险事件')
        } else {
          ForEach(this.events(), (item: AdminEvent) => this.eventRow(item), (item: AdminEvent) => item.id)
        }
      }
      .width('100%').constraintSize({ maxWidth: 1088 })
      .padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: 36 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
  }

  @Builder
  private doctorHealthModule() {
    Scroll(this.managementScroller) {
      Column({ space: 12 }) {
        this.moduleHeader('健康监测', '查看服务器已记录的体征与设备状态，不在医师端直接录入')
        if (this.businessStore.healthRecords.length === 0) {
          this.moduleEmpty('暂无健康记录')
        } else {
          ForEach(this.businessStore.healthRecords.slice(-80).reverse(), (record: HealthRecord) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(this.doctorElderName(record.elder_id)).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Text(record.record_time.length >= 16 ? record.record_time.slice(0, 16).replace('T', ' ') : '--')
                  .fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(`心率 ${record.heart_rate ?? '--'} · 血氧 ${record.spo2 ?? '--'} · 体温 ${record.temperature ?? '--'}`)
                .fontSize(10).fontColor(record.is_abnormal ? $r('app.color.doctor_workspace_warning') :
                  $r('app.color.doctor_workspace_text_secondary'))
            }
            .width('100%').padding(13).borderRadius(12)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          }, (record: HealthRecord) => `doctor-health-${record.id}`)
        }
      }
      .width('100%').constraintSize({ maxWidth: 1088 })
      .padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: 36 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
  }

  @Builder
  private doctorCollaborationModule() {
    Scroll(this.managementScroller) {
      Column({ space: 12 }) {
        this.moduleHeader('护理协作', '查看护理任务与执行进度，复核由服务端记录的护理结果')
        if (this.businessStore.tasks.length === 0) {
          this.moduleEmpty('暂无护理任务')
        } else {
          ForEach(this.businessStore.tasks.slice(-80).reverse(), (task: CareTask) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(task.title).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Text(`${this.doctorElderName(task.elder_id)} · ${task.assignee ?? '未分配'}`)
                  .fontSize(10).fontColor($r('app.color.doctor_workspace_text_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(task.status === 'done' ? '已完成' : task.status === 'doing' ? '进行中' : '待处理')
                .fontSize(11).fontColor(task.status === 'done' ? $r('app.color.doctor_workspace_success') :
                  $r('app.color.doctor_workspace_warning'))
            }
            .width('100%').padding(13).borderRadius(12)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          }, (task: CareTask) => `doctor-task-${task.id}`)
        }
        if (this.businessStore.careExecutions.length > 0) {
          Text(`已记录护理执行 ${this.businessStore.careExecutions.length} 条`)
            .fontSize(11).fontColor($r('app.color.doctor_workspace_text_tertiary'))
            .width('100%').margin({ top: 4 })
        }
      }
      .width('100%').constraintSize({ maxWidth: 1088 })
      .padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: 36 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
  }

  @Builder
  private moduleHeader(title: string, subtitle: string) {
    Column({ space: 5 }) {
      Text(title).fontSize(24).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(subtitle).fontSize(11).fontColor($r('app.color.doctor_workspace_text_secondary'))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private moduleEmpty(text: string) {
    Text(text).width('100%').padding({ top: 64, bottom: 64 })
      .fontSize(12).fontColor($r('app.color.doctor_workspace_text_tertiary'))
      .textAlign(TextAlign.Center)
  }

  @Builder
  private doctorModuleView() {
    if (this.selectedNavId === 'staff') {
      this.doctorCollaborationModule()
    } else if (this.selectedNavId === 'quality') {
      WideDoctorAdmission({
        compactWidth: this.compactWidth,
        contentTopInset: WIDE_TITLE_BAR_HEIGHT + this.statusBarHeight,
        naviIndicatorHeight: this.naviIndicatorHeight,
        standaloneMode: false,
        onExit: () => { this.selectedNavId = 'overview'; }
      })
    } else if (this.selectedNavId === 'risk') {
      this.doctorRiskModule()
    } else if (this.selectedNavId === 'assets') {
      this.doctorHealthModule()
    } else {
      this.modulePlaceholder()
    }
  }

  @Builder
  private workspaceContent() {
    Column() {
      if (this.selectedNavId === 'overview') {
        if (this.isDoctor) {
          this.dashboard()
        } else {
          WideServerMonitor({
            statusBarHeight: this.statusBarHeight,
            naviIndicatorHeight: this.naviIndicatorHeight,
            compactWidth: this.compactWidth,
            managementScroller: this.managementScroller
          })
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
      } else if (!this.isDoctor && this.selectedNavId === 'quality') {
        WideBedManagement({
          compactWidth: this.compactWidth,
          statusBarHeight: this.statusBarHeight,
          naviIndicatorHeight: this.naviIndicatorHeight,
          managementScroller: this.managementScroller
        })
      } else if (!this.isDoctor && this.selectedNavId === 'risk') {
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
        this.doctorModuleView()
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
