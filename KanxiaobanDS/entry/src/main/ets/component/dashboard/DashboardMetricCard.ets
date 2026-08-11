import { DashboardMetric } from '../../model/DashboardModels';
import { dashboardToneColor, dashboardToneSoftColor } from './DashboardStyle';

@ComponentV2
export struct DashboardMetricCard {
  @Param @Require data: DashboardMetric;

  build() {
    Column({ space: 16 }) {
      Row() {
        Stack() {
          SymbolGlyph(this.data.symbol)
            .fontSize(24)
            .fontColor([dashboardToneColor(this.data.tone)])
        }
        .width(48)
        .height(48)
        .borderRadius(16)
        .backgroundColor(dashboardToneSoftColor(this.data.tone))

        Blank()

        Text(this.data.trend)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(dashboardToneColor(this.data.tone))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor(dashboardToneSoftColor(this.data.tone))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 6 }) {
        Text(this.data.label)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .fontWeight(FontWeight.Medium)

        Row({ space: 6 }) {
          Text(this.data.value)
            .fontSize(34)
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Bold)
            .maxLines(1)

          Text(this.data.unit)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 4 })
        }
        .alignItems(VerticalAlign.Bottom)

        Text(this.data.note)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 176 })
    .padding(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level8'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .accessibilityGroup(true)
    .accessibilityText(`${this.data.label}，${this.data.value}${this.data.unit}，${this.data.trend}，${this.data.note}`)
  }
}
