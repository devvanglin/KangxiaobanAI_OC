import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { BusinessStore } from '../../network/BusinessStore';
import { AlertApi } from '../../network/AlertApi';
import { Alert, AlertAction, HealthRecord } from '../../network/Dto';
import { QuickEmptyHint, quickElderName } from './WideDoctorQuickPageKit';

interface CategoryTab {
  key: string;
  label: string;
}

interface VitalCell {
  label: string;
  value: string;
  danger: boolean;
}

const TAG: string = 'WideDoctorAlertsPage';

/** 医师端「告警通知」：分类筛选 + 搜索 + 左列表右详情 + 处置时间线。 */
@ComponentV2
export struct WideDoctorAlertsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local category: string = 'all';
  @Local search: string = '';
  @Local selectedAlertId: number = -1;
  @Local actions: AlertAction[] = [];
  @Local actionsLoading: boolean = false;
  @Local operating: boolean = false;
  @Local compactDetailVisible: boolean = false;
  private scroller: Scroller = new Scroller();
  private detailScroller: Scroller = new Scroller();
  private categoryTabs: CategoryTab[] = [
    { key: 'all', label: '全部' },
    { key: 'device', label: '设备告警' },
    { key: 'health', label: '健康告警' },
    { key: 'emergency', label: '紧急告警' },
    { key: 'system', label: '系统通知' }
  ];

  aboutToAppear(): void {
    void this.businessStore.load().then((): void => {
      if (this.selectedAlertId === -1) {
        const alerts: Alert[] = this.filteredAlerts();
        if (alerts.length > 0) {
          this.selectedAlertId = alerts[0].id;
        }
      }
    });
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  // ==================== 数据映射 ====================

  private categoryOf(alert: Alert): string {
    if (alert.type === 'offline') {
      return 'device';
    }
    if (alert.level === 'emergency' || alert.type === 'fall') {
      return 'emergency';
    }
    const type: string = alert.type;
    if (type.includes('health') || type.includes('vital') || type.includes('heart') ||
      type.includes('breath') || type.includes('oxygen') || type.includes('sleep')) {
      return 'health';
    }
    return 'system';
  }

  private filteredAlerts(): Alert[] {
    const keyword: string = this.search.trim();
    return this.businessStore.alerts.filter((alert: Alert): boolean => {
      if (this.category !== 'all' && this.categoryOf(alert) !== this.category) {
        return false;
      }
      if (keyword.length === 0) {
        return true;
      }
      const haystack: string =
        `${alert.content}${alert.type}${quickElderName(this.businessStore, alert.elder_id)}`;
      return haystack.includes(keyword);
    });
  }

  private selectedAlert(): Alert | undefined {
    return this.businessStore.alerts.find((alert: Alert): boolean => alert.id === this.selectedAlertId);
  }

  private alertById(alertId: number): Alert {
    return this.businessStore.alerts.find((alert: Alert): boolean => alert.id === alertId) ?? this.emptyAlert();
  }

  private emptyAlert(): Alert {
    return {
      id: -1,
      elder_id: undefined,
      device_id: '',
      type: '',
      level: 'info',
      content: '',
      status: 'new',
      handled_by: '',
      create_time: ''
    };
  }

  private deviceFor(alert: Alert): IotDeviceRef | undefined {
    return this.businessStore.devices.find((item: IotDeviceRef): boolean => item.device_id === alert.device_id);
  }

  private deviceSourceText(alert: Alert): string {
    const device: IotDeviceRef | undefined = this.deviceFor(alert);
    if (device === undefined) {
      return alert.device_id.length > 0 ? alert.device_id : '未知设备';
    }
    return device.product === 'breath_radar' ? '睡眠监测雷达' :
      device.product === 'fall_radar' ? '跌倒监测雷达' : (device.product || device.device_id);
  }

  private alertTitle(alert: Alert): string {
    const device: IotDeviceRef | undefined = this.deviceFor(alert);
    const room: string = device !== undefined && device.room.length > 0 ? `${device.room}房间` : '';
    const elderName: string = alert.elder_id !== undefined && alert.elder_id !== 0 ?
      quickElderName(this.businessStore, alert.elder_id) : '';
    if (alert.type === 'offline') {
      return `${room}设备离线告警`;
    }
    const suffix: string = alert.type === 'fall' ? '跌倒告警' : '健康数据异常';
    if (elderName.length > 0) {
      return `${room}${elderName}${suffix}`;
    }
    return room.length > 0 ? `${room}${suffix}` : `${suffix}（${alert.type || '未分类'}）`;
  }

  private alertNo(alert: Alert): string {
    const day: string = alert.create_time.slice(0, 10).split('-').join('');
    return `ALT-${day}-${alert.id.toString().padStart(4, '0')}`;
  }

  private shortTime(time: string): string {
    const idx: number = time.indexOf(' ') >= 0 ? time.indexOf(' ') : time.indexOf('T');
    return idx >= 0 ? time.slice(idx + 1, idx + 6) : time;
  }

  private fullTime(time: string): string {
    return time.replace('T', ' ').slice(0, 19);
  }

  private statusText(status: string): string {
    return status === 'closed' ? '已闭环' : status === 'handled' ? '处理中' : '待处理';
  }

  private statusTextColor(status: string): ResourceColor {
    return status === 'closed' ? $r('app.color.doctor_workspace_success') :
      status === 'handled' ? $r('app.color.brand_blue') : $r('app.color.doctor_workspace_warning');
  }

  private statusBgColor(status: string): ResourceColor {
    return status === 'closed' ? 'rgba(99,153,34,0.12)' :
      status === 'handled' ? 'rgba(29,99,237,0.10)' : 'rgba(239,159,39,0.16)';
  }

  private levelText(level: string): string {
    return level === 'emergency' ? '紧急' : level === 'important' ? '重要' : '一般';
  }

  private levelTextColor(level: string): ResourceColor {
    return level === 'emergency' ? Color.White :
      level === 'important' ? $r('app.color.doctor_workspace_warning') : $r('sys.color.font_secondary');
  }

  private levelBgColor(level: string): ResourceColor {
    return level === 'emergency' ? $r('app.color.doctor_workspace_danger') :
      level === 'important' ? 'rgba(239,159,39,0.16)' : 'rgba(136,135,128,0.14)';
  }

  private actionText(action: string): string {
    return action === 'acknowledge' ? '标记已读' :
      action === 'assign' ? '转派处理' :
      action === 'note' ? '添加备注' :
      action === 'escalate' ? '升级上报' :
      action === 'resolve' ? '标记解决' : '关闭告警';
  }

  private latestRecord(elderId?: number): HealthRecord | undefined {
    if (elderId === undefined || elderId === 0) {
      return undefined;
    }
    return this.businessStore.healthRecords
      .filter((item: HealthRecord): boolean => item.elder_id === elderId)
      .sort((left: HealthRecord, right: HealthRecord): number =>
        right.record_time.localeCompare(left.record_time))[0];
  }

  private vitalCells(alert: Alert): VitalCell[] {
    const record: HealthRecord | undefined = this.latestRecord(alert.elder_id);
    const danger: boolean = record?.risk_level === 'danger' || record?.is_abnormal === true;
    return [
      { label: '心率', value: record?.heart_rate !== undefined ? `${record.heart_rate} 次/分` : '--', danger: danger },
      { label: '血氧饱和度', value: record?.spo2 !== undefined ? `${record.spo2} %` : '--', danger: danger },
      { label: '呼吸频率', value: record?.respiratory_rate !== undefined ? `${record.respiratory_rate} 次/分` : '--', danger: danger },
      { label: '体温', value: record?.temperature !== undefined ? `${record.temperature} ℃` : '--', danger: danger },
      { label: '设备编号', value: alert.device_id.length > 0 ? alert.device_id : '--', danger: false },
      { label: '当前状态', value: this.statusText(alert.status), danger: alert.status === 'new' && danger }
    ];
  }

  // ==================== 交互 ====================

  private reloadActions(alertId: number): void {
    this.actionsLoading = true;
    AlertApi.listActions(alertId).then((items: AlertAction[]): void => {
      if (this.selectedAlertId === alertId) {
        this.actions = items;
      }
      this.actionsLoading = false;
    }).catch((): void => {
      this.actionsLoading = false;
    });
  }

  private selectAlert(alert: Alert): void {
    this.selectedAlertId = alert.id;
    this.actions = [];
    this.reloadActions(alert.id);
    if (this.compactWidth) {
      this.compactDetailVisible = true;
    } else {
      this.resetDetailScroll();
    }
  }

  private resetDetailScroll(): void {
    try {
      this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } catch (_error) {
      // scroller 未挂载时忽略。
    }
  }

  private runOperation(operation: () => Promise<void>, successMessage: string): void {
    const alert: Alert | undefined = this.selectedAlert();
    if (alert === undefined || this.operating) {
      return;
    }
    this.operating = true;
    operation().then((): void => {
      this.operating = false;
      this.reloadActions(alert.id);
      void this.businessStore.load();
      this.showToast(successMessage);
    }).catch((error: Object): void => {
      this.operating = false;
      this.showToast(error instanceof Error && error.message.length > 0 ? error.message : '操作失败，请重试');
    });
  }

  private markAcknowledge(): void {
    const alert: Alert | undefined = this.selectedAlert();
    if (alert === undefined) {
      return;
    }
    this.runOperation((): Promise<void> => AlertApi.addAction(alert.id, 'acknowledge', ''), '已标记已读');
  }

  private assignHandling(): void {
    const alert: Alert | undefined = this.selectedAlert();
    if (alert === undefined) {
      return;
    }
    this.runOperation((): Promise<void> => AlertApi.addAction(alert.id, 'assign', '转派至护理站跟进'),
      '已转派处理');
  }

  private closeAlert(): void {
    const alert: Alert | undefined = this.selectedAlert();
    if (alert === undefined) {
      return;
    }
    this.runOperation((): Promise<void> => AlertApi.handleAlert(alert.id, true), '告警已关闭');
  }

  @Monitor('selectedAlertId')
  onSelectedAlertChange(): void {
    if (this.selectedAlertId !== -1 && this.actions.length === 0) {
      this.reloadActions(this.selectedAlertId);
    }
  }

  // ==================== UI ====================

  @Builder
  private levelBadge(level: string) {
    Text(this.levelText(level))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.levelTextColor(level))
      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
      .borderRadius(5)
      .backgroundColor(this.levelBgColor(level))
  }

  @Builder
  private statusBadge(status: string) {
    Text(this.statusText(status))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.statusTextColor(status))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(6)
      .backgroundColor(this.statusBgColor(status))
  }

  @Builder
  private categoryTabBar() {
    Row({ space: 26 }) {
      ForEach(this.categoryTabs, (tab: CategoryTab) => {
        Column({ space: 6 }) {
          Text(tab.label)
            .fontSize(15)
            .fontWeight(this.category === tab.key ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.category === tab.key ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
          Row()
            .width(20)
            .height(3)
            .borderRadius(1.5)
            .backgroundColor(this.category === tab.key ? $r('sys.color.font_primary') : Color.Transparent)
        }
        .onClick(() => {
          this.category = tab.key;
        })
      }, (tab: CategoryTab) => tab.key)
    }
    .width('100%')
    .padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private alertCard(alert: Alert) {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        this.levelBadge(alert.level)
        Blank()
        Text(this.shortTime(alert.create_time))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.alertTitle(alert))
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(alert.content)
        .width('100%')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 8 }) {
        Text(`来源: ${this.deviceSourceText(alert)}`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        this.statusBadge(alert.status)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor(this.selectedAlertId === alert.id ? 'rgba(29,99,237,0.06)' : Color.Transparent)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.selectAlert(alert);
    })
  }

  @Builder
  private masterPane() {
    Column({ space: 10 }) {
      TextInput({ placeholder: '搜索告警…', text: this.search })
        .width('100%')
        .height(38)
        .fontSize(13)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(10)
        .onChange((value: string) => {
          this.search = value;
        })

      Scroll(this.scroller) {
        Column({ space: 8 }) {
          if (this.filteredAlerts().length === 0) {
            QuickEmptyHint({ text: '当前筛选下暂无告警', loading: this.businessStore.loading })
              .margin({ top: 40 })
          } else {
            ForEach(this.filteredAlerts(), (alert: Alert) => {
              this.alertCard(alert)
            }, (alert: Alert) => `alert-${alert.id}-${alert.status}`)
          }
        }
        .width('100%')
        .padding({ bottom: 16 + this.naviIndicatorHeight })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width(this.compactWidth ? '100%' : '37%')
    .constraintSize({ minWidth: 320, maxWidth: 460 })
    .height('100%')
  }

  @Builder
  private detailHeader(alert: Alert) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        this.levelBadge(alert.level)
        Text(this.alertTitle(alert))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.alertNo(alert))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(`告警时间：${this.fullTime(alert.create_time)}   来源：${this.deviceSourceText(alert)}` +
        `   当前状态：${this.statusText(alert.status)}`)
        .width('100%')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private detailCardTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
  }

  @Builder
  private detailContentCard(alert: Alert) {
    Column({ space: 10 }) {
      this.detailCardTitle('告警详情')
      Text(alert.content)
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private vitalCellView(cell: VitalCell) {
    Column({ space: 6 }) {
      Text(cell.label)
        .width('100%')
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(cell.value)
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(cell.danger ? $r('app.color.doctor_workspace_danger') : $r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(8)
  }

  @Builder
  private vitalCard(alert: Alert) {
    Column({ space: 10 }) {
      this.detailCardTitle('生命体征数据')
      GridRow({ columns: 3, gutter: 10 }) {
        ForEach(this.vitalCells(alert), (cell: VitalCell) => {
          GridCol() {
            this.vitalCellView(cell)
          }
        }, (cell: VitalCell) => `${cell.label}-${cell.value}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private timelineRow(time: string, title: string, note: string, isFirst: boolean) {
    Row({ space: 10 }) {
      Column() {
        Circle({ width: 7, height: 7 })
          .fill(isFirst ? $r('app.color.doctor_workspace_danger') : $r('sys.color.font_tertiary'))
        if (!isFirst) {
          Blank()
        }
      }
      .width(7)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 3 }) {
        Text(time)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        if (note.length > 0) {
          Text(note)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 14 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private timelineCard(alert: Alert) {
    Column({ space: 10 }) {
      this.detailCardTitle('处理记录')
      if (this.actionsLoading) {
        Text('正在加载处理记录…')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ top: 6 })
      } else {
        this.timelineRow(this.fullTime(alert.create_time), '系统触发告警，推送至护理工作台',
          alert.content, true)
        ForEach(this.actions, (item: AlertAction) => {
          this.timelineRow(this.fullTime(item.created_at),
            `${this.actionText(item.action)} · ${item.user_id > 0 ? '操作员' + item.user_id : '系统'}`,
            item.note, false)
        }, (item: AlertAction) => `action-${item.id}`)
      }
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private actionButtons(alert: Alert) {
    Row({ space: 12 }) {
      Blank()
      if (alert.status !== 'closed') {
        Button('标记已读')
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(10)
          .height(40)
          .padding({ left: 18, right: 18 })
          .enabled(!this.operating)
          .onClick(() => {
            this.markAcknowledge();
          })
        Button('转派处理')
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(10)
          .height(40)
          .padding({ left: 18, right: 18 })
          .enabled(!this.operating)
          .onClick(() => {
            this.assignHandling();
          })
        Button(this.operating ? '提交中…' : '关闭告警')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.font_primary'))
          .borderRadius(10)
          .height(40)
          .padding({ left: 22, right: 22 })
          .enabled(!this.operating)
          .onClick(() => {
            this.closeAlert();
          })
      } else {
        Text(`该告警已闭环 · 处理人 ${alert.handled_by.length > 0 ? alert.handled_by : '未记录'}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private detailPane() {
    if (this.selectedAlert() === undefined) {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.bell_fill'))
          .fontSize(44)
          .fontColor([$r('sys.color.font_tertiary')])
        Text('在左侧选择一条告警')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text('即可查看告警详情、生命体征与处理记录')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      this.alertDetail(this.selectedAlertId)
    }
  }

  @Builder
  private alertDetail(alertId: number) {
    Scroll(this.detailScroller) {
      Column({ space: 14 }) {
        this.detailHeader(this.alertById(alertId))
        this.detailContentCard(this.alertById(alertId))
        this.vitalCard(this.alertById(alertId))
        this.timelineCard(this.alertById(alertId))
        this.actionButtons(this.alertById(alertId))
      }
      .width('100%')
      .constraintSize({ maxWidth: 980 })
      .padding({
        left: this.compactWidth ? 16 : 24,
        right: this.compactWidth ? 16 : 24,
        bottom: 24 + this.naviIndicatorHeight
      })
    }
    .layoutWeight(1)
    .width('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    HdsNavDestination() {
      Column() {
        this.categoryTabBar()
        Row({ space: this.compactWidth ? 0 : 16 }) {
          if (this.compactWidth && this.compactDetailVisible) {
            this.compactDetail()
          } else {
            this.masterPane()
            if (!this.compactWidth) {
              this.detailPane()
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .height('100%')
    }
    .onBackPressed((): boolean => {
      if (this.compactWidth && this.compactDetailVisible) {
        this.compactDetailVisible = false;
        return true;
      }
      this.onClose();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '告警通知' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  private compactDetail() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.detailPane()
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(36)
      .height(36)
      .margin({ left: 12, top: 4 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .onClick(() => {
        this.compactDetailVisible = false;
      })
    }
    .width('100%')
    .height('100%')
  }
}

interface IotDeviceRef {
  device_id: string;
  product: string;
  room: string;
}
