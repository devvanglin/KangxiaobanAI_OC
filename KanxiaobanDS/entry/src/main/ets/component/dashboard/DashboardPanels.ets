import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsListItemCard, IconSize, PrefixIcon, SuffixText } from '@kit.UIDesignKit';
import {
  CARE_TREND,
  CARE_WORK_ITEMS,
  FACILITY_STATUSES,
  LIVE_EVENTS,
  RISK_SUMMARIES,
  WARD_STATUSES
} from '../../data/DashboardMockData';
import {
  CareWorkItem,
  DashboardEvent,
  DashboardTone,
  FacilityStatus,
  RiskSummary,
  TrendPoint,
  WardStatus
} from '../../model/DashboardModels';
import { dashboardProgressWidth, dashboardToneColor, dashboardToneSoftColor } from './DashboardStyle';

@Builder
function PanelHeading(title: string, subtitle: string, symbol: Resource) {
  Row({ space: 12 }) {
    Stack() {
      SymbolGlyph(symbol)
        .fontSize(21)
        .fontColor([$r('app.color.brand_primary')])
    }
    .width(40)
    .height(40)
    .borderRadius(2)
    .backgroundColor($r('app.color.cockpit_panel_strong'))
    .border({ width: 1, color: $r('app.color.cockpit_border_bright') })

    Column({ space: 3 }) {
      Text(title)
        .fontSize($r('sys.float.Title_M'))
        .fontColor($r('app.color.cockpit_text_primary'))
        .fontWeight(FontWeight.Bold)
      Text(subtitle)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.cockpit_text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
  .width('100%')
  .alignItems(VerticalAlign.Center)
}

@ComponentV2
export struct ExecutiveSummaryPanel {
  @Param title: string = '院级运行摘要';
  @Param description: string = '本地演示数据用于验证驾驶舱信息架构，尚未接入院内业务系统。';
  @Param compact: boolean = false;

  build() {
    Flex({ direction: this.compact ? FlexDirection.Column : FlexDirection.Row, alignItems: ItemAlign.Center }) {
      Row({ space: 14 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.AI_message'))
            .fontSize(28)
            .fontColor([$r('app.color.brand_primary')])
        }
        .width(52)
        .height(52)
        .borderRadius(2)
        .backgroundColor($r('app.color.cockpit_panel_strong'))
        .border({ width: 1, color: $r('app.color.cockpit_border_bright') })

        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(this.title)
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.cockpit_text_primary'))
            Text('演示')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.brand_primary'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor($r('app.color.brand_soft'))
              .borderRadius(8)
          }
          Text(this.description)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.cockpit_text_secondary'))
            .maxLines(this.compact ? 3 : 2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)

      if (!this.compact) {
        Row({ space: 18 }) {
          Column({ space: 2 }) {
            Text('4')
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.cockpit_text_primary'))
            Text('任务域')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.cockpit_text_secondary'))
          }
          Column({ space: 2 }) {
            Text('8')
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.status_danger'))
            Text('未闭环')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.cockpit_text_secondary'))
          }
        }
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
    .accessibilityGroup(true)
  }
}

@ComponentV2
export struct WardCapacityPanel {
  private wards: WardStatus[] = WARD_STATUSES;

  build() {
    Column({ space: 18 }) {
      PanelHeading('楼层运行', '床位、人力、任务与风险同屏对照', $r('sys.symbol.building_fill'))

      Column({ space: 16 }) {
        ForEach(this.wards, (ward: WardStatus) => {
          Column({ space: 10 }) {
            Row() {
              Column({ space: 3 }) {
                Text(ward.name)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(`${ward.floor} · ${ward.residents}/${ward.capacity} 人`)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Column({ space: 3 }) {
                Text(`${ward.occupancy.toFixed(1)}%`)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('sys.color.font_primary'))
                Text(`在岗 ${ward.staffOnDuty} · 待办 ${ward.openTasks} · 风险 ${ward.riskCount}`)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')

            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.chart_track'))
              Row()
                .width(dashboardProgressWidth(ward.occupancy))
                .height(8)
                .borderRadius(4)
                .backgroundColor(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
            }
            .width('100%')
            .height(8)
          }
          .width('100%')
          .accessibilityGroup(true)
          .accessibilityText(`${ward.name}，${ward.floor}，床位使用率${ward.occupancy.toFixed(1)}%，在岗${ward.staffOnDuty}人，待办${ward.openTasks}项，风险${ward.riskCount}项`)
        }, (ward: WardStatus) => ward.id)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
export struct CareTrendPanel {
  private points: TrendPoint[] = CARE_TREND;

  build() {
    Column({ space: 18 }) {
      PanelHeading('近七日服务质量', '任务完成率与交接完整率', $r('sys.symbol.waveform_path_ecg_magnifyingglass'))

      Row({ space: 14 }) {
        Row({ space: 6 }) {
          Row().width(10).height(10).borderRadius(5).backgroundColor($r('app.color.brand_primary'))
          Text('任务完成率').fontSize($r('sys.float.Body_S')).fontColor($r('sys.color.font_secondary'))
        }
        Row({ space: 6 }) {
          Row().width(10).height(10).borderRadius(5).backgroundColor($r('app.color.status_success'))
          Text('交接完整率').fontSize($r('sys.float.Body_S')).fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.points, (point: TrendPoint) => {
          Column({ space: 8 }) {
            Row({ space: 4 }) {
              Row()
                .width(10)
                .height(Math.max(18, point.value * 1.1))
                .borderRadius(5)
                .backgroundColor($r('app.color.brand_primary'))
              Row()
                .width(10)
                .height(Math.max(18, point.secondaryValue * 1.1))
                .borderRadius(5)
                .backgroundColor($r('app.color.status_success'))
            }
            .height(112)
            .alignItems(VerticalAlign.Bottom)

            Text(point.label)
              .fontSize($r('sys.float.Body_S'))
              .fontColor(point.label === '今日' ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
              .fontWeight(point.label === '今日' ? FontWeight.Medium : FontWeight.Regular)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .accessibilityGroup(true)
          .accessibilityText(`${point.label}，任务完成率${point.value}%，交接完整率${point.secondaryValue}%`)
        }, (point: TrendPoint) => point.label)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
export struct RiskSummaryPanel {
  private risks: RiskSummary[] = RISK_SUMMARIES;

  build() {
    Column({ space: 18 }) {
      PanelHeading('风险结构', '当前 8 项未闭环事件的类型分布', $r('sys.symbol.checkmark_shield_fill'))

      Column({ space: 14 }) {
        ForEach(this.risks, (risk: RiskSummary) => {
          Column({ space: 8 }) {
            Row() {
              Row({ space: 8 }) {
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(5)
                  .backgroundColor(dashboardToneColor(risk.tone))
                Text(risk.label)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_primary'))
              }
              Blank()
              Text(`${risk.count} 项 · ${risk.ratio}%`)
                .fontSize($r('sys.float.Body_S'))
                .fontColor(dashboardToneColor(risk.tone))
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')

            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(8).borderRadius(4).backgroundColor($r('app.color.chart_track'))
              Row()
                .width(dashboardProgressWidth(risk.ratio))
                .height(8)
                .borderRadius(4)
                .backgroundColor(dashboardToneColor(risk.tone))
            }
            .width('100%')
          }
          .accessibilityGroup(true)
          .accessibilityText(`${risk.label}${risk.count}项，占比${risk.ratio}%`)
        }, (risk: RiskSummary) => risk.id)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
export struct LiveEventPanel {
  private events: DashboardEvent[] = LIVE_EVENTS;

  private eventIcon(event: DashboardEvent): Resource {
    return event.tone === 'success' ? $r('sys.symbol.checkmark_circle_fill') :
      $r('sys.symbol.exclamationmark_triangle_fill');
  }

  build() {
    Column({ space: 14 }) {
      PanelHeading('实时事件流', '按紧急程度与发生时间组织', $r('sys.symbol.bell_fill'))

      List() {
        ForEach(this.events, (event: DashboardEvent) => {
          ListItem() {
            HdsListItemCard({
              prefixItem: new PrefixIcon({
                iconSize: IconSize.SYSTEM_ICON,
                iconValue: {
                  symbol: new SymbolGlyphModifier(this.eventIcon(event))
                    .fontColor([dashboardToneColor(event.tone)])
                }
              }),
              textItem: {
                primaryText: { text: `${event.title} · ${event.level}` },
                secondaryText: { text: `${event.location} · ${event.detail}` }
              },
              suffixItem: new SuffixText({ text: event.time }),
              cardHeight: 72,
              cardBorderRadius: 0,
              cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
              cardPrefixMargin: 0,
              cardSuffixMargin: 0
            })
          }
          .focusable(true)
          .accessibilityText(`${event.time}，${event.level}，${event.title}，${event.location}，${event.detail}`)
        }, (event: DashboardEvent) => event.id)
      }
      .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider'), startMargin: 50, endMargin: 12 })
      .height(this.events.length * 72)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
export struct CareExecutionPanel {
  private workItems: CareWorkItem[] = CARE_WORK_ITEMS;

  private completion(item: CareWorkItem): number {
    return item.total > 0 ? item.completed / item.total * 100 : 0;
  }

  build() {
    Column({ space: 18 }) {
      PanelHeading('照护执行看板', '按服务类型检查完成量与超时量', $r('sys.symbol.calendar_badge_clock'))

      Column({ space: 16 }) {
        ForEach(this.workItems, (item: CareWorkItem) => {
          Column({ space: 9 }) {
            Row() {
              Column({ space: 3 }) {
                Text(item.label)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(`${item.owner} · ${item.completed}/${item.total} 项`)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Text(item.overdue > 0 ? `超时 ${item.overdue}` : '无超时')
                .fontSize($r('sys.float.Body_S'))
                .fontColor(item.overdue > 0 ? $r('app.color.status_danger') : $r('app.color.status_success'))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .borderRadius(10)
                .backgroundColor(item.overdue > 0 ? $r('app.color.status_danger_soft') :
                  $r('app.color.status_success_soft'))
            }
            .width('100%')

            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(8).borderRadius(4).backgroundColor($r('app.color.chart_track'))
              Row()
                .width(dashboardProgressWidth(this.completion(item)))
                .height(8)
                .borderRadius(4)
                .backgroundColor(item.overdue > 0 ? $r('app.color.status_warning') : $r('app.color.status_success'))
            }
            .width('100%')
          }
          .accessibilityGroup(true)
          .accessibilityText(`${item.label}，${item.owner}，已完成${item.completed}项，共${item.total}项，超时${item.overdue}项`)
        }, (item: CareWorkItem) => item.id)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
export struct FacilityStatusPanel {
  private facilities: FacilityStatus[] = FACILITY_STATUSES;

  private onlineRatio(item: FacilityStatus): number {
    return item.total > 0 ? item.online / item.total * 100 : 0;
  }

  build() {
    Column({ space: 18 }) {
      PanelHeading('设备运行', '关键设备在线率与异常摘要', $r('sys.symbol.hammer_fill'))

      GridRow({ columns: { sm: 4, md: 8, lg: 8 }, gutter: { x: 12, y: 12 } }) {
        ForEach(this.facilities, (item: FacilityStatus) => {
          GridCol({ span: { sm: 4, md: 4, lg: 4 } }) {
            Column({ space: 12 }) {
              Row() {
                Stack() {
                  SymbolGlyph(item.symbol)
                    .fontSize(22)
                    .fontColor([$r('app.color.brand_primary')])
                }
                .width(40)
                .height(40)
                .borderRadius(13)
                .backgroundColor($r('app.color.brand_soft'))
                Blank()
                Text(`${this.onlineRatio(item).toFixed(1)}%`)
                  .fontSize($r('sys.float.Title_S'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
                    $r('app.color.status_success'))
              }
              .width('100%')

              Column({ space: 4 }) {
                Text(item.label)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(`${item.online}/${item.total} 在线`)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
                Text(item.note)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_tertiary'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .constraintSize({ minHeight: 152 })
            .padding(16)
            .backgroundColor($r('app.color.cockpit_panel_strong'))
            .border({ width: 1, color: $r('app.color.cockpit_grid') })
            .borderRadius(3)
            .accessibilityGroup(true)
            .accessibilityText(`${item.label}，${item.online}/${item.total}在线，${item.note}`)
          }
        }, (item: FacilityStatus) => item.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
export struct ActionCenterPanel {
  @Param sectionTitle: string = '今日院级关注';

  build() {
    Column({ space: 16 }) {
      PanelHeading(this.sectionTitle, '把跨楼层、跨班组的问题集中到可执行事项', $r('sys.symbol.AI_message'))

      Column({ space: 12 }) {
        this.actionItem('东区二层床位接近满载', '评估西区可用床位与转区安排', '运营', 'warning')
        this.actionItem('夜班存在 2 人排班缺口', '在 16:00 前完成跨组协调', '人力', 'danger')
        this.actionItem('2 台生命体征设备持续离线', '设备班组现场复核网络与电源', '设备', 'warning')
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }

  @Builder
  private actionItem(title: string, detail: string, owner: string, tone: DashboardTone) {
    Row({ space: 12 }) {
      Row()
        .width(5)
        .height(42)
        .borderRadius(3)
        .backgroundColor(dashboardToneColor(tone))
      Column({ space: 4 }) {
        Text(title)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(detail)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(owner)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(dashboardToneColor(tone))
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor(dashboardToneSoftColor(tone))
    }
    .width('100%')
    .padding(12)
    .borderRadius(2)
    .backgroundColor($r('app.color.cockpit_panel_strong'))
    .border({ width: 1, color: $r('app.color.cockpit_grid') })
    .accessibilityGroup(true)
    .accessibilityText(`${owner}关注，${title}，${detail}`)
  }
}
