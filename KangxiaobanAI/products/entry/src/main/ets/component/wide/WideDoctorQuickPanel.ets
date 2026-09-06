import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Assessment, Bed, Bill, CareTask, Elder, Room, Schedule } from '../../network/Dto';

interface QuickMetric {
  label: string;
  value: string;
  tone: ResourceColor;
}

interface QuickFilterOption {
  key: string;
  label: string;
}

/**
 * 医师工作台「常用功能」子页：床位预览 / 护理任务 / 告警处理 / 健康评估 / 账单管理 / 日常总览。
 * 全部为只读视图，数据来自 BusinessStore 的服务器快照，空数据不会生成本地演示记录。
 */
@ComponentV2
export struct WideDoctorQuickPanel {
  @Param kind: string = '';
  @Param compactWidth: boolean = false;
  @Event onBack: () => void = () => {};
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local taskFilter: string = 'all';
  @Local alertFilter: string = 'all';
  @Local billFilter: string = 'all';
  @Local scheduleShift: string = 'all';
  private scroller: Scroller = new Scroller();

  private title(): string {
    switch (this.kind) {
      case 'beds': return '床位预览';
      case 'tasks': return '护理任务';
      case 'alerts': return '告警处理';
      case 'assessment': return '健康评估';
      case 'billing': return '账单管理';
      case 'schedule': return '日常总览';
      default: return '医师工作模块';
    }
  }

  private subtitle(): string {
    switch (this.kind) {
      case 'beds': return `${this.businessStore.beds.length} 张床位 · ${this.businessStore.rooms.length} 间房间`;
      case 'tasks': return `${this.businessStore.tasks.length} 项护理任务`;
      case 'alerts': return `${this.businessStore.alerts.length} 条告警记录`;
      case 'assessment': return `${this.businessStore.assessments.length} 份健康评估`;
      case 'billing': return `${this.businessStore.bills.length} 张账单`;
      case 'schedule': return `${this.businessStore.schedules.length} 条排班记录`;
      default: return '以下数据来自服务器当前快照';
    }
  }

  private elderName(elderId?: number): string {
    if (elderId === undefined || elderId === 0) {
      return '未关联长者';
    }
    return this.businessStore.elders.find((item: Elder) => item.id === elderId)?.name ?? '未关联长者';
  }

  private elderLocation(elderId?: number): string {
    const elder: Elder | undefined = elderId === undefined ? undefined :
      this.businessStore.elders.find((item: Elder) => item.id === elderId);
    const bed: Bed | undefined = elder === undefined ? undefined :
      this.businessStore.beds.find((item: Bed) => item.id === elder.bed_id);
    const room: Room | undefined = bed === undefined ? undefined :
      this.businessStore.rooms.find((item: Room) => item.id === bed.room_id);
    return bed !== undefined && room !== undefined ? `${room.building}${room.floor}F-${room.room_no}-${bed.bed_no}` : '未分配床位';
  }

  private roomLabel(room: Room): string {
    return `${room.building}${room.floor}F · ${room.room_no}`;
  }

  private bedStatusText(status: string): string {
    return status === 'occupied' ? '已入住' : status === 'maintenance' ? '维护中' : '空闲';
  }

  private bedStatusTone(status: string): ResourceColor {
    return status === 'occupied' ? $r('app.color.doctor_workspace_focus') :
      status === 'maintenance' ? $r('sys.color.font_tertiary') : $r('app.color.doctor_workspace_success');
  }

  private taskStatusText(status: string): string {
    return status === 'todo' ? '待处理' : status === 'doing' ? '进行中' : '已完成';
  }

  private taskStatusTone(status: string): ResourceColor {
    return status === 'todo' ? $r('app.color.doctor_workspace_danger') :
      status === 'doing' ? $r('app.color.doctor_workspace_warning') : $r('app.color.doctor_workspace_success');
  }

  private alertStatusText(status: string): string {
    return status === 'closed' ? '已复核' : status === 'handled' ? '复核中' : '待复核';
  }

  private alertStatusTone(status: string): ResourceColor {
    return status === 'closed' ? $r('app.color.doctor_workspace_success') :
      status === 'handled' ? $r('app.color.doctor_workspace_warning') : $r('app.color.doctor_workspace_danger');
  }

  private alertLevelText(level: string): string {
    return level === 'emergency' ? '紧急' : level === 'important' ? '重要' : '一般';
  }

  private riskText(risk: string): string {
    if (risk === 'high' || risk === 'danger') {
      return '高风险';
    }
    return risk === 'medium' || risk === 'warning' ? '中风险' : risk === 'low' ? '低风险' : (risk || '--');
  }

