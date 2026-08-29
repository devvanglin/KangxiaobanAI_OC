import { KeyCode } from '@kit.InputKit';
import ApiClient from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Bed, Room, Schedule } from '../../network/Dto';

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

@ComponentV2
export struct WideAdminWorkspace {
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local selectedNavId: string = 'overview';
  @Local isSidebarCollapsed: boolean = false;
  @Local selectedPeriod: number = 0;
  @Local hoveredId: string = '';
  @Local businessStore: BusinessStore = BusinessStore.getShared();

  private navItems: AdminNavItem[] = [
    { id: 'overview', label: '运营总览', symbol: $r('sys.symbol.square_grid_2x2') },
    { id: 'residents', label: '长者与床位', symbol: $r('sys.symbol.person_2_fill') },
    { id: 'staff', label: '人员与排班', symbol: $r('sys.symbol.person_crop_circle_fill') },
    { id: 'quality', label: '养护质量', symbol: $r('sys.symbol.checkmark_shield_fill') },
    { id: 'risk', label: '风险事件', symbol: $r('sys.symbol.exclamationmark_triangle_fill') },
    { id: 'assets', label: '设备与物资', symbol: $r('sys.symbol.archivebox_fill') },
    { id: 'reports', label: '运营报表', symbol: $r('sys.symbol.waveform_path_ecg_square') }
  ];

  aboutToAppear(): void {
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
      status: item.status === 'closed' ? '已闭环' : item.status === 'handled' ? '跟进中' : '待处理',
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

  private toneColor(tone: string): ResourceColor {
    if (tone === 'danger') return $r('app.color.doctor_workspace_danger');
    if (tone === 'warning') return $r('app.color.doctor_workspace_warning');
    if (tone === 'success') return $r('app.color.doctor_workspace_success');
    if (tone === 'focus') return $r('app.color.doctor_workspace_focus');
    return $r('app.color.doctor_workspace_text_secondary');
  }

  private title(): string {
    return this.navItems.find((item: AdminNavItem) => item.id === this.selectedNavId)?.label ?? '运营总览';
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
            Text('机构管理端')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text('康小伴养老养护平台')
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
        ForEach(this.navItems, (item: AdminNavItem) => this.navItem(item), (item: AdminNavItem) => item.id)
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
        Text('服务器数据').fontSize(9).fontColor($r('app.color.doctor_workspace_text_tertiary'))
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
      Row().width(4).height(42).borderRadius(2).backgroundColor(this.toneColor(item.tone))
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
      Button(item.status === '已闭环' || item.status === '跟进中' ? item.status : '标记跟进')
        .height(32).fontSize(10).borderRadius(9)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
        .enabled(item.status !== '已闭环' && item.status !== '跟进中')
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
        Text('区域床位使用').fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text(`共 ${this.businessStore.beds.length} 张`).fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      if (this.occupancyRows().length === 0) {
        Text(this.businessStore.loading ? '正在加载床位数据' : '暂无床位数据')
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
      Progress({ value: percent, total: 100, type: ProgressType.Linear })
        .width('100%').height(6).color(percent >= 95 ? $r('app.color.doctor_workspace_warning') :
          $r('app.color.doctor_workspace_focus')).backgroundColor($r('app.color.doctor_workspace_surface_hover'))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dashboard() {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Column({ space: 5 }) {
            Text('机构运营总览').fontSize(this.compactWidth ? 26 : 30).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text('围绕长者安全、人员配置与养护质量组织今日运营').fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('实时数据')
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
        }.width('100%')
      }
      .width('100%').padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.statusBarHeight + 28, bottom: 36 + this.naviIndicatorHeight }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private modulePlaceholder() {
    Column({ space: 14 }) {
      SymbolGlyph(this.navItems.find((item: AdminNavItem) => item.id === this.selectedNavId)?.symbol ??
        $r('sys.symbol.square_grid_2x2'))
        .fontSize(42).fontColor([$r('app.color.doctor_workspace_accent')])
      Text(this.title()).fontSize(26).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text('该模块尚未开放服务器业务接口。')
        .fontSize(12).fontColor($r('app.color.doctor_workspace_text_secondary'))
      Button('返回运营总览').height(40).borderRadius(12).fontSize(12)
        .fontColor($r('app.color.doctor_workspace_background'))
        .backgroundColor($r('app.color.doctor_workspace_text_primary'))
        .onClick(() => this.selectedNavId = 'overview')
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  build() {
    Row() {
      this.sidebar()
      if (this.selectedNavId === 'overview') {
        this.dashboard()
      } else {
        this.modulePlaceholder()
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.doctor_workspace_background'))
  }
}
