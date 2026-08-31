import { KeyCode } from '@kit.InputKit';
import ApiClient from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Assessment, Bed, CareTask, Elder, HealthRecord, Room, Schedule } from '../../network/Dto';
import { WideDoctorAdmission } from './WideDoctorAdmission';

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
  @Param doctorScroller: Scroller = new Scroller();
  @Param doctorNavIndex: number = 0;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
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
        { id: 'staff', label: '护理协作', symbol: $r('sys.symbol.person_crop_circle_fill') },
        { id: 'quality', label: '评估与照护计划', symbol: $r('sys.symbol.checkmark_shield_fill') },
        { id: 'risk', label: '风险复核', symbol: $r('sys.symbol.exclamationmark_triangle_fill') },
        { id: 'assets', label: '健康监测', symbol: $r('sys.symbol.waveform_path_ecg_square') },
        { id: 'reports', label: '评估记录', symbol: $r('sys.symbol.checkmark_shield_fill') }
      ];
    }
    return [
      { id: 'overview', label: '运营总览', symbol: $r('sys.symbol.square_grid_2x2') },
      { id: 'residents', label: '长者与床位', symbol: $r('sys.symbol.person_2_fill') },
      { id: 'staff', label: '人员与排班', symbol: $r('sys.symbol.person_crop_circle_fill') },
      { id: 'quality', label: '养护质量', symbol: $r('sys.symbol.checkmark_shield_fill') },
      { id: 'risk', label: '风险事件', symbol: $r('sys.symbol.exclamationmark_triangle_fill') },
      { id: 'assets', label: '设备与物资', symbol: $r('sys.symbol.archivebox_fill') },
      { id: 'reports', label: '运营报表', symbol: $r('sys.symbol.waveform_path_ecg_square') }
    ];
  }

  @Monitor('doctorNavIndex')
  onDoctorNavIndexChange(): void {
    if (!this.isDoctor) {
      return;
    }
    const ids: string[] = ['overview', 'residents', 'staff', 'quality', 'risk', 'assets', 'reports'];
    if (this.doctorNavIndex >= 0 && this.doctorNavIndex < ids.length) {
      this.selectedNavId = ids[this.doctorNavIndex];
    }
  }

  aboutToAppear(): void {
    this.onDoctorNavIndexChange();
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
      const pendingAssessments: number = activeElders.filter((elder) =>
        !this.businessStore.assessments.some((assessment) => assessment.elder_id === elder.id)).length;
      return [
        { label: '重点关注长者', value: focusElders.toString(), note: `${openAlerts.length} 条待复核风险`,
          symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
        { label: '待复核风险', value: openAlerts.length.toString(), note: `${emergencyAlerts} 项紧急风险`,
          symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger' },
        { label: '待评估长者', value: pendingAssessments.toString(), note: '当前在院且暂无评估记录',
          symbol: $r('sys.symbol.checkmark_shield_fill'), tone: 'warning' },
        { label: '护理执行进度', value: `${completion}%`, note: `${doneTasks}/${totalTasks} 项护理任务已完成`,
          symbol: $r('sys.symbol.checkmark_circle_fill'), tone: 'success' }
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
    return this.isDoctor ? WIDE_TITLE_BAR_HEIGHT + this.statusBarHeight + 20 : this.statusBarHeight + 28;
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
      (this.isDoctor ? '临床工作台' : '运营总览');
  }

  private workspaceTitle(): string {
    return this.isDoctor ? '医师工作台' : '机构运营总览';
  }

  private workspaceSubtitle(): string {
    return this.isDoctor ? '围绕长者健康评估、风险复核与护理计划协作开展今日工作' :
      '围绕长者安全、人员配置与养护质量组织今日运营';
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
    Column({ space: 12 }) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(38).height(38).borderRadius(12).backgroundColor($r('app.color.doctor_workspace_surface_hover'))
          SymbolGlyph(metric.symbol).fontSize(20).fontColor([this.toneColor(metric.tone)])
        }
        Blank()
        Text(this.isDoctor ? '健康与照护数据' : '服务器数据').fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      Text(metric.label).fontSize(12).fontColor($r('app.color.doctor_workspace_text_secondary')).width('100%')
      Text(metric.value).fontSize(28).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary')).width('100%')
      Text(metric.note).fontSize(10).fontColor(this.toneColor(metric.tone)).width('100%')
    }
    .width('100%').height(176).padding(16).borderRadius(16)
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
    Scroll(this.doctorScroller) {
      Column({ space: 20 }) {
        Row() {
          Column({ space: 5 }) {
            Text(this.workspaceTitle()).fontSize(this.compactWidth ? 26 : 30).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text(this.workspaceSubtitle()).fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.isDoctor ? '实时健康数据' : '实时数据')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
        }.width('100%').alignItems(VerticalAlign.Center)
        GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
          ForEach(this.metrics(), (metric: AdminMetric) => {
            GridCol({ span: this.compactWidth ? 6 : 3 }) { this.metricCard(metric) }
          }, (metric: AdminMetric) => metric.label)
        }.width('100%')
        GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
          GridCol({ span: this.compactWidth ? 12 : 5 }) { this.occupancyPanel() }
          GridCol({ span: this.compactWidth ? 12 : 7 }) {
            Column() {
              Row() {
                Text(this.isDoctor ? '今日风险复核' : '今日运营关注').fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Blank()
                Text(`${this.events().length} 项`).fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
              }.width('100%').height(52).padding({ left: 16, right: 16 })
              if (this.events().length === 0) {
                Text(this.businessStore.loading ? (this.isDoctor ? '正在加载风险记录' : '正在加载告警数据') :
                  (this.isDoctor ? '暂无待复核风险事件' : '暂无运营关注事项'))
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
        }.width('100%')
      }
      .width('100%').padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: 36 + this.naviIndicatorHeight }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
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
      Button(this.isDoctor ? '返回医师工作台' : '返回运营总览').height(40).borderRadius(12).fontSize(12)
        .fontColor($r('app.color.doctor_workspace_background'))
        .backgroundColor($r('app.color.doctor_workspace_text_primary'))
        .onClick(() => this.selectedNavId = 'overview')
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private doctorResidentModule() {
    Scroll(this.doctorScroller) {
      Column({ space: 12 }) {
        this.moduleHeader('长者档案', '查看在院长者的基本资料、照护等级和床位信息')
        if (this.businessStore.elders.length === 0) {
          this.moduleEmpty('暂无长者档案')
        } else {
          ForEach(this.businessStore.elders, (elder: Elder) => {
            Row({ space: 12 }) {
              Text(elder.name.slice(0, 1))
                .width(42).height(42).borderRadius(21)
                .fontSize(17).fontColor(Color.White).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.doctor_workspace_accent'))
              Column({ space: 4 }) {
                Text(elder.name).fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Text(`${elder.gender === 'M' ? '男' : '女'} · ${elder.status === 2 ? '在院' : '非在院'} · 照护等级 ${elder.care_level}`)
                  .fontSize(10).fontColor($r('app.color.doctor_workspace_text_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(elder.bed?.bed_no ?? '未分配床位')
                .fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
            }
            .width('100%').padding(14).borderRadius(12)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          }, (elder: Elder) => `doctor-elder-${elder.id}`)
        }
      }
      .width('100%').constraintSize({ maxWidth: 1088 })
      .padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.contentTopPadding(), bottom: 36 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private doctorRiskModule() {
    Scroll(this.doctorScroller) {
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
  }

  @Builder
  private doctorHealthModule() {
    Scroll(this.doctorScroller) {
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
  }

  @Builder
  private doctorCollaborationModule() {
    Scroll(this.doctorScroller) {
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
  }

  @Builder
  private doctorReportsModule() {
    Scroll(this.doctorScroller) {
      Column({ space: 12 }) {
        this.moduleHeader('评估记录', '查看已保存的服务端评估结果和护理执行进度')
        if (this.businessStore.assessments.length === 0) {
          this.moduleEmpty('暂无评估记录')
        } else {
          ForEach(this.businessStore.assessments, (assessment: Assessment) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(this.businessStore.elders.find((item: Elder) => item.id === assessment.elder_id)?.name ?? '未知长者')
                  .fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Text(assessment.assessment_type || '护理评估')
                  .fontSize(10).fontColor($r('app.color.doctor_workspace_text_secondary'))
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(assessment.score === undefined ? '未评分' : `${assessment.score} 分`)
                .fontSize(12).fontColor($r('app.color.doctor_workspace_focus'))
            }
            .width('100%').padding(13).borderRadius(12)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          }, (assessment: Assessment) => `doctor-assessment-${assessment.id}`)
        }
      }
      .width('100%').constraintSize({ maxWidth: 1088 })
      .padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.statusBarHeight + 28, bottom: 36 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
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
    if (this.selectedNavId === 'residents') {
      this.doctorResidentModule()
    } else if (this.selectedNavId === 'staff') {
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
    } else if (this.selectedNavId === 'reports') {
      this.doctorReportsModule()
    } else {
      this.modulePlaceholder()
    }
  }

  @Builder
  private workspaceContent() {
    Column() {
      if (this.selectedNavId === 'overview') {
        this.dashboard()
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
    if (this.isDoctor) {
      this.workspaceContent()
    } else {
      Row() {
        this.sidebar()
        this.workspaceContent()
      }
      .width('100%').height('100%')
      .backgroundColor($r('app.color.doctor_workspace_background'))
    }
  }
}
