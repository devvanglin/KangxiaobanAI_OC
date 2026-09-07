import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { BusinessStore } from '../../network/BusinessStore';
import { Alert } from '../../network/Dto';
import {
  QuickEmptyHint,
  QuickFilterChips,
  QuickMetricStrip,
  quickAlertLevelBgColor,
  quickAlertLevelText,
  quickAlertLevelTextColor,
  quickAlertStatusText,
  quickAlertStatusTone,
  quickElderName
} from './WideDoctorQuickPageKit';

/** 医师端「告警处理」：沉浸式只读路由页，按复核状态筛选服务器告警记录。 */
@ComponentV2
export struct WideDoctorAlertsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local alertFilter: string = 'all';
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

  private alertCount(status: string): number {
    return this.businessStore.alerts.filter((item: Alert) => item.status === status).length;
  }

  private filteredAlerts(): Alert[] {
    if (this.alertFilter === 'all') {
      return this.businessStore.alerts;
    }
    return this.businessStore.alerts.filter((item: Alert) => item.status === this.alertFilter);
  }

  @Builder
  private alertRows() {
    ForEach(this.filteredAlerts(), (alert: Alert) => {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(alert.type || '风险告警')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(quickAlertLevelText(alert.level))
              .fontSize(10)
              .fontColor(quickAlertLevelTextColor(alert.level))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor(quickAlertLevelBgColor(alert.level))
          }.alignItems(VerticalAlign.Center)
          Text(alert.content)
            .fontSize(11.5)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${quickElderName(this.businessStore, alert.elder_id)} · ${alert.handled_by || '未分配'} · ${alert.create_time}`)
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(quickAlertStatusText(alert.status))
          .fontSize(12)
          .fontColor(quickAlertStatusTone(alert.status))
      }
      .width('100%')
      .padding({ top: 13, bottom: 13 })
      .borderWidth({ bottom: 0.5 })
      .borderColor({ bottom: $r('sys.color.comp_divider') })
      .alignItems(VerticalAlign.Center)
    }, (alert: Alert) => `quick-alert-${alert.id}-${alert.status}`)
  }

  @Builder
  private alertsCard() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('告警记录')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        Text(`${this.filteredAlerts().length} 条`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })

      Column({ space: 0 }) {
        if (this.filteredAlerts().length === 0) {
          QuickEmptyHint({ text: '当前筛选下暂无告警', loading: this.businessStore.loading })
        } else {
          this.alertRows()
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
                  label: '全部告警',
                  value: `${this.businessStore.alerts.length}`,
                  tone: $r('sys.color.font_secondary')
                },
                { label: '待复核', value: `${this.alertCount('open')}`, tone: $r('app.color.doctor_workspace_danger') },
                { label: '复核中', value: `${this.alertCount('handled')}`, tone: $r('app.color.doctor_workspace_warning') },
                { label: '已复核', value: `${this.alertCount('closed')}`, tone: $r('app.color.doctor_workspace_success') }
              ]
            })

            QuickFilterChips({
              options: [
                { key: 'all', label: '全部' },
                { key: 'open', label: '待复核' },
                { key: 'handled', label: '复核中' },
                { key: 'closed', label: '已复核' }
              ],
              current: this.alertFilter,
              onSelect: (key: string) => {
                this.alertFilter = key;
              }
            })

            this.alertsCard()
          }
          .width('100%')
          .constraintSize({ maxWidth: 1280 })
          .padding({
            left: this.compactWidth ? 16 : 28,
            right: this.compactWidth ? 16 : 28,
            top: 88 + this.statusBarHeight,
            bottom: 24 + this.naviIndicatorHeight
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
        title: { mainTitle: '告警处理' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
