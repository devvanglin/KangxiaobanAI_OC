import {
  CARE_METRICS,
  DASHBOARD_SECTIONS,
  FACILITY_METRICS,
  OVERVIEW_METRICS,
  SAFETY_METRICS
} from '../../data/DashboardMockData';
import { DashboardMetric, DashboardSection, DashboardSectionItem } from '../../model/DashboardModels';
import { CockpitOverview } from './CockpitOverview';
import { DashboardMetricCard } from './DashboardMetricCard';
import {
  ActionCenterPanel,
  CareExecutionPanel,
  CareTrendPanel,
  FacilityStatusPanel,
  LiveEventPanel,
  RiskSummaryPanel,
  WardCapacityPanel
} from './DashboardPanels';

@ComponentV2
export struct DashboardContent {
  @Param @Require currentSection: DashboardSection;
  @Param @Require pageScroller: Scroller;
  @Event onSectionChange: (section: DashboardSection) => void = (_section: DashboardSection) => {};
  @Local layoutWidth: number = 0;
  @Local currentTime: string = '';
  @Local currentDate: string = '';
  private clockTimer: number = -1;
  private sections: DashboardSectionItem[] = DASHBOARD_SECTIONS;

  aboutToAppear(): void {
    this.updateClock();
    this.clockTimer = setInterval(() => this.updateClock(), 30000);
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : value.toString();
  }

