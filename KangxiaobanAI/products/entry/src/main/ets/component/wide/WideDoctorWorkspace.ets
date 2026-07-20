// Copyright (c) 2026 Huawei Device Co., Ltd.
// Licensed under the Apache License, Version 2.0.

import { ColorMetrics, LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { WindowUtil } from '../../util/WindowUtil';

interface DoctorNavItem {
  id: string;
  label: string;
  symbol: Resource;
  badge?: string;
}

interface DoctorNavGroup {
  label: string;
  items: DoctorNavItem[];
}

interface DoctorRecentPatient {
  id: string;
  bed: string;
  displayName: string;
  visitedAt: string;
}

interface DoctorQueueItem {
  id: string;
  patient: string;
  bed: string;
  reason: string;
  meta: string;
  status: string;
  tone: string;
}

interface DoctorModuleRow {
  id: string;
  patient: string;
  bed: string;
  item: string;
  source: string;
  updatedAt: string;
  status: string;
  tone: string;
}

@ComponentV2
export struct WideDoctorWorkspace {
  @Param statusBarHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local selectedNavId: string = 'workspace';
  @Local selectedModuleRowId: string = 'case-01';
  @Local moduleFilterIndex: number = 0;
  @Local isSidebarCollapsed: boolean = false;
  @Local hoveredTarget: string = '';
  @Local searchText: string = '';
  @Local aiQuestion: string = '';
  @Local generalSettingsIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.gearshape'))
      .fontSize(18)
      .fontColor([$r('app.color.doctor_workspace_text_primary')]);
  @Local aboutIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.info_circle'))
      .fontSize(18)
      .fontColor([$r('app.color.doctor_workspace_text_primary')]);
  @Local logoutIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.xmark'))
      .fontSize(18)
      .fontColor([$r('app.color.doctor_workspace_danger')]);
  private focusController = this.getUIContext().getFocusController();
  private sidebarScroller: Scroller = new Scroller();

  private homeNavItem: DoctorNavItem = {
    id: 'workspace',
    label: '医师工作台',
    symbol: $r('sys.symbol.stethoscope'),
    badge: '8'
  };

  private navGroups: DoctorNavGroup[] = [
    {
      label: '患者',
      items: [
        { id: 'patients', label: '我的患者', symbol: $r('sys.symbol.person_2_fill') },
        { id: 'focus', label: '重点关注', symbol: $r('sys.symbol.waveform_path_ecg_heart_fill'), badge: '4' }
      ]
    },
    {
      label: '临床工作',
      items: [
        { id: 'rounds', label: '今日查房', symbol: $r('sys.symbol.calendar_badge_clock'), badge: '22' },
        { id: 'judgment', label: '待医生判断', symbol: $r('sys.symbol.waveform_path_ecg_magnifyingglass'), badge: '8' },
        { id: 'orders', label: '医嘱签署', symbol: $r('sys.symbol.cross_text_clipboard'), badge: '5' },
        { id: 'results', label: '结果复核', symbol: $r('sys.symbol.cross_vial'), badge: '6' },
        { id: 'consultation', label: '会诊沟通', symbol: $r('sys.symbol.message_on_message_fill'), badge: '3' }
      ]
    },
    {
      label: '数据与智能',
      items: [
        { id: 'analysis', label: '临床分析', symbol: $r('sys.symbol.waveform_path_ecg_square') },
        { id: 'observation', label: '智能观察', symbol: $r('sys.symbol.cross_shield_badge_trend'), badge: '2' },
        { id: 'ai', label: '康小伴 AI', symbol: $r('sys.symbol.AI_message') }
      ]
    }
  ];

  private recentPatients: DoctorRecentPatient[] = [
    { id: 'recent-01', bed: '3A-12', displayName: '刘*', visitedAt: '10:24' },
    { id: 'recent-02', bed: '2B-06', displayName: '周*', visitedAt: '09:48' },
    { id: 'recent-03', bed: '5A-03', displayName: '陈*', visitedAt: '昨天' }
  ];

  private judgmentQueue: DoctorQueueItem[] = [
    { id: 'judge-01', patient: '刘*', bed: '3A-12', reason: '血氧连续 20 分钟低于 92%', meta: '等待 38 分钟', status: '紧急', tone: 'danger' },
    { id: 'judge-02', patient: '王*', bed: '3A-08', reason: '静息心率较基线升高 28%', meta: '等待 24 分钟', status: '关注', tone: 'warning' },
    { id: 'judge-03', patient: '陈*', bed: '5A-03', reason: '餐后血糖 14.2 mmol/L', meta: '等待 16 分钟', status: '待判断', tone: 'neutral' },
    { id: 'judge-04', patient: '赵*', bed: '2B-11', reason: '夜间体温升高至 38.3℃', meta: '等待 9 分钟', status: '待判断', tone: 'neutral' },
    { id: 'judge-05', patient: '何*', bed: '5A-05', reason: '血压较个人基线持续升高', meta: '等待 6 分钟', status: '待判断', tone: 'neutral' }
  ];

  private roundsQueue: DoctorQueueItem[] = [
    { id: 'round-01', patient: '周*', bed: '2B-06', reason: '术后第 2 天 · 重点查看伤口', meta: '10:40', status: '即将开始', tone: 'warning' },
    { id: 'round-02', patient: '李*', bed: '2B-09', reason: '呼吸训练与疼痛评估', meta: '11:00', status: '待查房', tone: 'neutral' },
    { id: 'round-03', patient: '孙*', bed: '3A-02', reason: '抗感染疗效复评', meta: '11:20', status: '待查房', tone: 'neutral' },
    { id: 'round-04', patient: '何*', bed: '5A-05', reason: '血糖方案调整后复评', meta: '11:40', status: '待查房', tone: 'neutral' },
    { id: 'round-05', patient: '赵*', bed: '2B-11', reason: '夜间发热病程复核', meta: '12:00', status: '待查房', tone: 'neutral' }
  ];

  private reviewQueue: DoctorQueueItem[] = [
    { id: 'review-01', patient: '刘*', bed: '3A-12', reason: '抗感染医嘱草稿', meta: '10:18', status: '待签署', tone: 'warning' },
    { id: 'review-02', patient: '陈*', bed: '5A-03', reason: '糖化血红蛋白异常结果', meta: '10:05', status: '待复核', tone: 'danger' },
    { id: 'review-03', patient: '周*', bed: '2B-06', reason: '术后影像报告', meta: '09:56', status: '待复核', tone: 'neutral' },
    { id: 'review-04', patient: '王*', bed: '3A-08', reason: '心内科会诊回复', meta: '09:42', status: '待确认', tone: 'neutral' },
    { id: 'review-05', patient: '李*', bed: '2B-09', reason: '镇痛方案调整草稿', meta: '09:30', status: '待签署', tone: 'neutral' }
  ];

  private moduleRows: DoctorModuleRow[] = [
    { id: 'case-01', patient: '刘*', bed: '3A-12', item: '血氧下降，需结合肺部感染病程判断', source: '床旁设备 + 护理记录', updatedAt: '10:32', status: '紧急', tone: 'danger' },
    { id: 'case-02', patient: '王*', bed: '3A-08', item: '静息心率较个人基线上升', source: '床旁设备', updatedAt: '10:28', status: '关注', tone: 'warning' },
    { id: 'case-03', patient: '陈*', bed: '5A-03', item: '餐后血糖异常，等待医生复核', source: '血糖仪', updatedAt: '10:21', status: '待处理', tone: 'neutral' },
    { id: 'case-04', patient: '赵*', bed: '2B-11', item: '夜间发热记录需要补充判断', source: '体温单', updatedAt: '10:12', status: '待处理', tone: 'neutral' },
    { id: 'case-05', patient: '周*', bed: '2B-06', item: '术后影像报告已回传', source: '影像科', updatedAt: '09:56', status: '待复核', tone: 'neutral' },
    { id: 'case-06', patient: '何*', bed: '5A-05', item: '调整方案后血糖趋势趋稳', source: '血糖仪 + 医嘱', updatedAt: '09:36', status: '已更新', tone: 'normal' }
  ];

  private riskTrendValues: number[] = [28, 42, 36, 55, 48, 68, 52, 74, 62, 84, 58, 72, 46, 64, 54, 76];
  private closureTrendValues: number[] = [36, 44, 52, 48, 60, 66, 62, 72, 68, 80, 76, 86, 82, 88, 84, 92];

  aboutToAppear(): void {
    WindowUtil.setSystemBarForDarkBackground(true);
  }

  aboutToDisappear(): void {
    WindowUtil.setSystemBarForDarkBackground(false);
  }

  private sidebarWidth(): number {
    if (this.isSidebarCollapsed) {
      return 72;
    }
    return this.compactWidth ? 224 : 248;
  }

  private mainPadding(): number {
    return this.compactWidth ? 20 : 24;
  }

  private isActive(id: string): boolean {
    return this.selectedNavId === id;
  }

  private toneColor(tone: string): ResourceColor {
    if (tone === 'danger') {
      return $r('app.color.doctor_workspace_danger');
    }
    if (tone === 'warning') {
      return $r('app.color.doctor_workspace_warning');
    }
    if (tone === 'normal') {
      return $r('app.color.doctor_workspace_success');
    }
    return $r('app.color.doctor_workspace_text_secondary');
  }

  private focusStrokeColor(): ColorMetrics {
    try {
      return ColorMetrics.resourceColor($r('sys.color.interactive_focus'));
    } catch (_error) {
      return ColorMetrics.numeric(0xFF1D63ED);
    }
  }

  private currentTitle(): string {
    if (this.homeNavItem.id === this.selectedNavId) {
      return this.homeNavItem.label;
    }
    for (let groupIndex: number = 0; groupIndex < this.navGroups.length; groupIndex++) {
      const group: DoctorNavGroup = this.navGroups[groupIndex];
      for (let itemIndex: number = 0; itemIndex < group.items.length; itemIndex++) {
        if (group.items[itemIndex].id === this.selectedNavId) {
          return group.items[itemIndex].label;
        }
      }
    }
    return '医师工作台';
  }

  private currentSubtitle(): string {
    if (this.selectedNavId === 'patients' || this.selectedNavId === 'focus') {
      return '按授权范围查看患者摘要、风险与近期记录';
    }
    if (this.selectedNavId === 'rounds') {
      return '按计划时间与临床优先级组织今日查房';
    }
    if (this.selectedNavId === 'orders') {
      return '草稿、签署与执行回执分层展示，所有操作保留审计记录';
    }
    if (this.selectedNavId === 'results') {
      return '聚合检验、影像与设备异常结果，等待医生复核';
    }
    if (this.selectedNavId === 'consultation') {
      return '集中处理会诊回复、医护沟通与患者上下文';
    }
    if (this.selectedNavId === 'analysis' || this.selectedNavId === 'observation') {
      return '趋势只用于发现问题，不替代患者级临床判断';
    }
    return '按风险、等待时长与业务截止时间排序';
  }

  private selectedModuleRow(): DoctorModuleRow {
    return this.moduleRows.find((row: DoctorModuleRow) => row.id === this.selectedModuleRowId) ??
      this.moduleRows[0];
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  private openGlobalSearch(): void {
    if (this.selectedNavId !== 'workspace') {
      this.selectedNavId = 'workspace';
      setTimeout(() => {
        try {
          this.focusController.requestFocus('doctor-global-search');
        } catch (_error) {
          // 页面切换未完成时保留工作台，不影响其它交互。
        }
      }, 120);
      return;
    }
    try {
      this.focusController.requestFocus('doctor-global-search');
    } catch (_error) {
      // 焦点请求失败时保留当前工作状态。
    }
  }

  private toggleSidebar(): void {
    this.isSidebarCollapsed = !this.isSidebarCollapsed;
    this.hoveredTarget = '';
    setTimeout(() => {
      try {
        this.sidebarScroller.scrollEdge(Edge.Top);
      } catch (_error) {
        // 侧栏尺寸切换期间滚动节点可能仍在重建，下一次布局会自然回到顶部。
      }
    }, 80);
  }

  @Builder
  private brandMark() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(30)
        .height(30)
        .borderRadius(10)
        .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
      SymbolGlyph($r('sys.symbol.cross_case_fill'))
        .fontSize(17)
        .fontColor([$r('app.color.doctor_workspace_accent')])
    }
    .width(30)
    .height(30)
  }

  @Builder
  private sidebarHeader() {
    Row({ space: 12 }) {
      this.brandMark()
      if (!this.isSidebarCollapsed) {
        Text('康小伴 AI')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .maxLines(1)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: this.isSidebarCollapsed ? 21 : 20, right: 16 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: 0.5 },
      color: { bottom: $r('app.color.doctor_workspace_border_soft') }
    })
  }

  @Builder
  private sidebarToggleButton() {
    Row({ space: 10 }) {
      SymbolGlyph(this.isSidebarCollapsed ? $r('sys.symbol.open_sidebar') : $r('sys.symbol.close_sidebar'))
        .fontSize(18)
        .fontColor([$r('app.color.doctor_workspace_text_secondary')])
      if (!this.isSidebarCollapsed) {
        Text('收起侧栏')
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
      }
    }
    .width(this.isSidebarCollapsed ? 40 : '100%')
    .height(40)
    .padding({ left: this.isSidebarCollapsed ? 0 : 12, right: this.isSidebarCollapsed ? 0 : 12 })
    .borderRadius(10)
    .backgroundColor(this.hoveredTarget === 'sidebar-toggle' ?
      $r('app.color.doctor_workspace_surface_hover') : Color.Transparent)
    .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(this.isSidebarCollapsed ? '展开侧栏' : '收起侧栏')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: this.focusStrokeColor()
    })
    .bindTips(this.isSidebarCollapsed ? '展开侧栏' : '收起侧栏', {
      appearingTime: 500,
      disappearingTime: 100,
      enableArrow: true,
      showAtAnchor: TipsAnchorType.TARGET
    })
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? 'sidebar-toggle' : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.toggleSidebar()))
    .onClick(() => this.toggleSidebar())
  }

  @Builder
  private quickSearch() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(17)
        .fontColor([$r('app.color.doctor_workspace_text_secondary')])
      if (!this.isSidebarCollapsed) {
        Text('快捷搜索…')
          .fontSize(14)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
        Text('Ctrl K')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
    }
    .width(this.isSidebarCollapsed ? 40 : '100%')
    .height(40)
    .padding({ left: this.isSidebarCollapsed ? 0 : 12, right: this.isSidebarCollapsed ? 0 : 12 })
    .borderRadius(11)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .accessibilityText('快捷搜索，快捷键 Control K')
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: this.focusStrokeColor()
    })
    .bindTips('快速搜索 · Ctrl K', {
      appearingTime: 500,
      disappearingTime: 100,
      enableArrow: true,
      showAtAnchor: TipsAnchorType.TARGET
    })
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.openGlobalSearch()))
    .onClick(() => this.openGlobalSearch())
  }

  @Builder
  private recentPatientItem(patient: DoctorRecentPatient) {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
        .fontSize(18)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
      if (!this.isSidebarCollapsed) {
        Column({ space: 2 }) {
          Text(`${patient.bed} · ${patient.displayName}`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .maxLines(1)
          Text(`最近查看 · ${patient.visitedAt}`)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height(this.isSidebarCollapsed ? 44 : 52)
    .padding({ left: this.isSidebarCollapsed ? 0 : 12, right: this.isSidebarCollapsed ? 0 : 10 })
    .borderRadius(10)
    .backgroundColor(this.hoveredTarget === patient.id ?
      $r('app.color.doctor_workspace_surface_hover') : Color.Transparent)
    .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(`最近查看，${patient.bed} ${patient.displayName}`)
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? patient.id : '')
    .onClick(() => {
      this.selectedNavId = 'patients';
    })
  }

  @Builder
  private sidebarNavItem(item: DoctorNavItem) {
    Row({ space: 11 }) {
      SymbolGlyph(item.symbol)
        .fontSize(18)
        .fontColor([this.isActive(item.id) ?
          $r('app.color.doctor_workspace_text_primary') :
          $r('app.color.doctor_workspace_text_tertiary')])
      if (!this.isSidebarCollapsed) {
        Text(item.label)
          .fontSize(13)
          .fontWeight(this.isActive(item.id) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.isActive(item.id) ?
            $r('app.color.doctor_workspace_text_primary') :
            $r('app.color.doctor_workspace_text_secondary'))
          .layoutWeight(1)
          .maxLines(1)
        if (item.badge) {
          Text(item.badge)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .width(24)
            .height(20)
            .padding({ left: 6, right: 6 })
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(11)
            .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
        }
      }
    }
    .width(this.isSidebarCollapsed ? 40 : '100%')
    .height(this.isSidebarCollapsed ? 40 : 44)
    .padding({ left: this.isSidebarCollapsed ? 0 : 12, right: this.isSidebarCollapsed ? 0 : 10 })
    .borderRadius(10)
    .backgroundColor(this.isActive(item.id) ?
      $r('app.color.doctor_workspace_surface_raised') :
      (this.hoveredTarget === item.id ? $r('app.color.doctor_workspace_surface_hover') : Color.Transparent))
    .justifyContent(this.isSidebarCollapsed ? FlexAlign.Center : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(item.badge ? `${item.label}，${item.badge} 项` : item.label)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilitySelected(this.isActive(item.id))
    .focusable(true)
    .focusOnTouch(true)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2),
      strokeColor: this.focusStrokeColor()
    })
    .bindTips(item.badge ? `${item.label}，${item.badge} 项` : item.label, {
      appearingTime: 500,
      disappearingTime: 100,
      enableArrow: true,
      showAtAnchor: TipsAnchorType.TARGET
    })
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? item.id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.selectedNavId = item.id;
    }))
    .onClick(() => {
      this.selectedNavId = item.id;
    })
  }

  @Builder
  private sidebarGroupTitle(label: string) {
    if (this.isSidebarCollapsed) {
      Divider()
        .width(24)
        .strokeWidth(0.5)
        .color($r('app.color.doctor_workspace_border_soft'))
        .margin({ top: 7, bottom: 7 })
    } else {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width('100%')
        .margin({ left: 10, top: 8, bottom: 5 })
    }
  }

  @Builder
  private sidebarNavigation() {
    Scroll(this.sidebarScroller) {
      Column({ space: 3 }) {
        this.sidebarNavItem(this.homeNavItem)
        if (!this.isSidebarCollapsed) {
          this.sidebarGroupTitle('最近查看')
          ForEach(this.recentPatients, (patient: DoctorRecentPatient) => {
            this.recentPatientItem(patient)
          }, (patient: DoctorRecentPatient) => patient.id)
        }
        ForEach(this.navGroups, (group: DoctorNavGroup, groupIndex: number) => {
          Column({ space: 3 }) {
            this.sidebarGroupTitle(group.label)
            ForEach(group.items, (item: DoctorNavItem) => {
              this.sidebarNavItem(item)
            }, (item: DoctorNavItem) => item.id)
          }
          .width('100%')
          .alignItems(this.isSidebarCollapsed ? HorizontalAlign.Center : HorizontalAlign.Start)
        }, (group: DoctorNavGroup, index: number) => `${group.label}-${index}`)
      }
      .width('100%')
      .padding({ bottom: 12 })
      .alignItems(this.isSidebarCollapsed ? HorizontalAlign.Center : HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private sidebarFooter() {
    Column({ space: 8 }) {
      if (!this.isSidebarCollapsed) {
        Row({ space: 8 }) {
          Row()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor($r('app.color.doctor_workspace_success'))
          Column({ space: 1 }) {
            Text('临床数据已同步')
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
            Text('最后更新 10:32')
              .fontSize(9)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 12 })
        .alignItems(VerticalAlign.Center)
      }
      this.sidebarToggleButton()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 12 })
    .border({
      width: { top: 0.5 },
      color: { top: $r('app.color.doctor_workspace_border_soft') }
    })
    .alignItems(this.isSidebarCollapsed ? HorizontalAlign.Center : HorizontalAlign.Start)
  }

  @Builder
  private sidebar() {
    Column() {
      this.sidebarHeader()
      Column() {
        this.quickSearch()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 14 })
      .alignItems(HorizontalAlign.Center)
      this.sidebarNavigation()
      this.sidebarFooter()
    }
    .width(this.sidebarWidth())
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.doctor_workspace_background'))
    .border({
      width: { right: 0.5 },
      color: { right: $r('app.color.doctor_workspace_border_soft') }
    })
    .animation({ duration: 240, curve: Curve.Friction })
    .clip(true)
  }

  @Builder
  private profileMenuHeader() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
        Text('ZM')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
      }
      Column({ space: 3 }) {
        Text('张敏')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text('呼吸内科 · 主治医师')
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private profileMenu() {
    Menu() {
      MenuItemGroup({ header: this.profileMenuHeader }) {
        MenuItem({ symbolStartIcon: this.generalSettingsIcon, content: '通用设置' })
          .height(46)
          .onClick(() => this.onOpenGeneral())
        MenuItem({ symbolStartIcon: this.aboutIcon, content: '关于我们' })
          .height(46)
          .onClick(() => this.onOpenAbout())
      }
      MenuItemGroup() {
        MenuItem({ symbolStartIcon: this.logoutIcon, content: '退出登录' })
          .height(46)
          .contentFontColor($r('app.color.doctor_workspace_danger'))
          .onClick(() => this.onLogout())
      }
    }
    .width(292)
    .radius(16)
  }

  @Builder
  private profileAction() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.hoveredTarget === 'doctor-profile' ?
          $r('app.color.doctor_workspace_surface_hover') :
          $r('app.color.doctor_workspace_surface_raised'))
      Text('ZM')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
    }
    .width(36)
    .height(36)
    .accessibilityText('医生账户菜单')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? 'doctor-profile' : '')
    .bindMenu(this.profileMenu, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 8, y: 0 }
    })
    .bindContextMenu(this.profileMenu, ResponseType.RightClick, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 8, y: 0 }
    })
  }

  @Builder
  private topTextAction(id: string, label: string, symbol: Resource, action: () => void) {
    Row({ space: 7 }) {
      SymbolGlyph(symbol)
        .fontSize(16)
        .fontColor([$r('app.color.doctor_workspace_text_secondary')])
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
    }
    .height(36)
    .padding({ left: 11, right: 12 })
    .borderRadius(10)
    .backgroundColor(this.hoveredTarget === id ?
      $r('app.color.doctor_workspace_surface_hover') : Color.Transparent)
    .accessibilityText(label)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, action))
    .onClick(action)
  }

  @Builder
  private topBar() {
    Row({ space: 4 }) {
      Blank()
        .layoutWeight(1)
      this.topTextAction('doctor-ai-top', '康小伴 AI', $r('sys.symbol.AI_message'), () => {
        this.selectedNavId = 'ai';
      })
      this.topTextAction('doctor-help', '支持', $r('sys.symbol.questionmark_circle'), () => {
        this.onOpenAbout();
      })
      this.profileAction()
    }
    .width('100%')
    .height(56 + this.statusBarHeight)
    .padding({ left: this.mainPadding(), right: this.mainPadding(), top: this.statusBarHeight })
    .backgroundColor($r('app.color.doctor_workspace_background'))
    .border({
      width: { bottom: 0.5 },
      color: { bottom: $r('app.color.doctor_workspace_border_soft') }
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private heroPill() {
    Row({ space: 8 }) {
      Row()
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor($r('app.color.doctor_workspace_success'))
      Text('康小伴 AI · 临床工作站')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(11)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
    }
    .height(36)
    .padding({ left: 14, right: 13 })
    .borderRadius(18)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.selectedNavId = 'ai';
    })
  }

  @Builder
  private shortcutKey(label: string) {
    Text(label)
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.doctor_workspace_text_secondary'))
      .width(label === 'Ctrl' ? 34 : 24)
      .height(24)
      .padding({ left: 6, right: 6 })
      .textAlign(TextAlign.Center)
      .borderRadius(6)
      .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
  }

  @Builder
  private heroSearch() {
    Stack({ alignContent: Alignment.End }) {
      Search({ value: this.searchText, placeholder: '搜索患者、床位、医嘱或检查结果' })
        .id('doctor-global-search')
        .width('100%')
        .height(56)
        .padding({ left: 6, right: this.compactWidth ? 16 : 86 })
        .borderRadius(16)
        .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
        .placeholderColor($r('app.color.doctor_workspace_text_tertiary'))
        .placeholderFont({ size: 15, weight: FontWeight.Regular })
        .textFont({ size: 15, weight: FontWeight.Regular })
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .searchIcon({
          size: 18,
          color: $r('app.color.doctor_workspace_text_secondary')
        })
        .keyboardShortcut('K', [ModifierKey.CTRL], () => this.openGlobalSearch())
        .onChange((value: string) => {
          this.searchText = value;
        })
      if (!this.compactWidth) {
        Row({ space: 5 }) {
          this.shortcutKey('Ctrl')
          this.shortcutKey('K')
        }
        .margin({ right: 16 })
      }
    }
    .width('100%')
    .height(56)
    .padding(4)
    .borderRadius(20)
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border_soft') })
  }

  @Builder
  private queueHeader(title: string, count: string, target: string) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(count)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width(24)
        .height(20)
        .padding({ left: 6, right: 6 })
        .textAlign(TextAlign.Center)
        .borderRadius(10)
        .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
      Blank()
        .layoutWeight(1)
      Text('···')
        .fontSize(16)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
    }
    .width('100%')
    .height(36)
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .onClick(() => {
      this.selectedNavId = target;
    })
  }

  @Builder
  private queueRow(item: DoctorQueueItem, symbol: Resource, target: string) {
    Row({ space: 10 }) {
      SymbolGlyph(symbol)
        .fontSize(17)
        .fontColor([item.tone === 'danger' ?
          $r('app.color.doctor_workspace_danger') :
          $r('app.color.doctor_workspace_text_tertiary')])
      Column({ space: 2 }) {
        Row({ space: 7 }) {
          Text(`${item.bed} · ${item.patient}`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .layoutWeight(1)
            .maxLines(1)
          Text(item.status)
            .fontSize(10)
            .fontColor(this.toneColor(item.tone))
            .maxLines(1)
        }
        .width('100%')
        Text(`${item.reason} · ${item.meta}`)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(10)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
    }
    .width('100%')
    .height(52)
    .padding({ left: 2, right: 2 })
    .backgroundColor(this.hoveredTarget === item.id ?
      $r('app.color.doctor_workspace_surface_hover') : Color.Transparent)
    .border({
      width: { bottom: 0.5 },
      color: { bottom: $r('app.color.doctor_workspace_border_soft') }
    })
    .alignItems(VerticalAlign.Center)
    .accessibilityText(`${item.bed} ${item.patient}，${item.reason}，${item.status}`)
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? item.id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.selectedNavId = target;
    }))
    .onClick(() => {
      this.selectedNavId = target;
    })
  }

  @Builder
  private queueColumn(title: string, count: string, items: DoctorQueueItem[], symbol: Resource, target: string) {
    Column() {
      this.queueHeader(title, count, target)
      ForEach(items, (item: DoctorQueueItem) => {
        this.queueRow(item, symbol, target)
      }, (item: DoctorQueueItem) => item.id)
    }
    .width('100%')
  }

  @Builder
  private analyticsHeader() {
    Row({ space: 8 }) {
      Text('Analytics')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Blank()
        .layoutWeight(1)
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.calendar_badge_clock'))
          .fontSize(15)
          .fontColor([$r('app.color.doctor_workspace_text_secondary')])
        Text('过去 24 小时')
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
      }
      .height(40)
      .padding({ left: 12, right: 12 })
      .borderRadius(11)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(15)
          .fontColor([$r('app.color.doctor_workspace_text_secondary')])
      }
      .width(40)
      .height(40)
      .borderRadius(11)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private chartBars(values: number[], accent: ResourceColor) {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.doctor_workspace_border_soft'))
        Blank()
          .layoutWeight(1)
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.doctor_workspace_border_soft'))
        Blank()
          .layoutWeight(1)
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.doctor_workspace_border_soft'))
      }
      .width('100%')
      .height(108)
      Row({ space: 7 }) {
        ForEach(values, (value: number, index: number) => {
          Column() {
            Blank()
              .layoutWeight(1)
            Row()
              .width('100%')
              .height(value)
              .borderRadius({ topLeft: 3, topRight: 3 })
              .backgroundColor(accent)
              .opacity(0.32 + index * 0.025)
          }
          .layoutWeight(1)
          .height(108)
          .justifyContent(FlexAlign.End)
        }, (value: number, index: number) => `${value}-${index}`)
      }
      .width('100%')
      .height(108)
      .padding({ left: 4, right: 4 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height(108)
  }

  @Builder
  private analyticsCard(
    title: string,
    value: string,
    unit: string,
    trend: string,
    values: number[],
    accent: ResourceColor
  ) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
          Text('数据截至 10:32 · 样本 12')
            .fontSize(9)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('···')
          .fontSize(16)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .width('100%')
      Row({ space: 8 }) {
        Text(value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text(unit)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .margin({ top: 11 })
        Text(trend)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_success'))
          .margin({ top: 11 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      this.chartBars(values, accent)
    }
    .width('100%')
    .height(240)
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dashboard() {
    Scroll() {
      Column() {
        Column({ space: 24 }) {
          this.heroPill()
          Text('今天先处理什么？')
            .fontSize(this.compactWidth ? 34 : 40)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .maxLines(1)
          this.heroSearch()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: this.compactWidth ? 78 : 128 })
        GridRow({ columns: 12, gutter: { x: 24, y: 24 } }) {
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.queueColumn(
              '待医生判断',
              '8',
              this.judgmentQueue,
              $r('sys.symbol.waveform_path_ecg_magnifyingglass'),
              'judgment'
            )
          }
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.queueColumn(
              '今日查房',
              '22',
              this.roundsQueue,
              $r('sys.symbol.calendar_badge_clock'),
              'rounds'
            )
          }
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.queueColumn(
              '待签署与复核',
              '11',
              this.reviewQueue,
              $r('sys.symbol.cross_text_clipboard'),
              'orders'
            )
          }
        }
        .width('100%')
        .margin({ top: 32 })
        Column({ space: 16 }) {
          this.analyticsHeader()
          GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
            GridCol({ span: 6 }) {
              this.analyticsCard(
                '重点患者风险趋势',
                '12',
                '位重点患者',
                '较昨日 +2',
                this.riskTrendValues,
                $r('app.color.doctor_workspace_focus')
              )
            }
            GridCol({ span: 6 }) {
              this.analyticsCard(
                '临床闭环概览',
                '86%',
                '今日完成率',
                '较昨日 +6.4%',
                this.closureTrendValues,
                $r('app.color.doctor_workspace_success')
              )
            }
          }
          .width('100%')
        }
        .width('100%')
        .margin({ top: this.compactWidth ? 64 : 72 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 1088 })
      .padding({ left: this.mainPadding(), right: this.mainPadding(), bottom: 72 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private statusTag(label: string, tone: string) {
    Text(label)
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.toneColor(tone))
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      .border({ width: 0.5, color: this.toneColor(tone) })
      .maxLines(1)
  }

  @Builder
  private moduleFilter(label: string, index: number) {
    Text(label)
      .fontSize(11)
      .fontWeight(this.moduleFilterIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.moduleFilterIndex === index ?
        $r('app.color.doctor_workspace_text_primary') :
        $r('app.color.doctor_workspace_text_secondary'))
      .height(34)
      .padding({ left: 14, right: 14 })
      .textAlign(TextAlign.Center)
      .borderRadius(10)
      .backgroundColor(this.moduleFilterIndex === index ?
        $r('app.color.doctor_workspace_surface_hover') : Color.Transparent)
      .focusable(true)
      .onClick(() => {
        this.moduleFilterIndex = index;
      })
  }

  @Builder
  private moduleTableHeader() {
    Row({ space: 12 }) {
      Text('患者 / 床位')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width(112)
      Text('事项')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .layoutWeight(1)
      Text('来源')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width(this.compactWidth ? 105 : 142)
      Text('状态')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width(70)
    }
    .width('100%')
    .height(40)
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private moduleTableRow(row: DoctorModuleRow) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(`${row.bed} · ${row.patient}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .maxLines(1)
        Text(row.updatedAt)
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .width(112)
      .alignItems(HorizontalAlign.Start)
      Text(row.item)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(row.source)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width(this.compactWidth ? 105 : 142)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Column() {
        this.statusTag(row.status, row.tone)
      }
      .width(70)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(68)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.selectedModuleRowId === row.id ?
      $r('app.color.doctor_workspace_surface_raised') :
      (this.hoveredTarget === row.id ? $r('app.color.doctor_workspace_surface_hover') : Color.Transparent))
    .border({
      width: { bottom: 0.5 },
      color: { bottom: $r('app.color.doctor_workspace_border_soft') }
    })
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? row.id : '')
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.selectedModuleRowId = row.id;
    }))
    .onClick(() => {
      this.selectedModuleRowId = row.id;
    })
  }

  @Builder
  private moduleListPanel() {
    Column() {
      Row({ space: 4 }) {
        this.moduleFilter('全部', 0)
        this.moduleFilter('待处理', 1)
        this.moduleFilter('已完成', 2)
        Blank()
          .layoutWeight(1)
        Text('共 28 项 · 最近更新 10:32')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 14 })
      .alignItems(VerticalAlign.Center)
      this.moduleTableHeader()
      ForEach(this.moduleRows, (row: DoctorModuleRow) => {
        this.moduleTableRow(row)
      }, (row: DoctorModuleRow) => row.id)
    }
    .width('100%')
    .borderRadius(16)
    .clip(true)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
  }

  @Builder
  private detailMetricRow(label: string, value: string, note: string, tone: string) {
    Row({ space: 10 }) {
      Row()
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(this.toneColor(tone))
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width(70)
      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .layoutWeight(1)
      Text(note)
        .fontSize(9)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
    }
    .width('100%')
    .height(30)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private patientDetailPanel(row: DoctorModuleRow) {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text(`${row.bed} · ${row.patient}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Text('男 · 72 岁 · 呼吸内科')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.statusTag(row.status, row.tone)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Column({ space: 8 }) {
        Text('当前事项')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .width('100%')
        Text(row.item)
          .fontSize(13)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .lineHeight(20)
          .width('100%')
        Text(`数据来源：${row.source} · ${row.updatedAt}`)
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .borderRadius(13)
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      .alignItems(HorizontalAlign.Start)
      Column({ space: 8 }) {
        Text('近期关键数据')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
        this.detailMetricRow('血氧', '91%', '较基线 -4%', 'danger')
        this.detailMetricRow('呼吸频率', '24 次/分', '近 2 小时上升', 'warning')
        this.detailMetricRow('体温', '37.6℃', '稳定', 'normal')
      }
      .width('100%')
      Column({ space: 8 }) {
        Row({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.AI_message'))
            .fontSize(16)
            .fontColor([$r('app.color.doctor_workspace_accent')])
          Text('AI 辅助摘要')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Blank()
          this.statusTag('待确认', 'warning')
        }
        .width('100%')
        Text('建议结合最近一次血气结果与肺部听诊记录复核。当前缺少 10:00 后的血气数据。')
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .lineHeight(18)
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .borderRadius(13)
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      Row({ space: 10 }) {
        Button('查看患者详情')
          .layoutWeight(1)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
        Button('加入待复核')
          .layoutWeight(1)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private moduleWorkspace() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text(this.currentTitle())
              .fontSize(this.compactWidth ? 24 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text(this.currentSubtitle())
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          this.statusTag('实时数据 · 10:32', 'normal')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
          GridCol({ span: this.compactWidth ? 12 : 8 }) {
            this.moduleListPanel()
          }
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.patientDetailPanel(this.selectedModuleRow())
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: 1400 })
      .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 24, bottom: 36 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private suggestedQuestion(label: string) {
    Row({ space: 7 }) {
      SymbolGlyph($r('sys.symbol.AI_message'))
        .fontSize(13)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .maxLines(1)
    }
    .height(36)
    .padding({ left: 11, right: 12 })
    .borderRadius(11)
    .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
    .focusable(true)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.aiQuestion = label;
    }))
    .onClick(() => {
      this.aiQuestion = label;
    })
  }

  @Builder
  private aiWorkspace() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('康小伴 AI 临床助手')
              .fontSize(this.compactWidth ? 24 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text('基于当前授权数据提供辅助信息，最终判断与签署始终由医生完成')
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          this.statusTag('独立医师会话', 'normal')
        }
        .width('100%')
        Row({ space: 8 }) {
          this.suggestedQuestion('汇总 3A 病区今天的异常趋势')
          this.suggestedQuestion('整理 3A-12 患者待复核证据')
          if (!this.compactWidth) {
            this.suggestedQuestion('生成查房记录草稿')
          }
        }
        .width('100%')
        Column({ space: 18 }) {
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width(36)
                .height(36)
                .borderRadius(12)
                .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
              Text('ZM')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
            }
            Text('请汇总 3A-12 患者血氧下降的关键证据，并指出还缺少哪些信息。')
              .fontSize(13)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .lineHeight(21)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          Divider()
            .strokeWidth(0.5)
            .color($r('app.color.doctor_workspace_border_soft'))
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width(36)
                .height(36)
                .borderRadius(12)
                .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
              SymbolGlyph($r('sys.symbol.AI_message'))
                .fontSize(17)
                .fontColor([$r('app.color.doctor_workspace_accent')])
            }
            Column({ space: 12 }) {
              Row() {
                Text('康小伴 AI')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Blank()
                this.statusTag('待医生确认', 'warning')
              }
              .width('100%')
              Text('当前可见证据显示：血氧从个人基线 95% 降至 91%，并持续约 20 分钟；同期呼吸频率由 19 次/分升至 24 次/分。护理记录提示咳痰增加。')
                .fontSize(13)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
                .lineHeight(22)
                .width('100%')
              Column({ space: 6 }) {
                Text('关键证据')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Text('• 床旁设备：SpO₂ 91%，10:11–10:31')
                  .fontSize(11)
                  .fontColor($r('app.color.doctor_workspace_text_secondary'))
                Text('• 护理记录：10:18 记录咳痰增加')
                  .fontSize(11)
                  .fontColor($r('app.color.doctor_workspace_text_secondary'))
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
              .alignItems(HorizontalAlign.Start)
              Text('缺失信息：10:00 后血气结果、最新肺部听诊记录。信息补齐前不建议形成确定性结论。')
                .fontSize(11)
                .fontColor($r('app.color.doctor_workspace_warning'))
                .lineHeight(18)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .padding(20)
        .borderRadius(16)
        .backgroundColor($r('app.color.doctor_workspace_surface'))
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
        Row({ space: 10 }) {
          TextArea({
            placeholder: '询问患者情况、结果趋势或生成待复核草稿…',
            text: this.aiQuestion
          })
            .layoutWeight(1)
            .height(68)
            .fontSize(13)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .placeholderColor($r('app.color.doctor_workspace_text_tertiary'))
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.aiQuestion = value;
            })
          Button() {
            SymbolGlyph($r('sys.symbol.arrow_up'))
              .fontSize(16)
              .fontColor([$r('app.color.doctor_workspace_background')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .enabled(this.aiQuestion.trim().length > 0)
          .opacity(this.aiQuestion.trim().length > 0 ? 1 : 0.42)
        }
        .width('100%')
        .padding({ left: 15, right: 11, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor($r('app.color.doctor_workspace_surface'))
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .constraintSize({ maxWidth: 1088 })
      .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 24, bottom: 36 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private currentContent() {
    if (this.selectedNavId === 'workspace') {
      this.dashboard()
    } else if (this.selectedNavId === 'ai') {
      this.aiWorkspace()
    } else {
      this.moduleWorkspace()
    }
  }

  build() {
    Row() {
      this.sidebar()
      Column() {
        this.topBar()
        Column() {
          this.currentContent()
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor($r('app.color.doctor_workspace_background'))
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.doctor_workspace_background'))
  }
}
