import {
  CARE_TREND,
  FACILITY_STATUSES,
  LIVE_EVENTS,
  WARD_STATUSES
} from '../../data/DashboardMockData';
import {
  DashboardEvent,
  DashboardTone,
  FacilityStatus,
  TrendPoint,
  WardStatus
} from '../../model/DashboardModels';
import { dashboardProgressWidth, dashboardToneColor } from './DashboardStyle';

interface CampusBuilding {
  id: string;
  name: string;
  area: string;
  floors: number;
  residents: number;
  status: string;
  tone: DashboardTone;
}

const CAMPUS_BUILDINGS: CampusBuilding[] = [
  { id: 'east-a', name: '东区 A 栋', area: '失能照护', floors: 5, residents: 94, status: '高负荷', tone: 'warning' },
  { id: 'east-b', name: '东区 B 栋', area: '认知症照护', floors: 7, residents: 78, status: '正常', tone: 'success' },
  { id: 'medical', name: '医养中心', area: '医疗协同', floors: 9, residents: 52, status: '关注', tone: 'brand' },
  { id: 'west-a', name: '西区 A 栋', area: '自理生活', floors: 6, residents: 91, status: '正常', tone: 'success' },
  { id: 'west-b', name: '西区 B 栋', area: '综合照护', floors: 8, residents: 41, status: '告警', tone: 'danger' }
];

