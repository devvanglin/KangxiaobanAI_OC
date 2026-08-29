// Copyright (c) 2026 Huawei Device Co., Ltd.
// Licensed under the Apache License, Version 2.0.

import { ColorMetrics, LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';
import { WideDoctorAdmission } from './WideDoctorAdmission';
import ApiClient from '../../network/ApiClient';
import AuthStore from '../../network/AuthStore';
import { BusinessStore } from '../../network/BusinessStore';
import { AiChatRequest, AiChatResponse, Alert, Assessment, Bed, CareTask, Elder, HealthRecord, MessageContact,
  MedicationRecord, Room, UserMessage } from '../../network/Dto';

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
  elderId?: number;
  patient: string;
  bed: string;
  reason: string;
  meta: string;
  status: string;
  tone: string;
}

interface DoctorModuleRow {
  id: string;
  elderId?: number;
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
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Param admissionCompactWidth: boolean = false;
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};
  @Local selectedNavId: string = 'workspace';
  @Local selectedModuleRowId: string = '';
  @Local moduleFilterIndex: number = 0;
  @Local admissionDraftDirty: boolean = false;
  @Local hoveredTarget: string = '';
  @Local searchText: string = '';
  @Local aiQuestion: string = '';
  @Local submittedAiQuestion: string = '';
  @Local aiAnswerText: string = '';
  @Local aiLoading: boolean = false;
  @Local patientSearchQuery: string = '';
  @Local businessStore: BusinessStore = BusinessStore.getShared();
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
    symbol: $r('sys.symbol.house_fill')
  };

  private navGroups: DoctorNavGroup[] = [
    {
      label: '长者',
      items: [
        { id: 'admission', label: '入住办理', symbol: $r('sys.symbol.person_badge_plus') },
        { id: 'patients', label: '长者档案', symbol: $r('sys.symbol.person_2_fill') },
        { id: 'focus', label: '风险关注', symbol: $r('sys.symbol.waveform_path_ecg_heart_fill') }
      ]
    },
    {
      label: '评估与计划',
      items: [
        { id: 'judgment', label: '综合评估', symbol: $r('sys.symbol.waveform_path_ecg_magnifyingglass') },
        { id: 'rounds', label: '今日养护巡查', symbol: $r('sys.symbol.calendar_badge_clock') },
        { id: 'orders', label: '用药安全', symbol: $r('sys.symbol.cross_text_clipboard') }
      ]
    },
    {
      label: '协同与连续照护',
      items: [
        { id: 'results', label: '异常处置与转介', symbol: $r('sys.symbol.cross_vial') },
        { id: 'consultation', label: '多专业协同', symbol: $r('sys.symbol.message_on_message_fill') }
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

  private recentPatients: DoctorRecentPatient[] = [];
  @Local judgmentQueue: DoctorQueueItem[] = [];
  @Local roundsQueue: DoctorQueueItem[] = [];
  @Local reviewQueue: DoctorQueueItem[] = [];
  @Local moduleRows: DoctorModuleRow[] = [];
  @Local patientRows: DoctorModuleRow[] = [];
  private riskTrendValues: number[] = [];
  private closureTrendValues: number[] = [];

  aboutToAppear(): void {
    this.loadWorkspaceData();
  }

  private async loadWorkspaceData(): Promise<void> {
    await this.businessStore.load();
    this.judgmentQueue = this.businessStore.assessments.map((item: Assessment): DoctorQueueItem => ({
      id: `assessment-${item.id}`,
      elderId: item.elder_id,
      patient: this.elderName(item.elder_id),
      bed: this.elderBed(item.elder_id),
      reason: item.notes || item.assessment_type,
      meta: this.timeText(item.assessed_at),
      status: item.risk_level === 'high' ? '高风险' : item.risk_level === 'medium' ? '需关注' : '已评估',
      tone: item.risk_level === 'high' ? 'danger' : item.risk_level === 'medium' ? 'warning' : 'normal'
    }));
    this.roundsQueue = this.businessStore.tasks
      .filter((item: CareTask) => item.status !== 'done')
      .map((item: CareTask): DoctorQueueItem => ({
        id: `task-${item.id}`,
        elderId: item.elder_id,
        patient: this.elderName(item.elder_id),
        bed: this.elderBed(item.elder_id),
        reason: item.title,
        meta: item.due_at ? this.timeText(item.due_at) : '--',
        status: item.status === 'doing' ? '进行中' : '待巡查',
        tone: item.status === 'doing' ? 'warning' : 'neutral'
      }));
    this.reviewQueue = this.businessStore.medications
      .filter((item: MedicationRecord) => item.status !== 'taken')
      .map((item: MedicationRecord): DoctorQueueItem => ({
        id: `medication-${item.id}`,
        elderId: item.elder_id,
        patient: this.elderName(item.elder_id),
        bed: this.elderBed(item.elder_id),
        reason: `${item.medicine_name} · ${item.dosage}`,
        meta: item.plan_time ? this.timeText(item.plan_time) : '--',
        status: '待复核',
        tone: 'warning'
      }));
    this.moduleRows = this.businessStore.alerts.map((item: Alert): DoctorModuleRow => ({
      id: `alert-${item.id}`,
      elderId: item.elder_id,
      patient: item.elder_id ? this.elderName(item.elder_id) : '机构设备',
      bed: item.elder_id ? this.elderBed(item.elder_id) : item.device_id,
      item: item.content,
      source: item.device_id || '服务器告警',
      updatedAt: this.timeText(item.create_time),
      status: item.status === 'closed' ? '已更新' : item.status === 'handled' ? '跟进中' : '待处理',
      tone: item.level === 'emergency' ? 'danger' : item.level === 'important' ? 'warning' : 'neutral'
    }));
    this.patientRows = this.businessStore.elders.map((item: Elder): DoctorModuleRow => ({
      id: `elder-${item.id}`,
      elderId: item.id,
      patient: item.name,
      bed: this.elderBed(item.id),
      item: item.remark || '暂无档案备注',
      source: '服务器长者档案',
      updatedAt: item.created_at ? this.timeText(item.created_at) : '--',
      status: item.status === 2 ? '在院' : item.status === 1 ? '登记' : '退住',
      tone: item.status === 2 ? 'normal' : 'neutral'
    }));
    const firstRow: DoctorModuleRow | undefined = this.rowsForCurrentModule()[0];
    this.selectedModuleRowId = firstRow?.id ?? '';
  }

  private elderName(elderId: number): string {
    return this.businessStore.elders.find((item: Elder) => item.id === elderId)?.name ?? '未知长者';
  }

  private elderBed(elderId: number): string {
    const elder: Elder | undefined = this.businessStore.elders.find((item: Elder) => item.id === elderId);
    const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === elder?.bed_id);
    const room: Room | undefined = bed ? this.businessStore.rooms.find((item: Room) => item.id === bed.room_id) : undefined;
    return bed && room ? `${room.building}${room.floor}F-${room.room_no}-${bed.bed_no}` : '未分配床位';
  }

  private timeText(value: string): string {
    return value.length >= 16 ? value.slice(0, 16) : value || '--';
  }

  private openRiskCount(): number {
    return this.businessStore.alerts.filter((item: Alert) =>
      item.status !== 'handled' && item.status !== 'closed').length;
  }

  private taskCompletionPercent(): number {
    const total: number = this.businessStore.tasks.length;
    if (total === 0) return 0;
    const done: number = this.businessStore.tasks.filter((item: CareTask) => item.status === 'done').length;
    return Math.round(done / total * 1000) / 10;
  }

  private sidebarWidth(): number {
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

  private queueAsModuleRows(queue: DoctorQueueItem[], source: string, prefix: string): DoctorModuleRow[] {
    return queue.map((item: DoctorQueueItem): DoctorModuleRow => ({
      id: `${prefix}-${item.id}`,
      elderId: item.elderId,
      patient: item.patient,
      bed: item.bed,
      item: item.reason,
      source: source,
      updatedAt: item.meta,
      status: item.status,
      tone: item.tone
    }));
  }

  /** Convert tenant-scoped user messages into the collaboration table rows. */
  private consultationRows(): DoctorModuleRow[] {
    const currentUserId: number | undefined = AuthStore.getUser()?.id;
    const messages: UserMessage[] = this.businessStore.messages
      .filter((message: UserMessage) => currentUserId === undefined ||
        message.sender_id === currentUserId || message.receiver_id === currentUserId)
      .sort((left: UserMessage, right: UserMessage): number => right.sent_at.localeCompare(left.sent_at));
    return messages.map((message: UserMessage): DoctorModuleRow => {
      const counterpartId: number = currentUserId !== undefined && message.sender_id === currentUserId ?
        message.receiver_id : message.sender_id;
      const contact: MessageContact | undefined = this.businessStore.messageContacts
        .find((item: MessageContact) => item.id === counterpartId);
      const elderId: number | undefined = message.elder_id;
      const patient: string = elderId === undefined ?
        (contact?.real_name || contact?.username || '协同联系人') : this.elderName(elderId);
      const bed: string = elderId === undefined ?
        (contact?.real_name || contact?.username || '未关联长者') : this.elderBed(elderId);
      const messageType: string = message.type.trim().length > 0 ? message.type : '协同消息';
      const isIncomingUnread: boolean = currentUserId !== undefined && message.receiver_id === currentUserId &&
        (message.read_at === undefined || message.read_at.trim().length === 0);
      return {
        id: `message-${message.id}`,
        elderId: elderId,
        patient: patient,
        bed: bed,
        item: message.content.trim().length > 0 ? message.content : '服务器未提供消息内容',
        source: `${contact?.real_name || contact?.username || messageType} · ${messageType}`,
        updatedAt: this.timeText(message.sent_at),
        status: isIncomingUnread ? '待处理' : '已更新',
        tone: isIncomingUnread ? 'warning' : 'normal'
      };
    });
  }

  private rowsForCurrentModule(): DoctorModuleRow[] {
    let rows: DoctorModuleRow[] = this.selectedNavId === 'patients' ? this.patientRows : this.moduleRows;
    if (this.selectedNavId === 'judgment') {
      rows = this.queueAsModuleRows(this.judgmentQueue, '综合评估 + 护理观察', 'judgment');
    } else if (this.selectedNavId === 'rounds') {
      rows = this.queueAsModuleRows(this.roundsQueue, '养护巡查计划', 'rounds');
    } else if (this.selectedNavId === 'orders') {
      rows = this.queueAsModuleRows(this.reviewQueue, '用药与协同记录', 'orders');
    } else if (this.selectedNavId === 'focus') {
      rows = rows.filter((row: DoctorModuleRow) => row.tone === 'danger' || row.tone === 'warning');
    } else if (this.selectedNavId === 'results') {
      rows = this.moduleRows;
    } else if (this.selectedNavId === 'consultation') {
      rows = this.consultationRows();
    } else if (this.selectedNavId === 'patients' && this.patientSearchQuery.length > 0) {
      rows = rows.filter((row: DoctorModuleRow) => {
        const searchText: string = `${row.patient} ${row.bed} ${row.item} ${row.source}`.toLowerCase();
        return searchText.includes(this.patientSearchQuery);
      });
    }
    if (this.moduleFilterIndex === 1) {
      return rows.filter((row: DoctorModuleRow) => row.status !== '已更新');
    }
    if (this.moduleFilterIndex === 2) {
      return rows.filter((row: DoctorModuleRow) => row.status === '已更新');
    }
    return rows;
  }

  private selectedModuleRow(): DoctorModuleRow | undefined {
    const visibleRows: DoctorModuleRow[] = this.rowsForCurrentModule();
    return visibleRows.find((row: DoctorModuleRow) => row.id === this.selectedModuleRowId) ?? visibleRows[0];
  }

  private openQueueItem(item: DoctorQueueItem, target: string): void {
    this.runAfterAdmissionGuard(() => {
      this.patientSearchQuery = '';
      this.selectedModuleRowId = `${target}-${item.id}`;
      this.moduleFilterIndex = 0;
      this.selectedNavId = target;
    });
  }

  private openRecentPatient(patient: DoctorRecentPatient): void {
    this.runAfterAdmissionGuard(() => {
      const matchedRow: DoctorModuleRow | undefined =
        this.patientRows.find((row: DoctorModuleRow) => row.bed === patient.bed);
      this.patientSearchQuery = '';
      this.moduleFilterIndex = 0;
      this.selectedModuleRowId = matchedRow?.id ?? this.patientRows[0]?.id ?? '';
      this.selectedNavId = 'patients';
    });
  }

  private navigateTo(target: string): void {
    if (target === this.selectedNavId) {
      if (target === 'patients' && this.patientSearchQuery.length > 0) {
        this.patientSearchQuery = '';
        this.moduleFilterIndex = 0;
        this.selectedModuleRowId = this.patientRows[0]?.id ?? '';
      }
      return;
    }
    this.runAfterAdmissionGuard(() => {
      this.patientSearchQuery = '';
      this.selectedNavId = target;
    });
  }

  private runAfterAdmissionGuard(action: () => void): void {
    if (this.selectedNavId !== 'admission' || !this.admissionDraftDirty) {
      action();
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
            fontColor: $r('app.color.doctor_workspace_danger'),
            action: () => {
              // Unmount the admission branch before external navigation so its local draft is actually discarded.
              this.admissionDraftDirty = false;
              this.selectedNavId = 'workspace';
              action();
            }
          }
        ]
      });
    } catch (_error) {
      // 对话框不可用时不执行外部跳转，避免静默丢失入住草稿。
    }
  }

  private async submitAiQuestion(): Promise<void> {
    const question: string = this.aiQuestion.trim();
    if (question.length === 0 || this.aiLoading) {
      return;
    }
    this.submittedAiQuestion = question;
    this.aiAnswerText = '';
    this.aiQuestion = '';
    this.aiLoading = true;
    try {
      const request: AiChatRequest = { question: question };
      const response = await ApiClient.post<AiChatResponse>('/ai/chat', request);
      this.aiAnswerText = response.code === 0 && response.data ? response.data.answer :
        (response.msg || 'AI 服务暂不可用');
    } catch (_error) {
      this.aiAnswerText = '无法连接 AI 服务，请稍后重试';
    }
    this.aiLoading = false;
  }

  private currentUserName(): string {
    const user = AuthStore.getUser();
    return user?.real_name || user?.username || '当前用户';
  }

  private currentUserInitial(): string {
    return this.currentUserName().slice(0, 1).toUpperCase();
  }

  private currentUserRole(): string {
    const user = AuthStore.getUser();
    if (!user || user.roles.length === 0) {
      return '未分配角色';
    }
    return user.roles.map((role) => role.name || role.code).join('、');
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      event.stopPropagation();
      action();
    }
  }

  private focusGlobalSearch(): void {
    try {
      this.focusController.requestFocus('doctor-global-search');
    } catch (_error) {
      // 焦点请求失败时保留当前工作状态。
    }
  }

  private openGlobalSearch(): void {
    if (this.selectedNavId !== 'workspace') {
      this.runAfterAdmissionGuard(() => {
        this.patientSearchQuery = '';
        this.selectedNavId = 'workspace';
        setTimeout(() => this.focusGlobalSearch(), 120);
      });
      return;
    }
    this.focusGlobalSearch();
  }

  private submitGlobalSearch(): void {
    const query: string = this.searchText.trim().toLowerCase();
    if (query.length === 0) {
      return;
    }
    const matchedRow: DoctorModuleRow | undefined = this.patientRows.find((row: DoctorModuleRow) => {
      const searchText: string = `${row.patient} ${row.bed} ${row.item} ${row.source}`.toLowerCase();
      return searchText.includes(query);
    });
    this.patientSearchQuery = query;
    this.moduleFilterIndex = 0;
    this.selectedModuleRowId = matchedRow?.id ?? '';
    this.selectedNavId = 'patients';
  }

  @Builder
  private recentPatientItem(patient: DoctorRecentPatient) {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
        .fontSize(18)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
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
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 10 })
    .borderRadius(10)
    .backgroundColor(this.hoveredTarget === patient.id ?
      $r('app.color.doctor_workspace_surface_hover') : Color.Transparent)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(`最近查看长者，${patient.bed} ${patient.displayName}`)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.openRecentPatient(patient);
    }))
    .onHover((isHover: boolean) => this.hoveredTarget = isHover ? patient.id : '')
    .onClick(() => {
      this.openRecentPatient(patient);
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
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 10 })
    .borderRadius(10)
    .backgroundColor(this.isActive(item.id) ?
      $r('app.color.doctor_workspace_surface_raised') :
      (this.hoveredTarget === item.id ? $r('app.color.doctor_workspace_surface_hover') : Color.Transparent))
    .justifyContent(FlexAlign.Start)
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
      this.navigateTo(item.id);
    }))
    .onClick(() => {
      this.navigateTo(item.id);
    })
  }

  @Builder
  private sidebarGroupTitle(label: string) {
    Text(label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      .width('100%')
      .margin({ left: 2, top: 8, bottom: 5 })
  }

  @Builder
  private sidebarNavigation() {
    Scroll(this.sidebarScroller) {
      Column({ space: 3 }) {
        this.sidebarNavItem(this.homeNavItem)
        this.sidebarGroupTitle('最近查看长者')
        ForEach(this.recentPatients, (patient: DoctorRecentPatient) => {
          this.recentPatientItem(patient)
        }, (patient: DoctorRecentPatient) => patient.id)
        ForEach(this.navGroups, (group: DoctorNavGroup, groupIndex: number) => {
          Column({ space: 3 }) {
            this.sidebarGroupTitle(group.label)
            ForEach(group.items, (item: DoctorNavItem) => {
              this.sidebarNavItem(item)
            }, (item: DoctorNavItem) => item.id)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (group: DoctorNavGroup, index: number) => `${group.label}-${index}`)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 14, bottom: 12 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private sidebar() {
    Column() {
      this.sidebarNavigation()
    }
    .width(this.sidebarWidth())
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor($r('app.color.doctor_workspace_background'))
    .border({
      width: { right: 0.5 },
      color: { right: $r('app.color.doctor_workspace_border_soft') }
    })
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
        Text(this.currentUserInitial())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
      }
      Column({ space: 3 }) {
        Text(this.currentUserName())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text(this.currentUserRole())
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
          .onClick(() => this.runAfterAdmissionGuard(this.onOpenGeneral))
        MenuItem({ symbolStartIcon: this.aboutIcon, content: '关于我们' })
          .height(46)
          .onClick(() => this.runAfterAdmissionGuard(this.onOpenAbout))
      }
      MenuItemGroup() {
        MenuItem({ symbolStartIcon: this.logoutIcon, content: '退出登录' })
          .height(46)
          .contentFontColor($r('app.color.doctor_workspace_danger'))
          .onClick(() => this.runAfterAdmissionGuard(this.onLogout))
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
      Text(this.currentUserInitial())
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
        this.navigateTo('ai');
      })
      this.topTextAction('doctor-help', '支持', $r('sys.symbol.questionmark_circle'), () => {
        this.runAfterAdmissionGuard(this.onOpenAbout);
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
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.navigateTo('ai')))
    .onClick(() => {
      this.navigateTo('ai');
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
        .onSubmit((value: string) => {
          this.searchText = value;
          this.submitGlobalSearch();
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
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(12)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
    }
    .width('100%')
    .height(36)
    .alignItems(VerticalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .focusable(true)
    .focusOnTouch(true)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.navigateTo(target)))
    .onClick(() => {
      this.navigateTo(target);
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
      if (items.length === 0) {
        Text(this.businessStore.loading ? '正在加载服务器数据' : '暂无待处理记录')
          .width('100%')
          .height(76)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .textAlign(TextAlign.Center)
      } else {
        ForEach(items, (item: DoctorQueueItem) => {
          this.queueRow(item, symbol, target)
        }, (item: DoctorQueueItem) => item.id)
      }
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
        Text('服务器实时统计')
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
          Text('服务器数据')
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
      if (values.length > 0) {
        this.chartBars(values, accent)
      } else {
        Text('暂无历史趋势数据')
          .width('100%')
          .height(108)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .textAlign(TextAlign.Center)
      }
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
              this.judgmentQueue.length.toString(),
              this.judgmentQueue,
              $r('sys.symbol.waveform_path_ecg_magnifyingglass'),
              'judgment'
            )
          }
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.queueColumn(
              '今日巡查与计划',
              this.roundsQueue.length.toString(),
              this.roundsQueue,
              $r('sys.symbol.calendar_badge_clock'),
              'rounds'
            )
          }
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.queueColumn(
              '待复核与协同',
              this.reviewQueue.length.toString(),
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
                this.openRiskCount().toString(),
                '项待闭环风险',
                '实时',
                $r('app.color.doctor_workspace_warning'),
                this.riskTrendValues,
                $r('app.color.doctor_workspace_focus')
              )
            }
            GridCol({ span: 6 }) {
              this.analyticsCard(
                '照护计划闭环',
                `${this.taskCompletionPercent()}%`,
                '任务完成率',
                '实时',
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
      .padding({
        left: this.mainPadding(),
        right: this.mainPadding(),
        bottom: 72 + this.naviIndicatorHeight
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
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
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilitySelected(this.moduleFilterIndex === index)
      .focusable(true)
      .focusOnTouch(true)
      .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
        this.moduleFilterIndex = index;
      }))
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
        Text(`共 ${this.rowsForCurrentModule().length} 项 · 服务器数据`)
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

  private latestHealth(row: DoctorModuleRow): HealthRecord | undefined {
    if (!row.elderId) {
      return undefined;
    }
    return this.businessStore.healthRecords
      .filter((item: HealthRecord) => item.elder_id === row.elderId)
      .sort((left: HealthRecord, right: HealthRecord): number =>
        right.record_time.localeCompare(left.record_time))[0];
  }

  private metricValue(value: number | undefined, suffix: string): string {
    return value === undefined ? '未记录' : `${value}${suffix}`;
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
          Text('服务器业务记录')
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
        if (this.latestHealth(row)) {
          this.detailMetricRow('血氧', this.metricValue(this.latestHealth(row)!.spo2, '%'),
            this.timeText(this.latestHealth(row)!.record_time), this.latestHealth(row)!.is_abnormal ? 'danger' : 'normal')
          this.detailMetricRow('心率', this.metricValue(this.latestHealth(row)!.heart_rate, ' 次/分'),
            '服务器记录', this.latestHealth(row)!.is_abnormal ? 'warning' : 'normal')
          this.detailMetricRow('体温', this.metricValue(this.latestHealth(row)!.temperature, '℃'),
            '服务器记录', this.latestHealth(row)!.is_abnormal ? 'warning' : 'normal')
        } else {
          Text('暂无健康记录')
            .width('100%')
            .padding({ top: 14, bottom: 14 })
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      Row({ space: 10 }) {
        Button('查看长者档案')
          .layoutWeight(1)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .onClick(() => {
            this.navigateTo('patients');
            this.moduleFilterIndex = 0;
          })
        Button('跟进接口待接入')
          .layoutWeight(1)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .enabled(false)
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
          Text(this.currentTitle())
            .fontSize(this.compactWidth ? 22 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
          GridCol({ span: this.compactWidth || this.rowsForCurrentModule().length === 0 ? 12 : 8 }) {
            this.moduleListPanel()
          }
          if (this.rowsForCurrentModule().length > 0) {
            GridCol({ span: this.compactWidth ? 12 : 4 }) {
              this.patientDetailPanel(this.selectedModuleRow()!)
            }
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: 1400 })
      .padding({
        left: this.mainPadding(),
        right: this.mainPadding(),
        top: 24,
        bottom: 36 + this.naviIndicatorHeight
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
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
          Text('康小伴 AI 养护评估助手')
            .fontSize(this.compactWidth ? 22 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
        }
        .width('100%')
        Row({ space: 8 }) {
          this.suggestedQuestion('汇总今日风险趋势')
          this.suggestedQuestion('整理长者养护证据')
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
              Text(this.currentUserInitial())
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
            }
            Text(this.submittedAiQuestion.length > 0 ? this.submittedAiQuestion : '尚未提问')
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
                this.statusTag(this.aiLoading ? '生成中' : '待医师确认', 'warning')
              }
              .width('100%')
              Text(this.aiLoading ? '正在请求服务器 AI 服务…' :
                (this.aiAnswerText.length > 0 ? this.aiAnswerText : '输入问题后，服务器返回的回答会显示在这里。'))
                .fontSize(13)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
                .lineHeight(22)
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
            .barState(BarState.Off)
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
          .enabled(this.aiQuestion.trim().length > 0 && !this.aiLoading)
          .opacity(this.aiQuestion.trim().length > 0 && !this.aiLoading ? 1 : 0.42)
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
      .padding({
        left: this.mainPadding(),
        right: this.mainPadding(),
        top: 24,
        bottom: 36 + this.naviIndicatorHeight
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
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
        compactWidth: this.admissionCompactWidth,
        naviIndicatorHeight: this.naviIndicatorHeight,
        onDirtyChange: (dirty: boolean) => {
          this.admissionDraftDirty = dirty;
        },
        onExit: () => {
          this.admissionDraftDirty = false;
          this.selectedNavId = 'workspace';
          this.loadWorkspaceData();
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
