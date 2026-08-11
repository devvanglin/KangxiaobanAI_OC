import { HdsListItemCard, SuffixText } from '@kit.UIDesignKit';
import {
  FACILITY_STATUSES,
  LIVE_EVENTS,
  WARD_STATUSES
} from '../../data/DashboardMockData';
import {
  DashboardEvent,
  DashboardTone,
  FacilityStatus,
  WardStatus
} from '../../model/DashboardModels';
import {
  dashboardToneColor,
  dashboardToneSoftColor
} from './DashboardStyle';

interface RoomOperation {
  id: string;
  building: string;
  floor: string;
  roomNumber: string;
  residentNames: string;
  occupiedBeds: number;
  totalBeds: number;
  careLevel: string;
  owner: string;
  vitalStatus: string;
  devicesOnline: number;
  devicesTotal: number;
  temperature: string;
  humidity: string;
  openTasks: number;
  alerts: number;
  lastRound: string;
  nextTask: string;
  status: string;
  tone: DashboardTone;
}

const ROOM_OPERATIONS: RoomOperation[] = [
  {
    id: 'east-a-218', building: '东区 A 栋', floor: '2 层', roomNumber: '218',
    residentNames: '王桂兰、陈松年', occupiedBeds: 2, totalBeds: 2, careLevel: '三级照护', owner: '李晓',
    vitalStatus: '1 人离床未归', devicesOnline: 7, devicesTotal: 8, temperature: '23.8℃', humidity: '52%',
    openTasks: 3, alerts: 1, lastRound: '10:12', nextTask: '10:40 生命体征复测', status: '紧急', tone: 'danger'
  },
  {
    id: 'east-a-220', building: '东区 A 栋', floor: '2 层', roomNumber: '220',
    residentNames: '周素琴、赵建国', occupiedBeds: 2, totalBeds: 2, careLevel: '二级照护', owner: '刘敏',
    vitalStatus: '生命体征平稳', devicesOnline: 8, devicesTotal: 8, temperature: '23.5℃', humidity: '49%',
    openTasks: 1, alerts: 0, lastRound: '10:20', nextTask: '11:00 饮水与翻身', status: '正常', tone: 'success'
  },
  {
    id: 'east-b-307', building: '东区 B 栋', floor: '3 层', roomNumber: '307',
    residentNames: '孙玉兰、何秀珍', occupiedBeds: 2, totalBeds: 2, careLevel: '认知症照护', owner: '张洁',
    vitalStatus: '夜间睡眠偏少', devicesOnline: 9, devicesTotal: 9, temperature: '24.1℃', humidity: '55%',
    openTasks: 2, alerts: 1, lastRound: '10:08', nextTask: '10:35 情绪安抚巡视', status: '关注', tone: 'warning'
  },
  {
    id: 'east-b-309', building: '东区 B 栋', floor: '3 层', roomNumber: '309',
    residentNames: '林春华', occupiedBeds: 1, totalBeds: 2, careLevel: '认知症照护', owner: '张洁',
    vitalStatus: '生命体征平稳', devicesOnline: 7, devicesTotal: 7, temperature: '23.7℃', humidity: '50%',
    openTasks: 0, alerts: 0, lastRound: '10:16', nextTask: '11:20 午餐准备', status: '正常', tone: 'success'
  },
  {
    id: 'medical-506', building: '医养中心', floor: '5 层', roomNumber: '506',
    residentNames: '郑德荣、吴桂香', occupiedBeds: 2, totalBeds: 2, careLevel: '医护协同', owner: '陈医生 / 郑梅',
    vitalStatus: '血压待复测', devicesOnline: 11, devicesTotal: 12, temperature: '23.6℃', humidity: '51%',
    openTasks: 4, alerts: 1, lastRound: '10:05', nextTask: '10:30 血压复测', status: '关注', tone: 'warning'
  },
  {
    id: 'medical-508', building: '医养中心', floor: '5 层', roomNumber: '508',
    residentNames: '钱月英', occupiedBeds: 1, totalBeds: 1, careLevel: '术后康复', owner: '王医生 / 陈静',
    vitalStatus: '康复指标平稳', devicesOnline: 10, devicesTotal: 10, temperature: '23.4℃', humidity: '48%',
    openTasks: 2, alerts: 0, lastRound: '10:22', nextTask: '11:00 步态训练', status: '正常', tone: 'success'
  },
  {
    id: 'west-a-201', building: '西区 A 栋', floor: '2 层', roomNumber: '201',
    residentNames: '沈伯安、罗桂芳', occupiedBeds: 2, totalBeds: 2, careLevel: '一级照护', owner: '何丽',
    vitalStatus: '生命体征平稳', devicesOnline: 6, devicesTotal: 6, temperature: '23.2℃', humidity: '47%',
    openTasks: 1, alerts: 0, lastRound: '10:14', nextTask: '11:10 午前巡视', status: '正常', tone: 'success'
  },
  {
    id: 'west-b-305', building: '西区 B 栋', floor: '3 层', roomNumber: '305',
    residentNames: '顾爱华、唐福生', occupiedBeds: 2, totalBeds: 2, careLevel: '二级照护', owner: '许娟',
    vitalStatus: '呼吸频率正常', devicesOnline: 7, devicesTotal: 8, temperature: '24.6℃', humidity: '68%',
    openTasks: 3, alerts: 1, lastRound: '10:03', nextTask: '10:45 环境工单复核', status: '关注', tone: 'warning'
  }
];