@Builder
function CockpitPanelTitle(title: string, subtitle: string, symbol: Resource) {
  Column({ space: 8 }) {
    Row({ space: 9 }) {
      Row()
        .width(4)
        .height(18)
        .backgroundColor($r('app.color.cockpit_border_bright'))
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor([$r('app.color.cockpit_border_bright')])
      Text(title)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.cockpit_text_primary'))
      Blank()
      Text(subtitle)
        .fontSize(11)
        .fontColor($r('app.color.cockpit_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')

    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(1)
        .backgroundColor($r('app.color.cockpit_border'))
      Row()
        .width(76)
        .height(2)
        .backgroundColor($r('app.color.cockpit_border_bright'))
    }
    .width('100%')
    .height(2)
  }
  .width('100%')
}

@ComponentV2
export struct CockpitOverview {
  @Param compact: boolean = false;

  build() {
    GridRow({ columns: { sm: 4, md: 8, lg: 12 }, gutter: { x: 12, y: 12 } }) {
      GridCol({ span: { sm: 4, md: 8, lg: 3 } }) {
        Column({ space: 12 }) {
          CockpitBedPanel()
          CockpitWorkforcePanel()
        }
      }

      GridCol({ span: { sm: 4, md: 8, lg: 6 } }) {
        CockpitCampusPanel({ compact: this.compact })
      }

      GridCol({ span: { sm: 4, md: 8, lg: 3 } }) {
        CockpitAlarmPanel()
      }

      GridCol({ span: { sm: 4, md: 8, lg: 7 } }) {
        CockpitTrendPanel()
      }

      GridCol({ span: { sm: 4, md: 8, lg: 5 } }) {
        CockpitDevicePanel()
      }
    }
    .width('100%')
  }
}

@ComponentV2
struct CockpitBedPanel {
  private wards: WardStatus[] = WARD_STATUSES;

  build() {
    Column({ space: 14 }) {
      CockpitPanelTitle('床位运行', 'BED CAPACITY', $r('sys.symbol.building_fill'))

      Row() {
        Column({ space: 3 }) {
          Text('356')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.cockpit_border_bright'))
          Text('在院长者')
            .fontSize(11)
            .fontColor($r('app.color.cockpit_text_secondary'))
        }
        .layoutWeight(1)
        Column({ space: 3 }) {
          Text('92.4%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.status_warning'))
          Text('床位使用率')
            .fontSize(11)
            .fontColor($r('app.color.cockpit_text_secondary'))
        }
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 11 }) {
        ForEach(this.wards, (ward: WardStatus) => {
          Column({ space: 6 }) {
            Row() {
              Text(ward.name)
                .fontSize(12)
                .fontColor($r('app.color.cockpit_text_primary'))
              Blank()
              Text(`${ward.residents}/${ward.capacity}`)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(ward.occupancy >= 96 ? $r('app.color.status_warning') :
                  $r('app.color.cockpit_border_bright'))
            }
            .width('100%')
            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(5).backgroundColor($r('app.color.chart_track'))
              Row()
                .width(dashboardProgressWidth(ward.occupancy))
                .height(5)
                .backgroundColor(ward.occupancy >= 96 ? $r('app.color.status_warning') :
                  $r('app.color.cockpit_border_bright'))
            }
            .width('100%')
            .height(5)
          }
          .accessibilityGroup(true)
          .accessibilityText(`${ward.name}床位${ward.residents}/${ward.capacity}，使用率${ward.occupancy}%`)
        }, (ward: WardStatus) => ward.id)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
struct CockpitWorkforcePanel {
  build() {
    Column({ space: 14 }) {
      CockpitPanelTitle('班组态势', 'WORKFORCE', $r('sys.symbol.person_2_fill'))

      GridRow({ columns: 4, gutter: { x: 8, y: 8 } }) {
        GridCol({ span: 2 }) {
          this.staffCell('护理在岗', '52', '96.3%', 'success')
        }
        GridCol({ span: 2 }) {
          this.staffCell('医护协同', '17', '100%', 'brand')
        }
        GridCol({ span: 2 }) {
          this.staffCell('生活照护', '18', '94.7%', 'warning')
        }
        GridCol({ span: 2 }) {
          this.staffCell('夜班缺口', '2', '待协调', 'danger')
        }
      }
      .width('100%')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar_badge_clock'))
          .fontSize(18)
          .fontColor([$r('app.color.status_warning')])
        Column({ space: 3 }) {
          Text('下一交接节点 17:30')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.cockpit_text_primary'))
          Text('4 条交接记录仍缺少复查点')
            .fontSize(11)
            .fontColor($r('app.color.cockpit_text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(10)
      .backgroundColor($r('app.color.cockpit_panel_strong'))
      .border({ width: 1, color: $r('app.color.cockpit_grid') })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }

  @Builder
  private staffCell(label: string, value: string, note: string, tone: DashboardTone) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.cockpit_text_primary'))
      Text(note)
        .fontSize(10)
        .fontColor($r('app.color.cockpit_text_secondary'))
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .backgroundColor($r('app.color.cockpit_panel_strong'))
    .border({ width: 1, color: $r('app.color.cockpit_grid') })
    .alignItems(HorizontalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}，${note}`)
  }
}

@ComponentV2
struct CockpitCampusPanel {
  @Param compact: boolean = false;
  private buildings: CampusBuilding[] = CAMPUS_BUILDINGS;

  private buildingHeight(building: CampusBuilding): number {
    return (this.compact ? 26 : 34) + building.floors * (this.compact ? 7 : 10);
  }

  build() {
    Column({ space: 12 }) {
      CockpitPanelTitle('全院空间态势', 'CAMPUS DIGITAL TWIN', $r('sys.symbol.square_grid_2x2'))

      Row({ space: 8 }) {
        this.statusChip('正常区域', '3', 'success')
        this.statusChip('关注区域', '1', 'warning')
        this.statusChip('告警区域', '1', 'danger')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        Column() {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (_gridLineIndex: number) => {
            Row()
              .width('100%')
              .height(1)
              .backgroundColor($r('app.color.cockpit_grid'))
            Blank()
          })
        }
        .width('100%')
        .height('100%')
        .opacity(0.55)

        Column({ space: 14 }) {
          Row() {
            Text('北门')
              .fontSize(10)
              .fontColor($r('app.color.cockpit_text_secondary'))
            Blank()
            Text('院区数据总线在线')
              .fontSize(10)
              .fontColor($r('app.color.status_success'))
          }
          .width('100%')

          Row({ space: this.compact ? 7 : 12 }) {
            ForEach(this.buildings, (building: CampusBuilding) => {
              Column({ space: 7 }) {
                Text(building.status)
                  .fontSize(10)
                  .fontColor(dashboardToneColor(building.tone))
                  .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                  .border({ width: 1, color: dashboardToneColor(building.tone) })
                  .backgroundColor($r('app.color.cockpit_panel_strong'))

                Stack({ alignContent: Alignment.Bottom }) {
                  Column() {
                    ForEach(Array.from({ length: building.floors }, (_value: undefined, index: number) => index),
                      (floor: number) => {
                        Row({ space: 4 }) {
                          ForEach([0, 1, 2], (windowIndex: number) => {
                            Row()
                              .layoutWeight(1)
                              .height(4)
                              .backgroundColor((floor + windowIndex) % 3 === 0 ?
                                dashboardToneColor(building.tone) : $r('app.color.cockpit_grid'))
                          })
                        }
                        .width('100%')
                        .layoutWeight(1)
                        .padding({ left: 5, right: 5 })
                      })
                  }
                  .width('100%')
                  .height(this.buildingHeight(building))
                  .padding({ top: 8, bottom: 6 })
                  .linearGradient({
                    angle: 180,
                    colors: [[$r('app.color.cockpit_panel_strong'), 0.0], [dashboardToneColor(building.tone), 1.0]]
                  })
                  .border({ width: 1, color: dashboardToneColor(building.tone) })

                  Row()
                    .width('70%')
                    .height(4)
                    .backgroundColor(dashboardToneColor(building.tone))
                    .opacity(0.75)
                }
                .width('100%')
                .height(this.buildingHeight(building))

                Column({ space: 2 }) {
                  Text(building.name)
                    .fontSize(this.compact ? 9 : 11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.cockpit_text_primary'))
                    .maxLines(1)
                  Text(`${building.residents} 人`)
                    .fontSize(9)
                    .fontColor($r('app.color.cockpit_text_secondary'))
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
              .accessibilityGroup(true)
              .accessibilityText(`${building.name}，${building.area}，${building.residents}人，状态${building.status}`)
            }, (building: CampusBuilding) => building.id)
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)

          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width('100%')
              .height(26)
              .border({ width: 1, color: $r('app.color.cockpit_border') })
              .backgroundColor($r('app.color.cockpit_panel_strong'))
            Row({ space: 18 }) {
              ForEach([0, 1, 2, 3, 4, 5, 6], (_roadMarkIndex: number) => {
                Row().width(18).height(2).backgroundColor($r('app.color.cockpit_border_bright'))
              })
            }
          }
          .width('100%')
          .height(26)
        }
        .width('100%')
        .height('100%')
        .padding(16)
      }
      .width('100%')
      .height(this.compact ? 350 : 470)
      .backgroundColor($r('app.color.cockpit_panel_strong'))
      .border({ width: 1, color: $r('app.color.cockpit_grid') })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border_bright') })
    .borderRadius(4)
  }

  @Builder
  private statusChip(label: string, value: string, tone: DashboardTone) {
    Row({ space: 6 }) {
      Row().width(7).height(7).borderRadius(4).backgroundColor(dashboardToneColor(tone))
      Text(label).fontSize(10).fontColor($r('app.color.cockpit_text_secondary'))
      Text(value).fontSize(12).fontWeight(FontWeight.Bold).fontColor(dashboardToneColor(tone))
    }
    .padding({ left: 8, right: 8, top: 5, bottom: 5 })
    .border({ width: 1, color: $r('app.color.cockpit_grid') })
    .backgroundColor($r('app.color.cockpit_panel_strong'))
    .accessibilityGroup(true)
  }
}

@ComponentV2
struct CockpitAlarmPanel {
  private events: DashboardEvent[] = LIVE_EVENTS;

  build() {
    Column({ space: 13 }) {
      CockpitPanelTitle('实时预警', 'LIVE ALERTS', $r('sys.symbol.exclamationmark_triangle_fill'))

      Row() {
        Column({ space: 3 }) {
          Text('8')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.status_danger'))
          Text('未闭环事件')
            .fontSize(11)
            .fontColor($r('app.color.cockpit_text_secondary'))
        }
        .layoutWeight(1)
        Column({ space: 3 }) {
          Text('4.8')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.cockpit_border_bright'))
          Text('平均响应/分钟')
            .fontSize(11)
            .fontColor($r('app.color.cockpit_text_secondary'))
        }
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 9 }) {
        ForEach(this.events, (event: DashboardEvent) => {
          Row({ space: 9 }) {
            Column({ space: 3 }) {
              Text(event.time)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(dashboardToneColor(event.tone))
              Text(event.level)
                .fontSize(9)
                .fontColor(dashboardToneColor(event.tone))
            }
            .width(40)
            .alignItems(HorizontalAlign.Start)

            Row()
              .width(3)
              .height(42)
              .backgroundColor(dashboardToneColor(event.tone))

            Column({ space: 3 }) {
              Text(event.title)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.cockpit_text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(event.location)
                .fontSize(10)
                .fontColor($r('app.color.cockpit_text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(event.detail)
                .fontSize(10)
                .fontColor($r('app.color.cockpit_text_secondary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(9)
          .backgroundColor($r('app.color.cockpit_panel_strong'))
          .border({ width: 1, color: $r('app.color.cockpit_grid') })
          .accessibilityGroup(true)
          .accessibilityText(`${event.time}，${event.level}，${event.title}，${event.location}，${event.detail}`)
        }, (event: DashboardEvent) => event.id)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
struct CockpitTrendPanel {
  private points: TrendPoint[] = CARE_TREND;

  build() {
    Column({ space: 14 }) {
      CockpitPanelTitle('七日照护质量趋势', 'SERVICE QUALITY', $r('sys.symbol.waveform_path_ecg_magnifyingglass'))

      Row({ space: 12 }) {
        Row({ space: 5 }) {
          Row().width(10).height(3).backgroundColor($r('app.color.cockpit_border_bright'))
          Text('任务完成率').fontSize(10).fontColor($r('app.color.cockpit_text_secondary'))
        }
        Row({ space: 5 }) {
          Row().width(10).height(3).backgroundColor($r('app.color.status_success'))
          Text('交接完整率').fontSize(10).fontColor($r('app.color.cockpit_text_secondary'))
        }
      }

      Row({ space: 8 }) {
        ForEach(this.points, (point: TrendPoint) => {
          Column({ space: 7 }) {
            Row({ space: 4 }) {
              Row()
                .width(8)
                .height(Math.max(18, point.value * 0.9))
                .backgroundColor($r('app.color.cockpit_border_bright'))
              Row()
                .width(8)
                .height(Math.max(18, point.secondaryValue * 0.9))
                .backgroundColor($r('app.color.status_success'))
            }
            .height(92)
            .alignItems(VerticalAlign.Bottom)
            Text(point.label)
              .fontSize(10)
              .fontColor(point.label === '今日' ? $r('app.color.cockpit_text_primary') :
                $r('app.color.cockpit_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .accessibilityGroup(true)
          .accessibilityText(`${point.label}任务完成率${point.value}%，交接完整率${point.secondaryValue}%`)
        }, (point: TrendPoint) => point.label)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}

@ComponentV2
struct CockpitDevicePanel {
  private facilities: FacilityStatus[] = FACILITY_STATUSES;

  private onlineRatio(item: FacilityStatus): number {
    return item.total > 0 ? item.online / item.total * 100 : 0;
  }

  build() {
    Column({ space: 14 }) {
      CockpitPanelTitle('设备脉冲', 'DEVICE PULSE', $r('sys.symbol.waveform_path_ecg_square'))

      GridRow({ columns: 4, gutter: { x: 8, y: 8 } }) {
        ForEach(this.facilities, (item: FacilityStatus) => {
          GridCol({ span: 2 }) {
            Row({ space: 9 }) {
              SymbolGlyph(item.symbol)
                .fontSize(20)
                .fontColor([this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
                  $r('app.color.cockpit_border_bright')])
              Column({ space: 3 }) {
                Text(item.label)
                  .fontSize(11)
                  .fontColor($r('app.color.cockpit_text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${this.onlineRatio(item).toFixed(1)}% 在线`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
                    $r('app.color.status_success'))
                Text(item.note)
                  .fontSize(9)
                  .fontColor($r('app.color.cockpit_text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.cockpit_panel_strong'))
            .border({ width: 1, color: $r('app.color.cockpit_grid') })
            .accessibilityGroup(true)
            .accessibilityText(`${item.label}在线率${this.onlineRatio(item).toFixed(1)}%，${item.note}`)
          }
        }, (item: FacilityStatus) => item.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.cockpit_panel'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .borderRadius(4)
  }
}
