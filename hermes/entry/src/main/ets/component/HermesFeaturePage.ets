import { featureSnapshot } from '../data/HermesCatalog';
import { HermesActivity, HermesFeatureSnapshot, HermesMetric, HermesNavItem } from '../model/HermesModels';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixText
} from '@kit.UIDesignKit';

@ComponentV2
export struct HermesFeaturePage {
  @Param @Require item: HermesNavItem;
  @Param wide: boolean = false;

  private snapshot(): HermesFeatureSnapshot {
    return featureSnapshot(this.item.key);
  }

  @Builder
  private metricCard(metric: HermesMetric) {
    Column({ space: 8 }) {
      Text(metric.label)
        .fontSize($r('app.float.hermes_text_caption'))
        .fontColor($r('app.color.hermes_text_secondary'))
        .width('100%')
      Text(metric.value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hermes_text_primary'))
        .width('100%')
      Text(metric.detail)
        .fontSize($r('app.float.hermes_text_caption'))
        .fontColor($r('app.color.hermes_text_muted'))
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .constraintSize({ minWidth: this.wide ? 180 : 132, maxWidth: this.wide ? 360 : 480 })
    .padding(16)
    .margin({ right: 12, bottom: 12 })
    .backgroundColor($r('app.color.hermes_bg_surface'))
    .borderRadius($r('app.float.hermes_radius_medium'))
    .border({ width: 1, color: $r('app.color.hermes_border') })
  }

  @Builder
  private activityRow(activity: HermesActivity) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SMALL_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.chevron_right'))
            .fontColor([activity.status === 'WARN' || activity.status === '需配置' ?
              $r('app.color.hermes_warning') : $r('app.color.hermes_success')])
        }
      }),
      textItem: {
        primaryText: { text: activity.title },
        secondaryText: { text: activity.detail }
      },
      suffixItem: new SuffixText({ text: this.wide ? `${activity.status} · ${activity.time}` : activity.status }),
      cardHeight: 70,
      cardBorderRadius: 0,
      hoverBorderRadius: 0,
      cardPrefixMargin: 2,
      cardSuffixMargin: 0,
      cardBackgroundColor: Color.Transparent,
      accessibilityOptions: {
        accessibilityText: `${activity.title}，${activity.status}，${activity.detail}`,
        accessibilityDescription: activity.time,
        accessibilityLevel: 'yes'
      }
    })
    .width('100%')
    .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border_light') })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 18 }) {
          Text(this.item.description)
            .fontSize($r('app.float.hermes_text_body'))
            .fontColor($r('app.color.hermes_text_secondary'))
            .width('100%')

          Text($r('app.string.mock_data_notice'))
            .fontSize(11)
            .fontColor($r('app.color.hermes_warning'))
            .width('100%')
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.hermes_bg_secondary'))
            .borderRadius($r('app.float.hermes_radius_small'))

          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.snapshot().metrics, (metric: HermesMetric) => {
              this.metricCard(metric)
            }, (metric: HermesMetric) => metric.label)
          }
          .width('100%')

          Column() {
            HdsListItemCard({
              textItem: { primaryText: { text: '最近活动' } },
              suffixItem: new SuffixText({ text: '查看全部' }),
              cardHeight: 50,
              cardBorderRadius: 0,
              hoverBorderRadius: 0,
              cardPrefixMargin: 0,
              cardSuffixMargin: 0,
              cardBackgroundColor: Color.Transparent,
              accessibilityOptions: {
                accessibilityText: '最近活动',
                accessibilityLevel: 'yes'
              }
            })
            .width('100%')
            .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border') })

            ForEach(this.snapshot().activities, (activity: HermesActivity) => {
              this.activityRow(activity)
            }, (activity: HermesActivity) => `${activity.title}-${activity.time}`)
          }
          .width('100%')
          .backgroundColor($r('app.color.hermes_bg_surface'))
          .borderRadius($r('app.float.hermes_radius_medium'))
          .border({ width: 1, color: $r('app.color.hermes_border') })

          Column({ space: 10 }) {
            Text('上游功能覆盖')
              .fontSize($r('app.float.hermes_text_title'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_text_primary'))
            Text('该页面已纳入原生导航与多端布局骨架。真实数据、编辑表单、服务调用和错误恢复将按照移植记忆中的覆盖表逐项替换。')
              .fontSize($r('app.float.hermes_text_body'))
              .fontColor($r('app.color.hermes_text_secondary'))
              .lineHeight(22)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.hermes_bg_surface'))
          .borderRadius($r('app.float.hermes_radius_medium'))
          .border({ width: 1, color: $r('app.color.hermes_border') })
        }
        .width('100%')
        .padding(this.wide ? 22 : 14)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_primary'))
  }
}
