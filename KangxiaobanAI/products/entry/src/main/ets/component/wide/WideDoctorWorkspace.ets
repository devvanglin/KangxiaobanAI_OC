// Copyright (c) 2026 Huawei Device Co., Ltd.
// Licensed under the Apache License, Version 2.0.

import { ColorMetrics, LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { WindowUtil } from '../../util/WindowUtil';
import { WideDoctorAdmission } from './WideDoctorAdmission';

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
  @Local submittedAiQuestion: string = '请汇总 3A-12 长者近期风险变化，并指出评估还缺少哪些信息。';
  @Local aiAnswerText: string =
    '当前可见证据显示：血氧较个人基线下降，活动后恢复变慢；护理记录提示进食量下降、夜间睡眠中断。';
  @Local followUpRowIds: string[] = [];
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
    label: '养护总览',
    symbol: $r('sys.symbol.house_fill'),
    badge: '8'
  };

  private navGroups: DoctorNavGroup[] = [
    {
      label: '长者',
      items: [
        { id: 'admission', label: '入住办理', symbol: $r('sys.symbol.person_badge_plus') },
        { id: 'patients', label: '长者档案', symbol: $r('sys.symbol.person_2_fill') },
        { id: 'focus', label: '风险关注', symbol: $r('sys.symbol.waveform_path_ecg_heart_fill'), badge: '4' }
      ]
    },
    {
      label: '评估与计划',
      items: [
        { id: 'judgment', label: '综合评估', symbol: $r('sys.symbol.waveform_path_ecg_magnifyingglass'), badge: '8' },
        { id: 'rounds', label: '今日养护巡查', symbol: $r('sys.symbol.calendar_badge_clock'), badge: '22' },
        { id: 'orders', label: '用药安全', symbol: $r('sys.symbol.cross_text_clipboard'), badge: '5' }
      ]
    },
    {
      label: '协同与连续照护',
      items: [
        { id: 'results', label: '异常处置与转介', symbol: $r('sys.symbol.cross_vial'), badge: '6' },
        { id: 'consultation', label: '多专业协同', symbol: $r('sys.symbol.message_on_message_fill'), badge: '3' }
      ]
    },
    {
      label: '数据支持',
      items: [
        { id: 'analysis', label: '养护质量', symbol: $r('sys.symbol.waveform_path_ecg_square') },
        { id: 'ai', label: '养护助手', symbol: $r('sys.symbol.AI_message') }
      ]
    }
  ];

  private recentPatients: DoctorRecentPatient[] = [
    { id: 'recent-01', bed: '3A-12', displayName: '刘*', visitedAt: '10:24' },
    { id: 'recent-02', bed: '2B-06', displayName: '周*', visitedAt: '09:48' },
    { id: 'recent-03', bed: '5A-03', displayName: '陈*', visitedAt: '昨天' }
  ];

  private judgmentQueue: DoctorQueueItem[] = [
    { id: 'judge-01', patient: '刘*', bed: '3A-12', reason: '夜间血氧连续低于个人基线', meta: '等待 38 分钟', status: '优先跟进', tone: 'danger' },
    { id: 'judge-02', patient: '王*', bed: '3A-08', reason: '静息心率较基线升高 28%', meta: '等待 24 分钟', status: '重点关注', tone: 'warning' },
    { id: 'judge-03', patient: '陈*', bed: '5A-03', reason: '餐后血糖与饮食记录不匹配', meta: '等待 16 分钟', status: '待评估', tone: 'neutral' },
    { id: 'judge-04', patient: '赵*', bed: '2B-11', reason: '夜间体温异常，需要补充观察', meta: '等待 9 分钟', status: '待评估', tone: 'neutral' },
    { id: 'judge-05', patient: '何*', bed: '5A-05', reason: '血压较个人基线持续升高', meta: '等待 6 分钟', status: '待评估', tone: 'neutral' }
  ];

  private roundsQueue: DoctorQueueItem[] = [
    { id: 'round-01', patient: '周*', bed: '2B-06', reason: '伤口、活动耐力与营养风险评估', meta: '10:40', status: '即将开始', tone: 'warning' },
    { id: 'round-02', patient: '李*', bed: '2B-09', reason: '呼吸训练效果与疼痛变化', meta: '11:00', status: '待巡查', tone: 'neutral' },
    { id: 'round-03', patient: '孙*', bed: '3A-02', reason: '慢病方案与功能状态复评', meta: '11:20', status: '待巡查', tone: 'neutral' },
    { id: 'round-04', patient: '何*', bed: '5A-05', reason: '血糖方案调整后的饮食与活动复评', meta: '11:40', status: '待巡查', tone: 'neutral' },
    { id: 'round-05', patient: '赵*', bed: '2B-11', reason: '夜间异常与睡眠情况复盘', meta: '12:00', status: '待巡查', tone: 'neutral' }
  ];

  private reviewQueue: DoctorQueueItem[] = [
    { id: 'review-01', patient: '刘*', bed: '3A-12', reason: '用药方案与相互作用复核', meta: '10:18', status: '待确认', tone: 'warning' },
    { id: 'review-02', patient: '陈*', bed: '5A-03', reason: '血糖趋势与饮食记录复核', meta: '10:05', status: '待复核', tone: 'danger' },
    { id: 'review-03', patient: '周*', bed: '2B-06', reason: '康复与功能评估记录回传', meta: '09:56', status: '待复核', tone: 'neutral' },
    { id: 'review-04', patient: '王*', bed: '3A-08', reason: '护理团队协同意见', meta: '09:42', status: '待协同', tone: 'neutral' },
    { id: 'review-05', patient: '李*', bed: '2B-09', reason: '镇痛与睡眠方案复核', meta: '09:30', status: '待确认', tone: 'neutral' }
  ];

  private moduleRows: DoctorModuleRow[] = [
    { id: 'case-01', patient: '刘*', bed: '3A-12', item: '血氧下降，需结合呼吸状态与护理观察复核', source: '床旁设备 + 护理记录', updatedAt: '10:32', status: '优先跟进', tone: 'danger' },
    { id: 'case-02', patient: '王*', bed: '3A-08', item: '静息心率较个人基线上升，建议复测并观察活动耐力', source: '床旁设备 + 巡查记录', updatedAt: '10:28', status: '重点关注', tone: 'warning' },
    { id: 'case-03', patient: '陈*', bed: '5A-03', item: '餐后血糖异常，等待用药与饮食方案复核', source: '血糖仪 + 膳食记录', updatedAt: '10:21', status: '待处理', tone: 'neutral' },
    { id: 'case-04', patient: '赵*', bed: '2B-11', item: '夜间体温异常，需要补充睡眠与感染风险观察', source: '体温单 + 护理记录', updatedAt: '10:12', status: '待处理', tone: 'neutral' },
    { id: 'case-05', patient: '周*', bed: '2B-06', item: '功能评估记录已回传，等待更新养护计划', source: '康复记录', updatedAt: '09:56', status: '待复核', tone: 'neutral' },
    { id: 'case-06', patient: '何*', bed: '5A-05', item: '调整方案后血糖趋势趋稳，继续观察依从性', source: '血糖仪 + 用药记录', updatedAt: '09:36', status: '已更新', tone: 'normal' }
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
    return this.compactWidth ? 236 : 264;
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
    return '养护总览';
  }

  private currentSubtitle(): string {
    if (this.selectedNavId === 'patients' || this.selectedNavId === 'focus') {
      return '按授权范围查看长者档案、照护等级与近期健康记录';
    }
    if (this.selectedNavId === 'rounds') {
      return '按养护计划安排今日巡查、功能观察与异常跟进';
    }
    if (this.selectedNavId === 'judgment') {
      return '结合 ADL、认知、营养、慢病与安全风险完成综合评估';
    }
    if (this.selectedNavId === 'orders') {
      return '复核用药、照护方案与执行反馈，保留确认记录';
    }
    if (this.selectedNavId === 'results') {
      return '汇总异常线索、处置记录与转介进度，保障连续照护';
    }
    if (this.selectedNavId === 'consultation') {
      return '集中处理护理、康复、营养与家属沟通协同';
    }
    if (this.selectedNavId === 'analysis') {
      return '关注功能维持、评估完成、用药核对与风险闭环质量';
    }
    return '按风险、等待时长与养护计划节点排序';
  }

  private queueAsModuleRows(queue: DoctorQueueItem[], source: string, prefix: string): DoctorModuleRow[] {
    return queue.map((item: DoctorQueueItem): DoctorModuleRow => ({
      id: `${prefix}-${item.id}`,
      patient: item.patient,
      bed: item.bed,
      item: item.reason,
      source: source,
      updatedAt: item.meta,
      status: item.status,
      tone: item.tone
    }));
  }

  private rowsForCurrentModule(): DoctorModuleRow[] {
    let rows: DoctorModuleRow[] = this.moduleRows;
    if (this.selectedNavId === 'judgment') {
      rows = this.queueAsModuleRows(this.judgmentQueue, '综合评估 + 护理观察', 'judgment');
    } else if (this.selectedNavId === 'rounds') {
      rows = this.queueAsModuleRows(this.roundsQueue, '养护巡查计划', 'rounds');
    } else if (this.selectedNavId === 'orders') {
      rows = this.queueAsModuleRows(this.reviewQueue, '用药与协同记录', 'orders');
    } else if (this.selectedNavId === 'focus') {
      rows = rows.filter((row: DoctorModuleRow) => row.tone === 'danger' || row.tone === 'warning');
    } else if (this.selectedNavId === 'results') {
      rows = rows.filter((row: DoctorModuleRow) => row.id === 'case-02' || row.id === 'case-04' || row.id === 'case-05');
    } else if (this.selectedNavId === 'consultation') {
      rows = rows.filter((row: DoctorModuleRow) => row.id === 'case-04' || row.id === 'case-05');
    }
    if (this.moduleFilterIndex === 1) {
      return rows.filter((row: DoctorModuleRow) => row.status !== '已更新');
    }
    if (this.moduleFilterIndex === 2) {
      return rows.filter((row: DoctorModuleRow) => row.status === '已更新');
    }
    return rows;
  }

  private selectedModuleRow(): DoctorModuleRow {
    const visibleRows: DoctorModuleRow[] = this.rowsForCurrentModule();
    return visibleRows.find((row: DoctorModuleRow) => row.id === this.selectedModuleRowId) ??
      visibleRows[0] ?? this.moduleRows[0];
  }

  private openQueueItem(item: DoctorQueueItem, target: string): void {
    this.selectedModuleRowId = `${target}-${item.id}`;
    this.moduleFilterIndex = 0;
    this.selectedNavId = target;
  }

  private isFollowedUp(rowId: string): boolean {
    return this.followUpRowIds.indexOf(rowId) >= 0;
  }

  private toggleFollowUp(rowId: string): void {
    if (this.isFollowedUp(rowId)) {
      this.followUpRowIds = this.followUpRowIds.filter((id: string) => id !== rowId);
      return;
    }
    this.followUpRowIds = [...this.followUpRowIds, rowId];
  }

  private submitAiQuestion(): void {
    const question: string = this.aiQuestion.trim();
    if (question.length === 0) {
      return;
    }
    this.submittedAiQuestion = question;
    this.aiAnswerText =
      '已按当前本地演示数据整理养护线索。请补充最新综合评估、用药依从性与护理观察，并由医师确认后再更新养护计划。';
    this.aiQuestion = '';
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
    .accessibilityText(`最近查看长者，${patient.bed} ${patient.displayName}`)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.selectedNavId = 'patients';
    }))
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
          this.sidebarGroupTitle('最近查看长者')
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
            Text('演示数据 · 本地')
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
            Text('样例时间 10:32')
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
      Column() {
        this.quickSearch()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })
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
        Text('养老医师 · 养护评估')
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
    .accessibilityText('医师账户菜单')
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
      this.topTextAction('doctor-ai-top', '养护助手', $r('sys.symbol.AI_message'), () => {
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
      Text('康小伴 · 养老养护工作台')
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
      Search({ value: this.searchText, placeholder: '搜索长者、房间/床位、评估记录或用药计划' })
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
      this.openQueueItem(item, target);
    }))
    .onClick(() => {
      this.openQueueItem(item, target);
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
      Text('养护数据')
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
    trendColor: ResourceColor,
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
          Text('本地演示 · 12 位长者')
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
          .fontColor(trendColor)
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
        Column({ space: 18 }) {
          this.heroPill()
          Text('今天先关注哪些长者？')
            .fontSize(this.compactWidth ? 30 : 34)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .maxLines(1)
          this.heroSearch()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: this.compactWidth ? 52 : 76 })
        GridRow({ columns: 12, gutter: { x: 24, y: 24 } }) {
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.queueColumn(
              '待评估与风险',
              '8',
              this.judgmentQueue,
              $r('sys.symbol.waveform_path_ecg_magnifyingglass'),
              'judgment'
            )
          }
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.queueColumn(
              '今日巡查与计划',
              '22',
              this.roundsQueue,
              $r('sys.symbol.calendar_badge_clock'),
              'rounds'
            )
          }
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.queueColumn(
              '待复核与协同',
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
                '重点长者风险趋势',
                '12',
                '位重点长者',
                '较昨日 +2',
                $r('app.color.doctor_workspace_warning'),
                this.riskTrendValues,
                $r('app.color.doctor_workspace_focus')
              )
            }
            GridCol({ span: 6 }) {
              this.analyticsCard(
                '照护计划闭环',
                '86%',
                '今日完成率',
                '较昨日 +6.4%',
                $r('app.color.doctor_workspace_success'),
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
        Text('长者 / 房间·床位')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width(112)
        Text('养护 / 评估事项')
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
  private moduleEmptyState() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(28)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
      Text('暂无符合条件的养护事项')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text('可切换筛选条件查看其它记录')
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
    }
    .width('100%')
    .height(180)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
        Text(`共 ${this.rowsForCurrentModule().length} 项 · 本地演示数据`)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 14 })
      .alignItems(VerticalAlign.Center)
      this.moduleTableHeader()
      if (this.rowsForCurrentModule().length === 0) {
        this.moduleEmptyState()
      } else {
        ForEach(this.rowsForCurrentModule(), (row: DoctorModuleRow) => {
          this.moduleTableRow(row)
        }, (row: DoctorModuleRow) => row.id)
      }
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
          Text('男 · 72 岁 · 重点养护 · 需关注慢病趋势')
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
        Text('当前养护关注')
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
        Text('近期健康指标')
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
        Text('建议结合近两次生命体征、护理观察与活动耐力记录复核。当前仍缺少最新功能评估信息。')
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
        Button('查看长者档案')
          .layoutWeight(1)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .onClick(() => {
            this.selectedNavId = 'patients';
            this.moduleFilterIndex = 0;
          })
        Button(this.isFollowedUp(row.id) ? '已加入养护跟进' : '加入养护跟进')
          .layoutWeight(1)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .onClick(() => this.toggleFollowUp(row.id))
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
          GridCol({ span: this.compactWidth || this.rowsForCurrentModule().length === 0 ? 12 : 8 }) {
            this.moduleListPanel()
          }
          if (this.rowsForCurrentModule().length > 0) {
            GridCol({ span: this.compactWidth ? 12 : 4 }) {
              this.patientDetailPanel(this.selectedModuleRow())
            }
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
            Text('康小伴 AI 养护评估助手')
              .fontSize(this.compactWidth ? 24 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text('整理养护证据与风险线索，方案由医师确认并与护理团队协同')
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          this.statusTag('养护评估会话', 'normal')
        }
        .width('100%')
        Row({ space: 8 }) {
          this.suggestedQuestion('汇总 3A 养护区今日风险趋势')
          this.suggestedQuestion('整理 3A-12 长者养护证据')
          if (!this.compactWidth) {
            this.suggestedQuestion('生成养护巡查记录草稿')
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
            Text(this.submittedAiQuestion)
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
                Text('康小伴 AI · 养护提示')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Blank()
                this.statusTag('待医师确认', 'warning')
              }
              .width('100%')
              Text(this.aiAnswerText)
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
                Text('• 护理记录：10:18 记录进食量下降')
                  .fontSize(11)
                  .fontColor($r('app.color.doctor_workspace_text_secondary'))
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
              .alignItems(HorizontalAlign.Start)
              Text('待补信息：最新 ADL/营养评估、用药依从性与护理观察。信息补齐前不形成确定性结论。')
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
            placeholder: '询问长者养护情况、评估趋势或生成待确认记录…',
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
          .onClick(() => this.submitAiQuestion())
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
    } else if (this.selectedNavId === 'admission') {
      WideDoctorAdmission({
        compactWidth: this.compactWidth,
        onExit: () => {
          this.selectedNavId = 'patients';
          this.moduleFilterIndex = 0;
        }
      })
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
