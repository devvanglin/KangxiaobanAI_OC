import { CockpitOverview } from './CockpitOverview';

@ComponentV2
export struct DashboardContent {
  @Local layoutWidth: number = 0;
  @Local layoutHeight: number = 0;

  private lengthValue(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return parseFloat(value);
    }
    return 0;
  }

  private updateLayoutSize(width: Length, height: Length): void {
    const nextWidth: number = this.lengthValue(width);
    const nextHeight: number = this.lengthValue(height);
    if (nextWidth > 0 && Math.abs(nextWidth - this.layoutWidth) > 0.5) {
      this.layoutWidth = nextWidth;
    }
    if (nextHeight > 0 && Math.abs(nextHeight - this.layoutHeight) > 0.5) {
      this.layoutHeight = nextHeight;
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

  build() {
    CockpitOverview({
      compact: this.isCompact(),
      layoutWidth: this.layoutWidth,
      layoutHeight: this.layoutHeight
    })
    .width('100%')
    .height('100%')
    .padding(this.pagePadding())
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateLayoutSize(newValue.width, newValue.height);
    })
  }
}
