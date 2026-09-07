import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { BusinessStore } from '../../network/BusinessStore';
import { Bill } from '../../network/Dto';
import {
  QuickEmptyHint,
  QuickFilterChips,
  QuickMetricStrip,
  quickBillStatusText,
  quickBillStatusTone,
  quickBillTotal,
  quickElderName
} from './WideDoctorQuickPageKit';

/** 医师端「账单管理」：沉浸式只读路由页，按支付状态筛选账单与金额汇总。 */
@ComponentV2
export struct WideDoctorBillsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local billFilter: string = 'all';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    void this.businessStore.load();
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

  private filteredBills(): Bill[] {
    if (this.billFilter === 'all') {
      return this.businessStore.bills;
    }
    return this.businessStore.bills.filter((item: Bill) => item.status === this.billFilter);
  }

  @Builder
  private billRows() {
    ForEach(this.filteredBills(), (bill: Bill) => {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(`${quickElderName(this.businessStore, bill.elder_id)} · ${bill.bill_month}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`床位费 ¥${bill.bed_fee} · 护理费 ¥${bill.nursing_fee} · 餐费 ¥${bill.meal_fee}`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`¥${bill.amount.toFixed(2)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(quickBillStatusText(bill))
          .fontSize(12)
          .fontColor(quickBillStatusTone(bill))
      }
      .width('100%')
      .padding({ top: 13, bottom: 13 })
      .borderWidth({ bottom: 0.5 })
      .borderColor({ bottom: $r('sys.color.comp_divider') })
      .alignItems(VerticalAlign.Center)
    }, (bill: Bill) => `quick-bill-${bill.id}`)
  }

  @Builder
  private billsCard() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('账单列表')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        Text(`${this.filteredBills().length} 张`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })

      Column({ space: 0 }) {
        if (this.filteredBills().length === 0) {
          QuickEmptyHint({ text: '当前筛选下暂无账单', loading: this.businessStore.loading })
        } else {
          this.billRows()
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 10 })
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 16 }) {
            QuickMetricStrip({
              metrics: [
                {
                  label: '账单总数',
                  value: `${this.businessStore.bills.length}`,
                  tone: $r('sys.color.font_secondary')
                },
                {
                  label: '应收总额',
                  value: `¥${quickBillTotal(this.businessStore, (_bill: Bill) => true)}`,
                  tone: $r('sys.color.font_secondary')
                },
                {
                  label: '已收金额',
                  value: `¥${quickBillTotal(this.businessStore, (bill: Bill) => bill.status === 'paid')}`,
                  tone: $r('app.color.doctor_workspace_success')
                },
                {
                  label: '待收金额',
                  value: `¥${quickBillTotal(this.businessStore, (bill: Bill) => bill.status !== 'paid')}`,
                  tone: $r('app.color.doctor_workspace_warning')
                }
              ]
            })

            QuickFilterChips({
              options: [
                { key: 'all', label: '全部' },
                { key: 'paid', label: '已支付' },
                { key: 'unpaid', label: '待支付' }
              ],
              current: this.billFilter,
              onSelect: (key: string) => {
                this.billFilter = key;
              }
            })

            this.billsCard()
          }
          .width('100%')
          .constraintSize({ maxWidth: this.compactWidth ? 1040 : 1320 })
          .padding({
            left: this.compactWidth ? 16 : 24,
            right: this.compactWidth ? 16 : 24,
            top: this.statusBarHeight + 56,
            bottom: 20 + this.naviIndicatorHeight
          })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
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
