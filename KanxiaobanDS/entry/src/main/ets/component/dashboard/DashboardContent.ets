import { CockpitOverview } from './CockpitOverview';

@ComponentV2
export struct DashboardContent {
  @Param @Require pageScroller: Scroller;
  @Local layoutWidth: number = 0;

  private lengthValue(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return parseFloat(value);
    }
    return 0;
  }

  private updateLayoutWidth(width: Length): void {
    const nextWidth: number = this.lengthValue(width);
    if (nextWidth > 0 && Math.abs(nextWidth - this.layoutWidth) > 0.5) {
      this.layoutWidth = nextWidth;
    }
  }

  private isCompact(): boolean {
    return this.layoutWidth > 0 && this.layoutWidth < 720;
  }

  private pagePadding(): number {
    if (this.layoutWidth >= 1180) {
      return 24;
    }
    if (this.layoutWidth >= 720) {
      return 20;
    }
    return 12;
  }

  @Builder
  private dataNotice() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor([$r('app.color.brand_primary')])
      Text('房间、住户、照护、设备与告警内容均为 KanxiaobanDS 本地演示数据，尚未接入院内业务服务。')
        .layoutWeight(1)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.brand_soft'))
    .accessibilityGroup(true)
  }

  build() {
    Scroll(this.pageScroller) {
      Column({ space: 16 }) {
        CockpitOverview({ compact: this.isCompact() })
        this.dataNotice()
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 68, bottom: this.pagePadding() })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateLayoutWidth(newValue.width);
    })
  }
}
