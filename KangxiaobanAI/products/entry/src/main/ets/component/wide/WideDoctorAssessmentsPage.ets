import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { TextModifier } from '@ohos.arkui.modifier';
import { BusinessStore } from '../../network/BusinessStore';
import { Assessment } from '../../network/Dto';
import {
  QuickEmptyHint,
  QuickMetricStrip,
  quickElderName,
  quickRiskText,
  quickRiskTone
} from './WideDoctorQuickPageKit';

/** 医师端「健康评估」：沉浸式只读路由页，展示服务器评估记录与风险分级。 */
@ComponentV2
export struct WideDoctorAssessmentsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
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

  private riskCount(match: (risk: string) => boolean): number {
    return this.businessStore.assessments.filter((item: Assessment) => match(item.risk_level)).length;
  }

  private riskToneModifier(risk: string): TextModifier {
    return new TextModifier().fontColor(quickRiskTone(risk));
  }

  @Builder
  private assessmentRows() {
    ForEach(this.businessStore.assessments, (item: Assessment) => {
      HdsListItemCard({
        textItem: {
          primaryText: { text: item.assessment_type },
          secondaryText: {
            text: `${quickElderName(this.businessStore, item.elder_id)} · ${item.assessed_at}`
          }
        },
        suffixItem: new SuffixText({
          text: item.risk_level.length > 0 ? quickRiskText(item.risk_level) : '--',
          modifier: this.riskToneModifier(item.risk_level)
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 64,
        hoverBorderRadius: 0
      })
    }, (item: Assessment) => `quick-assessment-${item.id}`)
  }

  @Builder
  private assessmentsCard() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('评估记录')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        Text(`${this.businessStore.assessments.length} 份`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })

      Column({ space: 0 }) {
        if (this.businessStore.assessments.length === 0) {
          QuickEmptyHint({ text: '暂无健康评估记录', loading: this.businessStore.loading })
        } else {
          this.assessmentRows()
        }
      }
      .width('100%')
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
                  label: '评估总数',
                  value: `${this.businessStore.assessments.length}`,
                  tone: $r('sys.color.font_secondary')
                },
                {
                  label: '高风险',
                  value: `${this.riskCount((risk: string) => risk === 'high' || risk === 'danger')}`,
                  tone: $r('app.color.doctor_workspace_danger')
                },
                {
                  label: '中风险',
                  value: `${this.riskCount((risk: string) => risk === 'medium' || risk === 'warning')}`,
                  tone: $r('app.color.doctor_workspace_warning')
                },
                {
                  label: '低风险',
                  value: `${this.riskCount((risk: string) => risk === 'low')}`,
                  tone: $r('app.color.doctor_workspace_success')
                }
              ]
            })

            this.assessmentsCard()
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
        title: { mainTitle: '健康评估' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