  private riskTone(risk: string): ResourceColor {
    if (risk === 'high' || risk === 'danger') {
      return $r('app.color.doctor_workspace_danger');
    }
    return risk === 'medium' || risk === 'warning' ? $r('app.color.doctor_workspace_warning') :
      $r('app.color.doctor_workspace_success');
  }

  private shiftText(shift: string): string {
    return shift === 'morning' ? '白班' : shift === 'afternoon' ? '晚班' : shift === 'night' ? '夜班' : (shift || '--');
  }

  private todayKey(): string {
    const now: Date = new Date();
    const pad = (v: number): string => v.toString().padStart(2, '0');
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  }

  private filteredTasks(): CareTask[] {
    if (this.taskFilter === 'all') {
      return this.businessStore.tasks;
    }
    return this.businessStore.tasks.filter((item: CareTask) => item.status === this.taskFilter);
  }

  private filteredAlerts(): Alert[] {
    if (this.alertFilter === 'all') {
      return this.businessStore.alerts;
    }
    return this.businessStore.alerts.filter((item: Alert) => item.status === this.alertFilter);
  }

  private filteredBills(): Bill[] {
    if (this.billFilter === 'all') {
      return this.businessStore.bills;
    }
    return this.businessStore.bills.filter((item: Bill) => item.status === this.billFilter);
  }

  private filteredSchedules(): Schedule[] {
    if (this.scheduleShift === 'all') {
      return this.businessStore.schedules;
    }
    return this.businessStore.schedules.filter((item: Schedule) => item.shift === this.scheduleShift);
  }

  private taskCount(status: string): number {
    return this.businessStore.tasks.filter((item: CareTask) => item.status === status).length;
  }

  private alertCount(status: string): number {
    return this.businessStore.alerts.filter((item: Alert) => item.status === status).length;
  }

  private billTotal(filter: (bill: Bill) => boolean): number {
    return Math.round(this.businessStore.bills.filter(filter).reduce((sum: number, bill: Bill) => sum + bill.amount, 0));
  }

  @Builder
  private metricChip(item: QuickMetric) {
    Column({ space: 4 }) {
      Text(item.value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(item.label)
        .fontSize(11)
        .fontColor(item.tone)
    }
    .layoutWeight(1)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(12)
    .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private metricRow(metrics: QuickMetric[]) {
    Row({ space: 10 }) {
      ForEach(metrics, (item: QuickMetric) => {
        this.metricChip(item)
      }, (item: QuickMetric) => `${item.label}-${item.value}`)
    }.width('100%')
  }

  @Builder
  private filterChips(options: QuickFilterOption[], current: string, onSelect: (key: string) => void) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(options, (option: QuickFilterOption) => {
        Text(option.label)
          .fontSize(12)
          .fontColor(current === option.key ? Color.White : $r('app.color.doctor_workspace_text_secondary'))
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .borderRadius(16)
          .backgroundColor(current === option.key ? '#1D1D1D' : $r('app.color.doctor_workspace_surface_hover'))
          .margin({ right: 8, bottom: 8 })
          .onClick(() => onSelect(option.key))
      }, (option: QuickFilterOption) => `${option.key}-${current === option.key}`)
    }.width('100%')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Row({ space: 12 }) {
          Button('‹ 返回工作台')
            .height(34)
            .fontSize(12)
            .borderRadius(9)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .backgroundColor($r('app.color.doctor_workspace_surface_hover'))
            .onClick(() => this.onBack())
          Text(this.title())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Blank().layoutWeight(1)
          Text(this.subtitle())
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.width('100%').alignItems(VerticalAlign.Center)

        if (this.kind === 'beds') {
          this.bedsView()
        } else if (this.kind === 'tasks') {
          this.tasksView()
        } else if (this.kind === 'alerts') {
          this.alertsView()
        } else if (this.kind === 'assessment') {
          this.assessmentsView()
        } else if (this.kind === 'billing') {
          this.billingView()
        } else {
          this.schedulesView()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 1280 })
      .padding({
        left: this.compactWidth ? 16 : 28,
        right: this.compactWidth ? 16 : 28,
        top: 56,
        bottom: 24
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.TopStart)
  }

  // ---- 床位预览 ----
  @Builder
  private bedsView() {
    this.metricRow([
      { label: '总床位', value: `${this.businessStore.beds.length}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '已入住', value: `${this.businessStore.beds.filter((bed: Bed) => bed.status === 'occupied').length}`, tone: $r('app.color.doctor_workspace_focus') },
      { label: '空闲', value: `${this.businessStore.beds.filter((bed: Bed) => bed.status !== 'occupied' && bed.status !== 'maintenance').length}`, tone: $r('app.color.doctor_workspace_success') },
      { label: '维护中', value: `${this.businessStore.beds.filter((bed: Bed) => bed.status === 'maintenance').length}`, tone: $r('sys.color.font_tertiary') }
    ])
    ForEach(this.businessStore.rooms, (room: Room) => {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(this.roomLabel(room))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Blank().layoutWeight(1)
          Text(`${this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id).length} 床`)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.width('100%')
        ForEach(this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id), (bed: Bed) => {
          Row({ space: 10 }) {
            Text(`床位 ${bed.bed_no}`)
              .fontSize(13)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width(96)
            Text(this.bedStatusText(bed.status))
              .fontSize(12)
              .fontColor(this.bedStatusTone(bed.status))
              .width(64)
            Text(bed.status === 'occupied' ? this.elderName(bed.elder_id) : '--')
              .fontSize(12)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').height(34).alignItems(VerticalAlign.Center)
        }, (bed: Bed) => `quick-bed-${bed.id}`)
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)
    }, (room: Room) => `quick-room-${room.id}`)
  }

  // ---- 护理任务 ----
  @Builder
  private tasksView() {
    this.metricRow([
      { label: '全部任务', value: `${this.businessStore.tasks.length}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '待处理', value: `${this.taskCount('todo')}`, tone: $r('app.color.doctor_workspace_danger') },
      { label: '进行中', value: `${this.taskCount('doing')}`, tone: $r('app.color.doctor_workspace_warning') },
      { label: '已完成', value: `${this.taskCount('done')}`, tone: $r('app.color.doctor_workspace_success') }
    ])
    this.filterChips([
      { key: 'all', label: '全部' },
      { key: 'todo', label: '待处理' },
      { key: 'doing', label: '进行中' },
      { key: 'done', label: '已完成' }
    ], this.taskFilter, (key: string) => this.taskFilter = key)
    ForEach(this.filteredTasks(), (task: CareTask) => {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            if (task.priority === 'danger') {
              Text('紧急')
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(6)
                .backgroundColor($r('app.color.doctor_workspace_danger'))
            }
            Text(task.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(VerticalAlign.Center)
          Text(`${this.elderName(task.elder_id)} · ${this.elderLocation(task.elder_id)}`)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.taskStatusText(task.status))
          .fontSize(12)
          .fontColor(this.taskStatusTone(task.status))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(VerticalAlign.Center)
    }, (task: CareTask) => `quick-task-${task.id}-${task.status}`)
    if (this.filteredTasks().length === 0) {
      Text('当前筛选下暂无任务').fontSize(13).fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
    }
  }

