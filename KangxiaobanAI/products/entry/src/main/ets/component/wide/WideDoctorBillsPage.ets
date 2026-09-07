import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import ApiClient from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Bill } from '../../network/Dto';
import { quickElderName } from './WideDoctorQuickPageKit';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

interface EmptyBody {
}

interface GenerateResult {
  created: number;
}

interface StatusFilter {
  key: string;
  label: string;
}

interface MonthOption {
  value: string;
}

/** 账单行展示用的派生状态：paid 已缴费 / partial 部分缴费 / pending 待缴费 / overdue 已逾期。 */
const BILL_STATUSES: StatusFilter[] = [
  { key: 'all', label: '全部' },
  { key: 'pending', label: '待缴费' },
  { key: 'partial', label: '部分缴费' },
  { key: 'paid', label: '已缴费' },
  { key: 'overdue', label: '已逾期' }
];

/** 医师端「账单管理」：状态胶囊 + 搜索 + 月份筛选 + 账单表格 + 合计行。 */
@ComponentV2
export struct WideDoctorBillsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local statusFilter: string = 'all';
  @Local search: string = '';
  @Local selectedMonthIndex: number = 0;
  @Local generating: boolean = false;
  @Local payingBillId: number = -1;
  @Local hoveredBillId: number = -1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    void this.businessStore.load();
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

  private currentMonth(): string {
    const now: Date = new Date();
    return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;
  }

  private statusItems(): WideSlidingCapsuleItem[] {
    return BILL_STATUSES.map((item: StatusFilter, index: number): WideSlidingCapsuleItem => {
      return { title: item.label, index: index };
    });
  }

  private statusIndex(): number {
    const idx: number = BILL_STATUSES.findIndex((item: StatusFilter): boolean => item.key === this.statusFilter);
    return idx < 0 ? 0 : idx;
  }

  private derivedStatus(bill: Bill): string {
    if (bill.status === 'paid') {
      return 'paid';
    }
    if (bill.status === 'partial') {
      return 'partial';
    }
    return bill.bill_month < this.currentMonth() ? 'overdue' : 'pending';
  }

  private monthOptions(): MonthOption[] {
    const months: string[] = [];
    this.businessStore.bills.forEach((bill: Bill): void => {
      if (!months.includes(bill.bill_month)) {
        months.push(bill.bill_month);
      }
    });
    months.sort((left: string, right: string): number => right.localeCompare(left));
    const options: MonthOption[] = [];
    const allOption: MonthOption = { value: '全部月份' };
    options.push(allOption);
    months.forEach((month: string): void => {
      const option: MonthOption = { value: month };
      options.push(option);
    });
    return options;
  }

  private billNo(bill: Bill): string {
    return `B${bill.bill_month.split('-').join('')}${bill.id.toString().padStart(3, '0')}`;
  }

  private filteredBills(): Bill[] {
    const keyword: string = this.search.trim();
    const month: string = this.selectedMonthIndex > 0 ? this.monthOptions()[this.selectedMonthIndex].value : '';
    return this.businessStore.bills.filter((bill: Bill): boolean => {
      const derived: string = this.derivedStatus(bill);
      if (this.statusFilter === 'pending' && derived !== 'pending') {
        return false;
      }
      if (this.statusFilter === 'partial' && derived !== 'partial') {
        return false;
      }
      if (this.statusFilter === 'paid' && derived !== 'paid') {
        return false;
      }
      if (this.statusFilter === 'overdue' && derived !== 'overdue') {
        return false;
      }
      if (month.length > 0 && bill.bill_month !== month) {
        return false;
      }
      if (keyword.length === 0) {
        return true;
      }
      const haystack: string =
        `${this.billNo(bill)}${quickElderName(this.businessStore, bill.elder_id)}`;
      return haystack.includes(keyword);
    });
  }

  private totalOf(selector: (bill: Bill) => number): number {
    let total: number = 0;
    this.filteredBills().forEach((bill: Bill): void => {
      total += selector(bill);
    });
    return total;
  }

  private formatMoney(value: number): string {
    const fixed: string = value.toFixed(2);
    const parts: string[] = fixed.split('.');
    const grouped: string = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return `¥${grouped}.${parts[1]}`;
  }

  private statusText(derived: string): string {
    return derived === 'paid' ? '已缴费' :
      derived === 'partial' ? '部分缴费' :
      derived === 'overdue' ? '已逾期' : '待缴费';
  }

  private statusTone(derived: string): ResourceColor {
    return derived === 'paid' ? $r('app.color.doctor_workspace_success') :
      derived === 'partial' ? $r('app.color.brand_blue') :
      derived === 'overdue' ? $r('app.color.doctor_workspace_danger') :
      $r('app.color.doctor_workspace_warning');
  }

  private statusBg(derived: string): ResourceColor {
    return derived === 'paid' ? 'rgba(99,153,34,0.12)' :
      derived === 'partial' ? 'rgba(29,99,237,0.10)' :
      derived === 'overdue' ? 'rgba(163,45,45,0.10)' : 'rgba(239,159,39,0.16)';
  }

  // ==================== 交互 ====================

  private generateBills(): void {
    if (this.generating) {
      return;
    }
    this.generating = true;
    const body: EmptyBody = {};
    ApiClient.post<GenerateResult>(`/bills/generate?month=${this.currentMonth()}`, body)
      .then((response): void => {
        this.generating = false;
        if (response.code !== 0) {
          this.showToast(response.msg.length > 0 ? response.msg : '生成账单失败');
          return;
        }
        const created: number = response.data !== undefined ? response.data.created : 0;
        this.showToast(created > 0 ? `已生成 ${created} 张账单` : '本期账单已全部生成');
        void this.businessStore.load();
      })
      .catch((_error: Object): void => {
        this.generating = false;
        this.showToast('生成账单失败，请检查网络');
      });
  }

  private collectBill(bill: Bill): void {
    const rest: number = Math.round((bill.amount - bill.paid) * 100) / 100;
    if (rest <= 0 || this.payingBillId === bill.id) {
      return;
    }
    this.payingBillId = bill.id;
    const request: PayRequest = {
      elder_id: bill.elder_id,
      month: bill.bill_month,
      amount: rest,
      reason: '账单缴费'
    };
    ApiClient.post<Object>('/bills/pay', request)
      .then((response): void => {
        this.payingBillId = -1;
        if (response.code !== 0) {
          this.showToast(response.msg.length > 0 ? response.msg : '收款失败');
          return;
        }
        this.showToast(`已收款 ${this.formatMoney(rest)}`);
        void this.businessStore.load();
      })
      .catch((_error: Object): void => {
        this.payingBillId = -1;
        this.showToast('收款失败，请检查网络');
      });
  }

  // ==================== UI ====================

  @Builder
  private headerCell(title: string, weight: number, alignEnd: boolean) {
    Text(title)
      .layoutWeight(weight)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .textAlign(alignEnd ? TextAlign.End : TextAlign.Start)
      .maxLines(1)
  }

  @Builder
  private moneyCell(value: string, weight: number, strong: boolean) {
    Text(value)
      .layoutWeight(weight)
      .fontSize(strong ? 13 : 12)
      .fontWeight(strong ? FontWeight.Bold : FontWeight.Regular)
      .fontColor($r('sys.color.font_primary'))
      .textAlign(TextAlign.End)
      .maxLines(1)
  }

  @Builder
  private statusPill(derived: string) {
    Text(this.statusText(derived))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.statusTone(derived))
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(6)
      .backgroundColor(this.statusBg(derived))
  }

  @Builder
  private tableHeader() {
    Row({ space: 12 }) {
      this.headerCell('账单编号', 3, false)
      this.headerCell('老人姓名', 2, false)
      this.headerCell('账单月份', 2, false)
      this.headerCell('床位费', 2, true)
      this.headerCell('护理费', 2, true)
      this.headerCell('餐费', 2, true)
      this.headerCell('应收金额', 3, true)
      this.headerCell('已收金额', 3, true)
      this.headerCell('状态', 2, false)
      this.headerCell('操作', 2, false)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private billRow(bill: Bill) {
    Row({ space: 12 }) {
      Text(this.billNo(bill))
        .layoutWeight(3)
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
      Text(quickElderName(this.businessStore, bill.elder_id))
        .layoutWeight(2)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text(bill.bill_month)
        .layoutWeight(2)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
      this.moneyCell(this.formatMoney(bill.bed_fee), 2, false)
      this.moneyCell(this.formatMoney(bill.nursing_fee), 2, false)
      this.moneyCell(this.formatMoney(bill.meal_fee), 2, false)
      this.moneyCell(this.formatMoney(bill.amount), 3, true)
      this.moneyCell(this.formatMoney(bill.paid), 3, true)
      Row() {
        this.statusPill(this.derivedStatus(bill))
      }
      .layoutWeight(2)

      Row({ space: 10 }) {
        if (this.derivedStatus(bill) !== 'paid') {
          Text(this.payingBillId === bill.id ? '收款中…' : '收款')
            .fontSize(13)
            .fontColor($r('app.color.brand_blue'))
            .onClick(() => {
              this.collectBill(bill);
            })
        } else {
          Text('已结清')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .layoutWeight(2)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.hoveredBillId === bill.id ? $r('sys.color.interactive_hover') : Color.Transparent)
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
    .onHover((isHover: boolean) => {
      this.hoveredBillId = isHover ? bill.id : -1;
    })
  }

  @Builder
  private totalRow() {
    Row({ space: 12 }) {
      Text(`合计（${this.filteredBills().length} 张）`)
        .layoutWeight(3)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text('')
        .layoutWeight(2)
      Text('')
        .layoutWeight(2)
      Text('')
        .layoutWeight(2)
      Text('')
        .layoutWeight(2)
      Text('')
        .layoutWeight(2)
      this.moneyCell(this.formatMoney(this.totalOf((bill: Bill): number => bill.amount)), 3, true)
      this.moneyCell(this.formatMoney(this.totalOf((bill: Bill): number => bill.paid)), 3, true)
      Text('待收金额')
        .layoutWeight(2)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
      Text(this.formatMoney(this.totalOf((bill: Bill): number => bill.amount - bill.paid)))
        .layoutWeight(2)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_danger'))
        .textAlign(TextAlign.End)
        .maxLines(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .alignItems(VerticalAlign.Center)
  }

  build() {
    HdsNavDestination() {
      Row() {
        Column() {
        Row({ space: 12 }) {
          WideSlidingCapsule({
            items: this.statusItems(),
            selectedIndex: this.statusIndex(),
            itemWidth: 88,
            onSelect: (index: number) => {
              if (index >= 0 && index < BILL_STATUSES.length) {
                this.statusFilter = BILL_STATUSES[index].key;
              }
            }
          })
          Blank()
          Select(this.monthOptions())
            .selected(this.selectedMonthIndex)
            .value(this.monthOptions()[this.selectedMonthIndex].value)
            .fontColor($r('sys.color.font_primary'))
            .height(38)
            .onSelect((index: number): void => {
              this.selectedMonthIndex = index;
            })
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(14)
              .fontColor([$r('sys.color.font_tertiary')])
            TextInput({ placeholder: '搜索老人姓名/账单编号…', text: this.search })
              .layoutWeight(1)
              .height(32)
              .fontSize(13)
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .onChange((value: string) => {
                this.search = value;
              })
          }
          .width(240)
          .height(38)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(19)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .margin({ left: 12 })
          Button(this.generating ? '生成中…' : '生成账单')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('sys.color.font_primary'))
            .borderRadius(10)
            .height(38)
            .padding({ left: 18, right: 18 })
            .enabled(!this.generating)
            .onClick(() => {
              this.generateBills();
            })
        }
        .width('100%')
        .padding({ top: 88 + this.statusBarHeight })
        .margin({ bottom: 16 })

        Column() {
          this.tableHeader()
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Scroll(this.scroller) {
            Column() {
              if (this.filteredBills().length === 0) {
                Column({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.doc_text'))
                    .fontSize(36)
                    .fontColor([$r('sys.color.font_tertiary')])
                  Text(this.businessStore.loading && !this.businessStore.loaded ? '正在加载账单…' : '暂无账单记录')
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('sys.color.font_secondary'))
                  Text('点击右上角「生成账单」为本月在院长者生成账单')
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('sys.color.font_tertiary'))
                }
                .width('100%')
                .padding({ top: 48, bottom: 48 })
                .alignItems(HorizontalAlign.Center)
              } else {
                ForEach(this.filteredBills(), (bill: Bill) => {
                  this.billRow(bill)
                }, (bill: Bill) => `bill-${bill.id}-${bill.status}-${bill.paid}`)
              }
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          if (this.filteredBills().length > 0) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
            this.totalRow()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ bottom: 24 + this.naviIndicatorHeight })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: 1280 })
        .padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .onBackPressed((): boolean => {
      this.onClose();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '账单管理' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}

interface PayRequest {
  elder_id: number;
  month: string;
  amount: number;
  reason: string;
}