  private updateClock(): void {
    const now: Date = new Date();
    this.currentTime = `${this.twoDigits(now.getHours())}:${this.twoDigits(now.getMinutes())}`;
    const weekdays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    this.currentDate = `${now.getFullYear()}-${this.twoDigits(now.getMonth() + 1)}-${this.twoDigits(now.getDate())} ${weekdays[now.getDay()]}`;
  }

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
      return 20;
    }
    if (this.layoutWidth >= 720) {
      return 16;
    }
    return 12;
  }

  private activeMetrics(): DashboardMetric[] {
    if (this.currentSection === 'care') {
      return CARE_METRICS;
    }
    if (this.currentSection === 'safety') {
      return SAFETY_METRICS;
    }
    if (this.currentSection === 'facility') {
      return FACILITY_METRICS;
    }
    return OVERVIEW_METRICS;
  }

  private sectionTitle(): string {
    const item: DashboardSectionItem | undefined = this.sections.find((section: DashboardSectionItem) =>
      section.id === this.currentSection);
    return item?.label ?? '全院态势';
  }

  private sectionDescription(): string {
    const item: DashboardSectionItem | undefined = this.sections.find((section: DashboardSectionItem) =>
      section.id === this.currentSection);
    return item?.description ?? '床位、人力、任务与风险总览';
  }

  @Builder
  private backgroundGrid() {
    Stack() {
      Column() {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (_rowIndex: number) => {
          Row()
            .width('100%')
            .height(1)
            .backgroundColor($r('app.color.cockpit_grid'))
          Blank()
        })
      }
      .width('100%')
      .height('100%')

      Row() {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (_columnIndex: number) => {
          Column()
            .width(1)
            .height('100%')
            .backgroundColor($r('app.color.cockpit_grid'))
          Blank()
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .opacity(0.18)
    .accessibilityLevel('no-hide-descendants')
  }

  @Builder
  private cockpitHeader() {
    Column({ space: 10 }) {
      Row({ space: 14 }) {
        if (!this.isCompact()) {
          Column({ space: 3 }) {
            Text(this.currentTime)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.cockpit_border_bright'))
            Text(this.currentDate)
              .fontSize(11)
              .fontColor($r('app.color.cockpit_text_secondary'))
          }
          .width(190)
          .alignItems(HorizontalAlign.Start)
          .accessibilityGroup(true)
        }

        Row({ space: this.isCompact() ? 8 : 18 }) {
          Row()
            .layoutWeight(1)
            .height(1)
            .linearGradient({
              angle: 0,
              colors: [[Color.Transparent, 0.0], [$r('app.color.cockpit_border_bright'), 1.0]]
            })

          Column({ space: 3 }) {
            Text('康小伴全院信息中心')
              .fontSize(this.isCompact() ? 20 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.cockpit_text_primary'))
              .letterSpacing(this.isCompact() ? 1 : 3)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('KANXIAOBAN INSTITUTION COMMAND CENTER')
              .fontSize(this.isCompact() ? 8 : 11)
              .fontColor($r('app.color.cockpit_border_bright'))
              .letterSpacing(1)
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Center)

          Row()
            .layoutWeight(1)
            .height(1)
            .linearGradient({
              angle: 0,
              colors: [[$r('app.color.cockpit_border_bright'), 0.0], [Color.Transparent, 1.0]]
            })
        }
        .layoutWeight(1)

        if (!this.isCompact()) {
          Row({ space: 14 }) {
            Column({ space: 3 }) {
              Text('院区数据总线')
                .fontSize(11)
                .fontColor($r('app.color.cockpit_text_secondary'))
              Row({ space: 6 }) {
                Row().width(7).height(7).borderRadius(4).backgroundColor($r('app.color.status_success'))
                Text('本地演示在线')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.status_success'))
              }
            }
            .alignItems(HorizontalAlign.End)

            Stack() {
              SymbolGlyph($r('sys.symbol.bell_fill'))
                .fontSize(21)
                .fontColor([$r('app.color.status_danger')])
              Text('8')
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .width(17)
                .height(17)
                .textAlign(TextAlign.Center)
                .borderRadius(9)
                .backgroundColor($r('app.color.status_danger'))
                .position({ x: 18, y: -7 })
            }
            .width(38)
            .height(34)
            .accessibilityText('8项未闭环预警')
          }
          .width(220)
          .justifyContent(FlexAlign.End)
        }
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 10 })
      .alignItems(VerticalAlign.Center)

      this.sectionSelector()
    }
    .width('100%')
    .backgroundColor($r('app.color.cockpit_panel_strong'))
    .border({ width: { bottom: 1 }, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private sectionSelector() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.sections, (section: DashboardSectionItem) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 8 }) {
              SymbolGlyph(section.symbol)
                .fontSize(18)
                .fontColor([this.currentSection === section.id ? $r('app.color.cockpit_border_bright') :
                  $r('app.color.cockpit_text_secondary')])

              if (!this.isCompact() || this.currentSection === section.id) {
                Text(section.label)
                  .fontSize(12)
                  .fontWeight(this.currentSection === section.id ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.currentSection === section.id ? $r('app.color.cockpit_text_primary') :
                    $r('app.color.cockpit_text_secondary'))
                  .maxLines(1)
              }

              if (section.badge > 0) {
                Text(section.badge.toString())
                  .fontSize(9)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center)
                  .constraintSize({ minWidth: 18 })
                  .height(18)
                  .padding({ left: 4, right: 4 })
                  .borderRadius(9)
                  .backgroundColor(section.id === 'safety' ? $r('app.color.status_danger') :
                    $r('app.color.cockpit_blue'))
              }
            }
          }
          .height(38)
          .padding({ left: 13, right: 13 })
          .borderRadius(2)
          .backgroundColor(this.currentSection === section.id ? $r('app.color.cockpit_panel') : Color.Transparent)
          .border({
            width: 1,
            color: this.currentSection === section.id ? $r('app.color.cockpit_border_bright') :
              $r('app.color.cockpit_grid')
          })
          .onClick(() => this.onSectionChange(section.id))
          .focusable(true)
          .accessibilityText(section.label)
          .accessibilityDescription(section.description)
          .accessibilitySelected(this.currentSection === section.id)
        }, (section: DashboardSectionItem) => section.id)
      }
      .padding({ left: this.pagePadding(), right: this.pagePadding(), bottom: 10 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private metricsGrid() {
    GridRow({ columns: { sm: 4, md: 8, lg: 12 }, gutter: { x: 12, y: 12 } }) {
      ForEach(this.activeMetrics(), (metric: DashboardMetric) => {
        GridCol({ span: { sm: 4, md: 4, lg: 3 } }) {
          DashboardMetricCard({ data: metric })
        }
      }, (metric: DashboardMetric) => metric.id)
    }
    .width('100%')
  }

  @Builder
  private carePanels() {
    GridRow({ columns: { sm: 4, md: 8, lg: 12 }, gutter: { x: 12, y: 12 } }) {
      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) { CareExecutionPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) { CareTrendPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) { WardCapacityPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) { ActionCenterPanel({ sectionTitle: '照护运营关注' }) }
    }
    .width('100%')
  }

  @Builder
  private safetyPanels() {
    GridRow({ columns: { sm: 4, md: 8, lg: 12 }, gutter: { x: 12, y: 12 } }) {
      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) { LiveEventPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) { RiskSummaryPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) { WardCapacityPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) { ActionCenterPanel({ sectionTitle: '安全闭环关注' }) }
    }
    .width('100%')
  }

  @Builder
  private facilityPanels() {
    GridRow({ columns: { sm: 4, md: 8, lg: 12 }, gutter: { x: 12, y: 12 } }) {
      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) { FacilityStatusPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) { WardCapacityPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) { LiveEventPanel() }
      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) { ActionCenterPanel({ sectionTitle: '设备空间关注' }) }
    }
    .width('100%')
  }

  @Builder
  private sectionHeading() {
    Row() {
      Column({ space: 4 }) {
        Text(this.sectionTitle())
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cockpit_text_primary'))
        Text(this.sectionDescription())
          .fontSize(12)
          .fontColor($r('app.color.cockpit_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Row({ space: 7 }) {
        Row().width(7).height(7).borderRadius(4).backgroundColor($r('app.color.status_success'))
        Text('本地演示数据')
          .fontSize(11)
          .fontColor($r('app.color.cockpit_text_secondary'))
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .border({ width: 1, color: $r('app.color.cockpit_grid') })
      .backgroundColor($r('app.color.cockpit_panel'))
      .accessibilityGroup(true)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      this.backgroundGrid()

      Column() {
        this.cockpitHeader()

        Scroll(this.pageScroller) {
          Column({ space: 12 }) {
            if (this.currentSection !== 'overview') {
              this.sectionHeading()
            }

            this.metricsGrid()

            if (this.currentSection === 'care') {
              this.carePanels()
            } else if (this.currentSection === 'safety') {
              this.safetyPanels()
            } else if (this.currentSection === 'facility') {
              this.facilityPanels()
            } else {
              CockpitOverview({ compact: this.isCompact() })
            }

            Text('数据说明：以上内容均为 KanxiaobanDS 本地演示数据，不代表已接入院内业务、设备或告警服务。')
              .fontSize(10)
              .fontColor($r('app.color.cockpit_text_secondary'))
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ top: 6, bottom: 10 })
          }
          .width('100%')
          .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 12, bottom: this.pagePadding() })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.cockpit_background'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateLayoutWidth(newValue.width);
    })
  }
}