  // ---- 告警处理 ----
  @Builder
  private alertsView() {
    this.metricRow([
      { label: '全部告警', value: `${this.businessStore.alerts.length}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '待复核', value: `${this.alertCount('open')}`, tone: $r('app.color.doctor_workspace_danger') },
      { label: '复核中', value: `${this.alertCount('handled')}`, tone: $r('app.color.doctor_workspace_warning') },
      { label: '已复核', value: `${this.alertCount('closed')}`, tone: $r('app.color.doctor_workspace_success') }
    ])
    this.filterChips([
      { key: 'all', label: '全部' },
      { key: 'open', label: '待复核' },
      { key: 'handled', label: '复核中' },
      { key: 'closed', label: '已复核' }
    ], this.alertFilter, (key: string) => this.alertFilter = key)
    ForEach(this.filteredAlerts(), (alert: Alert) => {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(alert.type || '风险告警')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.alertLevelText(alert.level))
              .fontSize(10)
              .fontColor(alert.level === 'emergency' ? Color.White : $r('app.color.doctor_workspace_danger'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor(alert.level === 'emergency' ? $r('app.color.doctor_workspace_danger') : '#FDEBEC')
          }.alignItems(VerticalAlign.Center)
          Text(alert.content)
            .fontSize(11.5)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.elderName(alert.elder_id)} · ${alert.handled_by || '未分配'} · ${alert.create_time}`)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.alertStatusText(alert.status))
          .fontSize(12)
          .fontColor(this.alertStatusTone(alert.status))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(VerticalAlign.Center)
    }, (alert: Alert) => `quick-alert-${alert.id}-${alert.status}`)
    if (this.filteredAlerts().length === 0) {
      Text('当前筛选下暂无告警').fontSize(13).fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
    }
  }

  // ---- 健康评估 ----
  @Builder
  private assessmentsView() {
    this.metricRow([
      { label: '评估总数', value: `${this.businessStore.assessments.length}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '高风险', value: `${this.businessStore.assessments.filter((item: Assessment) => item.risk_level === 'high' || item.risk_level === 'danger').length}`, tone: $r('app.color.doctor_workspace_danger') },
      { label: '中风险', value: `${this.businessStore.assessments.filter((item: Assessment) => item.risk_level === 'medium' || item.risk_level === 'warning').length}`, tone: $r('app.color.doctor_workspace_warning') },
      { label: '低风险', value: `${this.businessStore.assessments.filter((item: Assessment) => item.risk_level === 'low').length}`, tone: $r('app.color.doctor_workspace_success') }
    ])
    ForEach(this.businessStore.assessments, (item: Assessment) => {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(item.assessment_type)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.elderName(item.elder_id)} · ${item.assessed_at}`)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 4 }) {
          Text(item.risk_level.length > 0 ? this.riskText(item.risk_level) : '--')
            .fontSize(12)
            .fontColor(this.riskTone(item.risk_level))
          Text(item.score !== undefined ? `${item.score} 分` : '--')
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(VerticalAlign.Center)
    }, (item: Assessment) => `quick-assessment-${item.id}`)
    if (this.businessStore.assessments.length === 0) {
      Text('暂无健康评估记录').fontSize(13).fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
    }
  }

  // ---- 账单管理 ----
  @Builder
  private billingView() {
    this.metricRow([
      { label: '账单总数', value: `${this.businessStore.bills.length}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '应收总额', value: `¥${this.billTotal((_bill: Bill) => true)}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '已收金额', value: `¥${this.billTotal((bill: Bill) => bill.status === 'paid')}`, tone: $r('app.color.doctor_workspace_success') },
      { label: '待收金额', value: `¥${this.billTotal((bill: Bill) => bill.status !== 'paid')}`, tone: $r('app.color.doctor_workspace_warning') }
    ])
    this.filterChips([
      { key: 'all', label: '全部' },
      { key: 'paid', label: '已支付' },
      { key: 'unpaid', label: '待支付' }
    ], this.billFilter, (key: string) => this.billFilter = key)
    ForEach(this.filteredBills(), (bill: Bill) => {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(`${this.elderName(bill.elder_id)} · ${bill.bill_month}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`床位费 ¥${bill.bed_fee} · 护理费 ¥${bill.nursing_fee} · 餐费 ¥${bill.meal_fee}`)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`¥${bill.amount.toFixed(2)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text(bill.status === 'paid' ? '已支付' : bill.status === 'partial' ? '部分支付' : '待支付')
          .fontSize(12)
          .fontColor(bill.status === 'paid' ? $r('app.color.doctor_workspace_success') : $r('app.color.doctor_workspace_warning'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(VerticalAlign.Center)
    }, (bill: Bill) => `quick-bill-${bill.id}`)
    if (this.filteredBills().length === 0) {
      Text('当前筛选下暂无账单').fontSize(13).fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
    }
  }

  // ---- 日常总览 ----
  @Builder
  private schedulesView() {
    this.metricRow([
      { label: '排班总数', value: `${this.businessStore.schedules.length}`, tone: $r('app.color.doctor_workspace_text_secondary') },
      { label: '白班', value: `${this.businessStore.schedules.filter((item: Schedule) => item.shift === 'morning').length}`, tone: $r('app.color.doctor_workspace_focus') },
      { label: '晚班', value: `${this.businessStore.schedules.filter((item: Schedule) => item.shift === 'afternoon').length}`, tone: $r('app.color.doctor_workspace_warning') },
      { label: '夜班', value: `${this.businessStore.schedules.filter((item: Schedule) => item.shift === 'night').length}`, tone: $r('sys.color.font_tertiary') }
    ])
    this.filterChips([
      { key: 'all', label: '全部' },
      { key: 'morning', label: '白班' },
      { key: 'afternoon', label: '晚班' },
      { key: 'night', label: '夜班' }
    ], this.scheduleShift, (key: string) => this.scheduleShift = key)
    ForEach(this.filteredSchedules(), (item: Schedule) => {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(item.work_date)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(item.work_date === this.todayKey() ? $r('app.color.brand_blue') : $r('app.color.doctor_workspace_text_primary'))
            if (item.work_date === this.todayKey()) {
              Text('今天')
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(6)
                .backgroundColor($r('app.color.brand_blue'))
            }
          }.alignItems(VerticalAlign.Center)
          Text(item.room_scope && item.room_scope.length > 0 ? `负责区域 ${item.room_scope}` : '范围未登记')
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.shiftText(item.shift))
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
        Text(item.staff)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(VerticalAlign.Center)
    }, (item: Schedule) => `quick-schedule-${item.id}`)
    if (this.filteredSchedules().length === 0) {
      Text('当前筛选下暂无排班').fontSize(13).fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
    }
  }
}
