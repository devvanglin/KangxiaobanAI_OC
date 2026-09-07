import { BusinessStore } from '../../network/BusinessStore';
import { Alert, Assessment, Bed, Bill, CareTask, Elder, Room } from '../../network/Dto';

export interface QuickMetric {
  label: string;
  value: string;
  tone: ResourceColor;
}

export interface QuickFilterOption {
  key: string;
  label: string;
}

/**
 * 医师端「常用功能」路由页共享工具：纯函数只依赖传入的 BusinessStore 快照，
 * 不持有组件状态；组件全部使用 HDS 令牌（sys.color / app.color 语义色）。
 */

export function quickElderName(store: BusinessStore, elderId?: number): string {
  if (elderId === undefined || elderId === 0) {
    return '未关联长者';
  }
  return store.elders.find((item: Elder) => item.id === elderId)?.name ?? '未关联长者';
}

export function quickElderLocation(store: BusinessStore, elderId?: number): string {
  const elder: Elder | undefined = elderId === undefined ? undefined :
    store.elders.find((item: Elder) => item.id === elderId);
  const bed: Bed | undefined = elder === undefined ? undefined :
    store.beds.find((item: Bed) => item.id === elder.bed_id);
  const room: Room | undefined = bed === undefined ? undefined :
    store.rooms.find((item: Room) => item.id === bed.room_id);
  return bed !== undefined && room !== undefined ? `${room.building}${room.floor}F-${room.room_no}-${bed.bed_no}` :
    '未分配床位';
}

export function quickRoomLabel(room: Room): string {
  return `${room.building}${room.floor}F · ${room.room_no}`;
}

export function quickBedStatusText(status: string): string {
  return status === 'occupied' ? '已入住' : status === 'maintenance' ? '维护中' : '空闲';
}

export function quickBedStatusTone(status: string): ResourceColor {
  return status === 'occupied' ? $r('app.color.doctor_workspace_focus') :
    status === 'maintenance' ? $r('sys.color.font_tertiary') : $r('app.color.doctor_workspace_success');
}

export function quickTaskStatusText(status: string): string {
  return status === 'todo' ? '待处理' : status === 'doing' ? '进行中' : '已完成';
}

export function quickTaskStatusTone(status: string): ResourceColor {
  return status === 'todo' ? $r('app.color.doctor_workspace_danger') :
    status === 'doing' ? $r('app.color.doctor_workspace_warning') : $r('app.color.doctor_workspace_success');
}

export function quickAlertStatusText(status: string): string {
  return status === 'closed' ? '已复核' : status === 'handled' ? '复核中' : '待复核';
}

export function quickAlertStatusTone(status: string): ResourceColor {
  return status === 'closed' ? $r('app.color.doctor_workspace_success') :
    status === 'handled' ? $r('app.color.doctor_workspace_warning') : $r('app.color.doctor_workspace_danger');
}

export function quickAlertLevelText(level: string): string {
  return level === 'emergency' ? '紧急' : level === 'important' ? '重要' : '一般';
}

export function quickAlertLevelTextColor(level: string): ResourceColor {
  return level === 'emergency' ? Color.White : $r('app.color.doctor_workspace_danger');
}

export function quickAlertLevelBgColor(level: string): ResourceColor {
  return level === 'emergency' ? $r('app.color.doctor_workspace_danger') : $r('app.color.status_danger_bg');
}

export function quickRiskText(risk: string): string {
  if (risk === 'high' || risk === 'danger') {
    return '高风险';
  }
  return risk === 'medium' || risk === 'warning' ? '中风险' : risk === 'low' ? '低风险' : (risk || '--');
}

export function quickRiskTone(risk: string): ResourceColor {
  if (risk === 'high' || risk === 'danger') {
    return $r('app.color.doctor_workspace_danger');
  }
  return risk === 'medium' || risk === 'warning' ? $r('app.color.doctor_workspace_warning') :
    $r('app.color.doctor_workspace_success');
}

export function quickBillStatusText(bill: Bill): string {
  return bill.status === 'paid' ? '已支付' : bill.status === 'partial' ? '部分支付' : '待支付';
}

export function quickBillStatusTone(bill: Bill): ResourceColor {
  return bill.status === 'paid' ? $r('app.color.doctor_workspace_success') :
    $r('app.color.doctor_workspace_warning');
}

export function quickBillTotal(store: BusinessStore, filter: (bill: Bill) => boolean): number {
  return Math.round(store.bills.filter(filter).reduce((sum: number, bill: Bill) => sum + bill.amount, 0));
}

@ComponentV2
export struct QuickMetricStrip {
  @Param @Require metrics: QuickMetric[];

  build() {
    Row({ space: 10 }) {
      ForEach(this.metrics, (item: QuickMetric) => {
        Column({ space: 4 }) {
          Text(item.value)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(item.label)
            .fontSize(11)
            .fontColor(item.tone)
        }
        .layoutWeight(1)
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .borderRadius(12)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .alignItems(HorizontalAlign.Start)
      }, (item: QuickMetric) => `${item.label}-${item.value}`)
    }.width('100%')
  }
}

@ComponentV2
export struct QuickFilterChips {
  @Param @Require options: QuickFilterOption[];
  @Param current: string = 'all';
  @Event onSelect: (key: string) => void = (_key: string) => {};

  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.options, (option: QuickFilterOption) => {
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Text(option.label)
            .fontSize(13)
            .fontColor(this.current === option.key ? Color.White : $r('sys.color.font_secondary'))
        }
        .height(36)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.current === option.key ? $r('app.color.brand_blue') :
          $r('sys.color.comp_background_secondary'))
        .border({ width: this.current === option.key ? 0 : 0.5, color: $r('sys.color.comp_divider') })
        .margin({ right: 8, bottom: 8 })
        .accessibilityText(option.label)
        .accessibilitySelected(this.current === option.key)
        .onClick(() => this.onSelect(option.key))
      }, (option: QuickFilterOption) => `${option.key}-${this.current === option.key}`)
    }.width('100%')
  }
}

@ComponentV2
export struct QuickEmptyHint {
  @Param @Require text: string;
  @Param loading: boolean = false;

  build() {
    Column({ space: 10 }) {
      if (this.loading) {
        LoadingProgress().width(24).height(24).color($r('sys.color.font_tertiary'))
      }
      Text(this.text)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ top: 28, bottom: 28 })
    .alignItems(HorizontalAlign.Center)
  }
}
