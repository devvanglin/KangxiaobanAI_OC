import {
  HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TitleBarStyleOptions, hdsMaterial
} from '@kit.UIDesignKit';
import ApiClient from '../../network/ApiClient';
import { Assessment } from '../../network/Dto';

@ComponentV2
export struct WideAssessmentReportPage {
  @Param @Require assessmentId: number;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};
  @Local assessment: Assessment | null = null;
  @Local loading: boolean = true;
  @Local error: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { void this.loadReport(); }

  private async loadReport(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const response = await ApiClient.get<Assessment>(`/assessments/${this.assessmentId}`);
      if (response.code !== 0 || response.data === undefined) {
        this.error = response.msg || '评估报告加载失败';
      } else if ((response.data.report ?? '').trim().length === 0) {
        this.error = '该评估尚未生成完整报告';
      } else {
        this.assessment = response.data;
      }
    } catch (_error) {
      this.error = '无法连接服务器，评估报告加载失败';
    } finally {
      this.loading = false;
    }
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE },
      scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR }
    };
  }

  @Builder
  private summaryHeader(item: Assessment) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text('AI 综合评估报告').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Blank()
        Text('待医师复核').fontSize(12).fontColor($r('app.color.doctor_workspace_warning'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(10)
          .backgroundColor('rgba(239,159,39,0.14)')
      }.width('100%')
      Text(`评估编号 A${item.id.toString().padStart(6, '0')} · ${item.assessed_at.slice(0, 16)}`)
        .fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
      Text(item.notes).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.loading) {
            Column({ space: 10 }) {
              LoadingProgress().width(36).height(36)
              Text('正在加载评估报告…').fontSize(14).fontColor($r('sys.color.font_secondary'))
            }.width('100%').padding({ top: 120 }).alignItems(HorizontalAlign.Center)
          } else if (this.error.length > 0) {
            Column({ space: 12 }) {
              Text(this.error).fontSize(15).fontColor($r('sys.color.font_secondary'))
              Button('重新加载').height(40).borderRadius(10).onClick(() => { void this.loadReport(); })
            }.width('100%').padding({ top: 120 }).alignItems(HorizontalAlign.Center)
          } else if (this.assessment !== null) {
            this.summaryHeader(this.assessment!)
            Text(this.assessment!.report ?? '')
              .width('100%').fontSize(15).lineHeight(27).fontColor($r('sys.color.font_primary'))
              .padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          }
        }.width('100%').constraintSize({ maxWidth: 1080 })
          .padding({ left: 28, right: 28, top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }
    .hideBackButton(false)
    .onBackPressed((): boolean => { this.onClose(); return true; })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: '评估报告' } }, style: this.titleBarStyle() })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
