import { KeyCode } from '@kit.InputKit';

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
  title: string;
  detail: string;
  owner: string;
  time: string;
  status: string;
  tone: string;
}

@ComponentV2
export struct WideAdminWorkspace {
  @Param statusBarHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local selectedNavId: string = 'overview';
  @Local isSidebarCollapsed: boolean = false;
  @Local selectedPeriod: number = 0;
  @Local hoveredId: string = '';
  @Local resolvedIds: string[] = [];

  private navItems: AdminNavItem[] = [
    { id: 'overview', label: '运营总览', symbol: $r('sys.symbol.square_grid_2x2') },
    { id: 'residents', label: '长者与床位', symbol: $r('sys.symbol.person_2_fill'), badge: '3' },
    { id: 'staff', label: '人员与排班', symbol: $r('sys.symbol.person_crop_circle_fill'), badge: '2' },
    { id: 'quality', label: '养护质量', symbol: $r('sys.symbol.checkmark_shield_fill') },
    { id: 'risk', label: '风险事件', symbol: $r('sys.symbol.exclamationmark_triangle_fill'), badge: '5' },
    { id: 'assets', label: '设备与物资', symbol: $r('sys.symbol.archivebox_fill'), badge: '4' },
    { id: 'reports', label: '运营报表', symbol: $r('sys.symbol.waveform_path_ecg_square') }
  ];

  private metrics: AdminMetric[] = [
    { label: '在院长者', value: '128', note: '床位使用率 91.4%', symbol: $r('sys.symbol.person_2_fill'), tone: 'focus' },
    { label: '今日在岗', value: '46', note: '2 个班次待补位', symbol: $r('sys.symbol.person_crop_circle_fill'), tone: 'warning' },
    { label: '计划完成率', value: '93.6%', note: '较昨日 +2.1%', symbol: $r('sys.symbol.checkmark_circle_fill'), tone: 'success' },
    { label: '待闭环风险', value: '5', note: '1 项需要优先跟进', symbol: $r('sys.symbol.exclamationmark_triangle_fill'), tone: 'danger' }
  ];

  private events: AdminEvent[] = [
    { id: 'event-01', title: '3A 区夜班人员缺口', detail: '距交班 2 小时，尚缺 1 名护理员', owner: '人事排班', time: '10:28', status: '待协调', tone: 'warning' },
    { id: 'event-02', title: '2B 区跌倒风险复盘', detail: '环境与照护措施已补充，等待负责人确认', owner: '质量管理', time: '10:16', status: '待确认', tone: 'danger' },
    { id: 'event-03', title: '营养评估完成率低于目标', detail: '本周 8 位长者尚未完成周期评估', owner: '养护管理', time: '09:52', status: '跟进中', tone: 'warning' },
    { id: 'event-04', title: '智能床垫电量预警', detail: '4 台设备需在今日巡检中完成充电', owner: '设备管理', time: '09:31', status: '待处理', tone: 'neutral' }
  ];

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
      }.width('100%').padding(10)
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
        Text('本地演示').fontSize(9).fontColor($r('app.color.doctor_workspace_text_tertiary'))
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
      Button(this.resolvedIds.indexOf(item.id) >= 0 ? '已闭环' : '标记跟进')
        .height(32).fontSize(10).borderRadius(9)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
        .onClick(() => {
          if (this.resolvedIds.indexOf(item.id) < 0) this.resolvedIds = [...this.resolvedIds, item.id];
        })
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
        Text('共 140 张').fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      this.progressRow('2A 养护区', 34, 36, 94)
      this.progressRow('2B 养护区', 29, 32, 91)
      this.progressRow('3A 重点养护区', 31, 32, 97)
      this.progressRow('5A 认知照护区', 34, 40, 85)
    }
    .width('100%').height(258).padding(18).borderRadius(16)
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
          Row({ space: 6 }) {
            ForEach(['今日', '本周', '本月'], (label: string, index: number) => {
              Button(label).height(34).fontSize(10).borderRadius(10)
                .fontColor(this.selectedPeriod === index ? $r('app.color.doctor_workspace_background') :
                  $r('app.color.doctor_workspace_text_primary'))
                .backgroundColor(this.selectedPeriod === index ? $r('app.color.doctor_workspace_text_primary') :
                  $r('app.color.doctor_workspace_surface'))
                .onClick(() => this.selectedPeriod = index)
            })
          }
        }.width('100%').alignItems(VerticalAlign.Center)
        GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
          ForEach(this.metrics, (metric: AdminMetric) => {
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
                Text(`${this.events.length} 项`).fontSize(10).fontColor($r('app.color.doctor_workspace_text_tertiary'))
              }.width('100%').height(52).padding({ left: 16, right: 16 })
              ForEach(this.events, (item: AdminEvent) => this.eventRow(item), (item: AdminEvent) => item.id)
            }.width('100%').borderRadius(16).backgroundColor($r('app.color.doctor_workspace_surface'))
              .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          }
        }.width('100%')
      }
      .width('100%').padding({ left: this.compactWidth ? 20 : 28, right: this.compactWidth ? 20 : 28,
        top: this.statusBarHeight + 28, bottom: 36 }).alignItems(HorizontalAlign.Start)
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
      Text('该模块已纳入管理端信息架构，当前展示本地演示入口。')
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