@Builder
function PanelTitle(title: string, subtitle: string) {
  Column({ space: 4 }) {
    Text(title)
      .fontSize($r('sys.float.Title_M'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
    Text(subtitle)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
  .width('100%')
  .alignItems(HorizontalAlign.Start)
}

@Builder
function PanelHeading(title: string) {
  Text(title)
    .width('100%')
    .fontSize($r('sys.float.Title_M'))
    .fontWeight(FontWeight.Bold)
    .fontColor($r('sys.color.font_primary'))
}

@ComponentV2
export struct CockpitOverview {
  @Param compact: boolean = false;

  build() {
    if (this.compact) {
      Column({ space: 12 }) {
        RoomOperationsPanel({ compact: true })
        InstitutionSummaryPanel()
        LiveAlertSidePanel()
        BedLoadPanel()
        WorkforcePanel()
        FacilitySidePanel()
      }
      .width('100%')
    } else {
      GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
        GridCol({ span: 3 }) {
          Column({ space: 12 }) {
            InstitutionSummaryPanel()
            BedLoadPanel()
            WorkforcePanel()
          }
        }

        GridCol({ span: 6 }) {
          RoomOperationsPanel({ compact: false })
        }

        GridCol({ span: 3 }) {
          Column({ space: 12 }) {
            LiveAlertSidePanel()
            FacilitySidePanel()
          }
        }
      }
      .width('100%')
      .alignItems(ItemAlign.Start)
    }
  }
}

@ComponentV2
struct InstitutionSummaryPanel {
  build() {
    Column({ space: 16 }) {
      PanelHeading('养老院概览')

      GridRow({ columns: 4, gutter: { x: 8, y: 8 } }) {
        GridCol({ span: 2 }) { this.metricCell('在院长者', '356', '人', 'brand') }
        GridCol({ span: 2 }) { this.metricCell('床位使用', '92.4', '%', 'warning') }
        GridCol({ span: 2 }) { this.metricCell('当前在岗', '87', '人', 'success') }
        GridCol({ span: 2 }) { this.metricCell('未闭环', '8', '项', 'danger') }
      }
      .width('100%')

      Row() {
        Text('数据更新时间')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text('16:58')
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }

  @Builder
  private metricCell(label: string, value: string, unit: string, tone: DashboardTone) {
    Column({ space: 5 }) {
      Row({ space: 3 }) {
        Text(value)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(unit)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      Text(label)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(dashboardToneSoftColor(tone))
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}${unit}`)
  }
}

@ComponentV2
struct BedLoadPanel {
  private wards: WardStatus[] = WARD_STATUSES;

  build() {
    Column({ space: 14 }) {
      PanelTitle('床位运行', '楼层负荷与可用床位')

      Column({ space: 13 }) {
        ForEach(this.wards, (ward: WardStatus) => {
          Column({ space: 6 }) {
            Row() {
              Column({ space: 2 }) {
                Text(ward.name)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                Text(`${ward.floor} · ${ward.residents}/${ward.capacity}`)
                  .fontSize($r('sys.float.Body_S'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Text(`${ward.occupancy}%`)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
            }
            .width('100%')

            Progress({ value: ward.occupancy, total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(6)
              .color(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
              .backgroundColor($r('app.color.chart_track'))
          }
          .accessibilityGroup(true)
          .accessibilityText(`${ward.name}，床位使用率${ward.occupancy}%`)
        }, (ward: WardStatus) => ward.id)
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }
}

@ComponentV2
struct WorkforcePanel {
  build() {
    Column({ space: 14 }) {
      PanelHeading('班组态势')

      GridRow({ columns: 4, gutter: { x: 8, y: 8 } }) {
        GridCol({ span: 2 }) { this.staffCell('护理在岗', '52', '96.3%', 'success') }
        GridCol({ span: 2 }) { this.staffCell('医护协同', '17', '100%', 'brand') }
        GridCol({ span: 2 }) { this.staffCell('生活照护', '18', '94.7%', 'warning') }
        GridCol({ span: 2 }) { this.staffCell('夜班缺口', '2', '待协调', 'danger') }
      }
      .width('100%')

      Text('下一交接节点 17:30 · 4 条记录待补充')
        .width('100%')
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .padding(12)
        .borderRadius(14)
        .backgroundColor($r('sys.color.comp_background_secondary'))
    }
    .width('100%')
    .padding(18)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }

  @Builder
  private staffCell(label: string, value: string, note: string, tone: DashboardTone) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(label)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
      Text(note)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor(dashboardToneSoftColor(tone))
    .alignItems(HorizontalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}，${note}`)
  }
}

@ComponentV2
struct RoomOperationsPanel {
  @Param compact: boolean = false;
  private rooms: RoomOperation[] = ROOM_OPERATIONS;

  build() {
    Column({ space: 14 }) {
      this.panelIdentity()

      GridRow({ columns: this.compact ? 1 : 2, gutter: { x: 10, y: 10 } }) {
        ForEach(this.rooms, (room: RoomOperation) => {
          GridCol({ span: 1 }) {
            this.roomCard(room)
          }
        }, (room: RoomOperation) => room.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }

  @Builder
  private panelIdentity() {
    Text('全院房间运行总览')
      .width('100%')
      .fontSize($r('sys.float.Title_L'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
  }

  @Builder
  private roomCard(room: RoomOperation) {
    Column({ space: 11 }) {
        Row() {
          Column({ space: 2 }) {
            Text(`${room.roomNumber} 房`)
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text(`${room.building} · ${room.floor}`)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(room.status)
            .fontSize($r('sys.float.Caption_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor(dashboardToneColor(room.tone))
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor(dashboardToneSoftColor(room.tone))
        }
        .width('100%')

        Row() {
          Column({ space: 3 }) {
            Text(room.residentNames)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${room.careLevel} · 责任护理 ${room.owner}`)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text(`${room.occupiedBeds}/${room.totalBeds} 床`)
            .fontSize($r('sys.float.Body_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_primary'))
        }
        .width('100%')

        GridRow({ columns: 4, gutter: { x: 6, y: 6 } }) {
          GridCol({ span: 2 }) { this.roomInfoCell('生命体征', room.vitalStatus, room.tone) }
          GridCol({ span: 2 }) {
            this.roomInfoCell('设备在线', `${room.devicesOnline}/${room.devicesTotal} 台`,
              room.devicesOnline === room.devicesTotal ? 'success' : 'warning')
          }
          GridCol({ span: 2 }) { this.roomInfoCell('室内环境', `${room.temperature} · ${room.humidity}`, 'brand') }
          GridCol({ span: 2 }) {
            this.roomInfoCell('任务 / 预警', `${room.openTasks} 项 / ${room.alerts} 项`,
              room.alerts > 0 ? room.tone : 'success')
          }
        }
        .width('100%')

        Row() {
          Text(`最近巡视 ${room.lastRound}`)
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          Text(room.nextTask)
            .fontSize($r('sys.float.Caption_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor(room.openTasks > 0 ? $r('app.color.brand_primary') : $r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityGroup(true)
    .accessibilityText(`${room.building}${room.floor}${room.roomNumber}房，${room.residentNames}，${room.careLevel}，${room.status}，待办${room.openTasks}项，预警${room.alerts}项`)
  }

  @Builder
  private roomInfoCell(label: string, value: string, tone: DashboardTone) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor(dashboardToneColor(tone))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 9, right: 9, top: 8, bottom: 8 })
    .borderRadius(12)
    .backgroundColor(dashboardToneSoftColor(tone))
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
struct LiveAlertSidePanel {
  private events: DashboardEvent[] = LIVE_EVENTS;

  build() {
    Column({ space: 14 }) {
      PanelHeading('实时态势')

      List() {
        ForEach(this.events, (event: DashboardEvent) => {
          ListItem() {
            HdsListItemCard({
              textItem: {
                primaryText: { text: `${event.title} · ${event.level}` },
                secondaryText: { text: `${event.location} · ${event.detail}` }
              },
              suffixItem: new SuffixText({ text: event.time }),
              cardHeight: 66,
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
      .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider'), startMargin: 12, endMargin: 8 })
      .height(this.events.length * 66)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .padding(18)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }
}

@ComponentV2
struct FacilitySidePanel {
  private facilities: FacilityStatus[] = FACILITY_STATUSES;

  private onlineRatio(item: FacilityStatus): number {
    return Math.round(item.online / item.total * 1000) / 10;
  }

  build() {
    Column({ space: 14 }) {
      PanelHeading('设备与空间')

      Column({ space: 12 }) {
        ForEach(this.facilities, (item: FacilityStatus) => {
          Column({ space: 6 }) {
            Row() {
              Text(item.label)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Blank()
              Text(`${this.onlineRatio(item)}%`)
                .fontSize($r('sys.float.Body_S'))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
                  $r('app.color.status_success'))
            }
            .width('100%')

            Progress({ value: this.onlineRatio(item), total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(6)
              .color(this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
                $r('app.color.status_success'))
              .backgroundColor($r('app.color.chart_track'))

            Text(item.note)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .accessibilityGroup(true)
          .accessibilityText(`${item.label}在线率${this.onlineRatio(item)}%，${item.note}`)
        }, (item: FacilityStatus) => item.id)
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }
}
