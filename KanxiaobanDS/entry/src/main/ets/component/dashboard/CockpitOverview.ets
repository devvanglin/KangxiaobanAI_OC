import { FACILITY_STATUSES, LIVE_EVENTS, WARD_STATUSES } from '../../data/DashboardMockData';
import { DashboardEvent, DashboardTone, FacilityStatus, WardStatus } from '../../model/DashboardModels';
import { dashboardToneColor, dashboardToneSoftColor } from './DashboardStyle';

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
    residentNames: '顾爱华、唐福生', occupiedBeds: 2, totalBeds: 2, careLevel: '二级照护', owner: '许婷',
    vitalStatus: '呼吸频率正常', devicesOnline: 7, devicesTotal: 8, temperature: '24.6℃', humidity: '68%',
    openTasks: 3, alerts: 1, lastRound: '10:03', nextTask: '10:45 环境工单复核', status: '关注', tone: 'warning'
  }
];

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
  @Param layoutWidth: number = 0;
  @Param layoutHeight: number = 0;

  build() {
    if (this.compact) {
      MobileCockpit()
    } else {
      WideCockpit()
    }
  }
}

@ComponentV2
struct WideCockpit {
  build() {
    Column({ space: 12 }) {
      TodayPulsePanel()
        .height(116)

      Row({ space: 12 }) {
        Column({ space: 12 }) {
          RoomOperationsPanel({ compact: false })
            .layoutWeight(74)
            .width('100%')
          FloorTeamPanel()
            .layoutWeight(26)
            .width('100%')
        }
          .layoutWeight(67)
          .height('100%')

        Column({ space: 12 }) {
          LiveAlertPanel({ compact: false })
            .layoutWeight(62)
          ReadinessPanel()
            .layoutWeight(38)
        }
        .layoutWeight(33)
        .height('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
struct FloorTeamPanel {
  private wards: WardStatus[] = WARD_STATUSES;

  build() {
    Row({ space: 18 }) {
      Column({ space: 6 }) {
        Row() {
          Text('院区负荷')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Blank()
          Text('140 张床')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        Row({ space: 12 }) {
          this.wardLoad(this.wards[0])
          this.wardLoad(this.wards[1])
          this.wardLoad(this.wards[2])
          this.wardLoad(this.wards[3])
        }
        .layoutWeight(1)
        .width('100%')
      }
      .layoutWeight(62)
      .height('100%')

      Row()
        .width(1)
        .height('82%')
        .backgroundColor($r('sys.color.comp_divider'))

      Column({ space: 6 }) {
        Row() {
          Text('班组保障')
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Blank()
          Text('17:30 交接')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        Row({ space: 8 }) {
          this.staffMetric('护理在岗', '52', 'success')
          this.staffMetric('医护协同', '17', 'brand')
          this.staffMetric('生活照护', '18', 'warning')
          this.staffMetric('夜班缺口', '2', 'danger')
        }
        .layoutWeight(1)
        .width('100%')
      }
      .layoutWeight(38)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private wardLoad(ward: WardStatus) {
    Column({ space: 4 }) {
      Row() {
        Text(ward.name)
          .layoutWeight(1)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${ward.occupancy}%`)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
      }
      .width('100%')
      Progress({ value: ward.occupancy, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(4)
        .color(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
        .backgroundColor($r('app.color.chart_track'))
      Text(`${ward.residents}/${ward.capacity} 床`)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
    .accessibilityText(`${ward.name}床位使用率${ward.occupancy}%`)
  }

  @Builder
  private staffMetric(label: string, value: string, tone: DashboardTone) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(10)
    .backgroundColor(dashboardToneSoftColor(tone))
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}`)
  }
}

@ComponentV2
struct TodayPulsePanel {
  build() {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text('今日运营脉搏')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('值班中')
            .fontSize($r('sys.float.Caption_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.status_success'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(10)
            .backgroundColor($r('app.color.status_success_soft'))
        }
        Text('先处理安全风险，再看房间节奏与资源保障')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.clock_fill'))
            .fontSize(13)
            .fontColor([$r('sys.color.font_secondary')])
          Text('本地演示数据 · 16:58 更新')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .layoutWeight(30)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 4 })

      this.metric('在院长者', '356', '床位使用 92.4%', 'brand')
      this.metric('当前在岗', '87', '夜班仍缺 2 人', 'warning')
      this.metric('待闭环事项', '8', '其中 1 项紧急', 'danger')
      this.metric('设备在线', '97.8%', '8 台待排查', 'success')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 14, top: 12, bottom: 12 })
    .borderRadius(22)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private metric(label: string, value: string, note: string, tone: DashboardTone) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(note)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(17)
    .height('100%')
    .padding({ left: 14, right: 12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .border({ width: { left: 0.5 }, color: { left: $r('sys.color.comp_divider') } })
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}，${note}`)
  }
}

@ComponentV2
struct MobileCockpit {
  build() {
    Column({ space: 8 }) {
      MobileSummaryPanel()
        .layoutWeight(7)

      RoomOperationsPanel({ compact: true })
        .layoutWeight(45)

      Row({ space: 8 }) {
        LiveAlertPanel({ compact: true })
          .layoutWeight(1)
          .height('100%')
        FacilityPanel({ compact: true })
          .layoutWeight(1)
          .height('100%')
      }
      .layoutWeight(14)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
struct InstitutionSummaryPanel {
  build() {
    Column({ space: 8 }) {
      PanelHeading('养老院概览')
      Row() {
        this.metricCell('在院长者', '356', '人', 'brand')
        Row()
          .width(1)
          .height('62%')
          .backgroundColor($r('sys.color.comp_divider'))
        this.metricCell('床位使用', '92.4', '%', 'warning')
      }
      .layoutWeight(1)
      Row()
        .width('100%')
        .height(1)
        .backgroundColor($r('sys.color.comp_divider'))
      Row() {
        this.metricCell('当前在岗', '87', '人', 'success')
        Row()
          .width(1)
          .height('62%')
          .backgroundColor($r('sys.color.comp_divider'))
        this.metricCell('未闭环', '8', '项', 'danger')
      }
      .layoutWeight(1)
      Row() {
        Text('本地演示数据')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text('更新 16:58')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private metricCell(label: string, value: string, unit: string, tone: DashboardTone) {
    Column({ space: 2 }) {
      Row({ space: 2 }) {
        Text(value)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(unit)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 10, right: 10 })
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}${unit}`)
  }
}

@ComponentV2
struct MobileSummaryPanel {
  build() {
    Row() {
      this.metric('长者', '356', 'brand')
      Row().width(1).height('52%').backgroundColor($r('sys.color.comp_divider'))
      this.metric('床位', '92.4%', 'warning')
      Row().width(1).height('52%').backgroundColor($r('sys.color.comp_divider'))
      this.metric('在岗', '87', 'success')
      Row().width(1).height('52%').backgroundColor($r('sys.color.comp_divider'))
      this.metric('告警', '8', 'danger')
    }
    .width('100%')
    .height('100%')
    .padding(8)
    .borderRadius(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private metric(label: string, value: string, tone: DashboardTone) {
    Column({ space: 1 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}`)
  }
}

@ComponentV2
struct BedLoadPanel {
  private wards: WardStatus[] = WARD_STATUSES;

  build() {
    Column({ space: 8 }) {
      PanelHeading('床位运行')
      ForEach(this.wards, (ward: WardStatus) => {
        Column({ space: 3 }) {
          Row() {
            Column({ space: 1 }) {
              Text(ward.name)
                .fontSize($r('sys.float.Body_S'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text(`${ward.floor} · ${ward.residents}/${ward.capacity}`)
                .fontSize($r('sys.float.Caption_S'))
                .fontColor($r('sys.color.font_secondary'))
                .maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text(`${ward.occupancy}%`)
              .fontSize($r('sys.float.Body_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
          }
          .width('100%')
          Progress({ value: ward.occupancy, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(4)
            .color(ward.occupancy >= 96 ? $r('app.color.status_warning') : $r('app.color.brand_primary'))
            .backgroundColor($r('app.color.chart_track'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .accessibilityGroup(true)
        .accessibilityText(`${ward.name}床位使用率${ward.occupancy}%`)
      }, (ward: WardStatus) => ward.id)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }
}

@ComponentV2
struct WorkforcePanel {
  build() {
    Column({ space: 8 }) {
      PanelHeading('班组态势')
      Row() {
        this.staffCell('护理在岗', '52', 'success')
        Row().width(1).height('62%').backgroundColor($r('sys.color.comp_divider'))
        this.staffCell('医护协同', '17', 'brand')
      }
      .layoutWeight(1)
      Row()
        .width('100%')
        .height(1)
        .backgroundColor($r('sys.color.comp_divider'))
      Row() {
        this.staffCell('生活照护', '18', 'warning')
        Row().width(1).height('62%').backgroundColor($r('sys.color.comp_divider'))
        this.staffCell('夜班缺口', '2', 'danger')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private staffCell(label: string, value: string, tone: DashboardTone) {
    Column({ space: 1 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_primary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${label}${value}`)
  }
}

@ComponentV2
struct RoomOperationsPanel {
  @Param compact: boolean = false;
  @Local currentPage: number = 0;
  private rooms: RoomOperation[] = ROOM_OPERATIONS;
  private pageSize: number = 4;

  private pageCount(): number {
    return Math.ceil(this.rooms.length / this.pageSize);
  }

  private visibleRoomIndexes(): number[] {
    const firstIndex: number = this.currentPage * this.pageSize;
    return [firstIndex, firstIndex + 1, firstIndex + 2, firstIndex + 3];
  }

  private showPreviousPage(): void {
    if (this.currentPage > 0) {
      this.currentPage -= 1;
    }
  }

  private showNextPage(): void {
    if (this.currentPage < this.pageCount() - 1) {
      this.currentPage += 1;
    }
  }

  build() {
    Column({ space: this.compact ? 7 : 10 }) {
      this.panelHeader()

      if (this.compact) {
        ForEach(this.visibleRoomIndexes(), (index: number) => {
          this.compactRoomCard(this.rooms[index])
        }, (index: number) => `${index}`)
      } else {
        Grid() {
          ForEach(this.visibleRoomIndexes(), (index: number) => {
            GridItem() {
              this.wideRoomCard(this.rooms[index])
            }
          }, (index: number) => `${index}`)
        }
        .layoutWeight(1)
        .width('100%')
        .columnsTemplate('1fr 1fr')
        .rowsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.compact ? 6 : 0)
    .borderRadius(this.compact ? $r('sys.float.corner_radius_level8') : 0)
    .backgroundColor(this.compact ? $r('sys.color.comp_background_primary') : Color.Transparent)
    .border({ width: this.compact ? 0.5 : 0, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private wideRoomCard(room: RoomOperation) {
    Column({ space: 7 }) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Row({ space: 5 }) {
            Text(room.roomNumber)
              .fontSize(25)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('房')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          Text(`${room.building} · ${room.floor}`)
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text(room.residentNames)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${room.careLevel} · ${room.owner}`)
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(room.status)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor(dashboardToneColor(room.tone))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
          .backgroundColor(dashboardToneSoftColor(room.tone))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        this.roomMetric('床位', `${room.occupiedBeds}/${room.totalBeds}`, 'brand')
        this.roomMetric('设备', `${room.devicesOnline}/${room.devicesTotal}`, room.devicesOnline < room.devicesTotal ?
          'warning' : 'success')
        this.roomMetric('温湿度', `${room.temperature} · ${room.humidity}`, 'brand')
      }
      .width('100%')

      Row({ space: 7 }) {
        SymbolGlyph(room.tone === 'danger' ? $r('sys.symbol.exclamationmark_triangle_fill') :
          $r('sys.symbol.checkmark_circle_fill'))
          .fontSize(15)
          .fontColor([dashboardToneColor(room.tone)])
        Text(room.vitalStatus)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(dashboardToneColor(room.tone))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`巡房 ${room.lastRound}`)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .borderRadius(12)
      .backgroundColor(dashboardToneSoftColor(room.tone))

      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.clock_fill'))
          .fontSize(15)
          .fontColor([$r('app.color.brand_primary')])
        Text(room.nextTask)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${room.openTasks} 项待办 · ${room.alerts} 项告警`)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor(room.alerts > 0 ? dashboardToneColor(room.tone) : $r('sys.color.font_secondary'))
          .maxLines(1)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .borderRadius(18)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: room.tone === 'danger' ? $r('app.color.status_danger') :
      $r('app.color.cockpit_border') })
    .accessibilityGroup(true)
    .accessibilityText(`${room.building}${room.floor}${room.roomNumber}房，${room.residentNames}，${room.careLevel}，${room.status}，待办${room.openTasks}项，预警${room.alerts}项`)
  }

  @Builder
  private roomMetric(label: string, value: string, tone: DashboardTone) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 9, right: 9, top: 7, bottom: 7 })
    .borderRadius(11)
    .backgroundColor($r('app.color.room_metric_surface'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private compactRoomCard(room: RoomOperation) {
    Column({ space: 4 }) {
      Row() {
        Text(`${room.roomNumber} 房`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(` · ${room.residentNames}`)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${room.occupiedBeds}/${room.totalBeds}床`)
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
        Blank()
        Text(room.status)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor(dashboardToneColor(room.tone))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(9)
          .backgroundColor(dashboardToneSoftColor(room.tone))
      }
      .width('100%')

      Row() {
        Text(room.vitalStatus)
          .layoutWeight(1)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(dashboardToneColor(room.tone))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${room.devicesOnline}/${room.devicesTotal}台 · ${room.temperature} · ${room.humidity}`)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('app.color.brand_primary'))
      }
      .width('100%')

      Row() {
        Text(`${room.careLevel} · ${room.building}`)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text(`${room.openTasks}任务/${room.alerts}警 · `)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor(room.alerts > 0 ? dashboardToneColor(room.tone) : $r('sys.color.font_secondary'))
        Text(room.nextTask)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .borderRadius(12)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('app.color.cockpit_border') })
    .accessibilityGroup(true)
    .accessibilityText(`${room.building}${room.floor}${room.roomNumber}房，${room.residentNames}，${room.careLevel}，${room.status}，待办${room.openTasks}项，预警${room.alerts}项`)
  }

  @Builder
  private panelHeader() {
    Row({ space: 8 }) {
      Column({ space: 1 }) {
        Text(this.compact ? '房间总览' : '房间运行')
          .fontSize(this.compact ? $r('sys.float.Body_M') : $r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        if (!this.compact) {
          Text('优先看异常房间，再按任务时间推进处置')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text(`第 ${this.currentPage + 1} / ${this.pageCount()} 页`)
        .fontSize($r('sys.float.Caption_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text('上一页')
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.currentPage > 0 ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .height(this.compact ? 28 : 30)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .enabled(this.currentPage > 0)
      .opacity(this.currentPage > 0 ? 1 : 0.5)
      .accessibilityText('上一页房间')
      .onClick(() => {
        this.showPreviousPage();
      })

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text('下一页')
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.currentPage < this.pageCount() - 1 ? Color.White : $r('sys.color.font_tertiary'))
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .height(this.compact ? 28 : 30)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.currentPage < this.pageCount() - 1 ? $r('app.color.brand_primary') :
        $r('sys.color.comp_background_secondary'))
      .enabled(this.currentPage < this.pageCount() - 1)
      .opacity(this.currentPage < this.pageCount() - 1 ? 1 : 0.5)
      .accessibilityText('下一页房间')
      .onClick(() => {
        this.showNextPage();
      })
    }
    .width('100%')
    .height(this.compact ? 30 : 44)
  }

}

@ComponentV2
struct LiveAlertPanel {
  @Param compact: boolean = false;
  private events: DashboardEvent[] = LIVE_EVENTS;

  build() {
    Column({ space: this.compact ? 3 : 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text(this.compact ? '实时' : '待处置事件')
            .fontSize(this.compact ? $r('sys.float.Body_M') : $r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          if (!this.compact) {
            Text('按紧急程度与发生时间排序')
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        if (!this.compact) {
          Text('8 项')
            .fontSize($r('sys.float.Caption_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.status_danger'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(10)
            .backgroundColor($r('app.color.status_danger_soft'))
        }
      }
      .width('100%')
      if (this.compact) {
        ForEach(this.events.slice(0, 3), (event: DashboardEvent) => {
          this.compactEventRow(event)
        }, (event: DashboardEvent) => event.id)
      } else {
        ForEach(this.events.slice(0, 5), (event: DashboardEvent) => {
          this.wideEventRow(event)
        }, (event: DashboardEvent) => event.id)
        Row() {
          Text('查看全部事件')
            .fontSize($r('sys.float.Body_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
          Blank()
          Text('其中 3 项需要现场确认')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .height(32)
        .padding({ left: 8, right: 8 })
        .borderRadius(10)
        .backgroundColor($r('app.color.room_task_surface'))
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.compact ? 8 : 14)
    .borderRadius(this.compact ? 16 : 20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private wideEventRow(event: DashboardEvent) {
    Row({ space: 9 }) {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(event.level)
            .fontSize($r('sys.float.Caption_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor(dashboardToneColor(event.tone))
          Text(event.title)
            .layoutWeight(1)
            .fontSize($r('sys.float.Body_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(event.time)
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        Text(`${event.location} · ${event.detail}`)
          .width('100%')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 9, right: 7, top: 6, bottom: 6 })
    .borderRadius(11)
    .backgroundColor(event.tone === 'danger' ? $r('app.color.status_danger_soft') : Color.Transparent)
    .border({ width: { left: 3 }, color: { left: dashboardToneColor(event.tone) } })
    .focusable(true)
    .accessibilityGroup(true)
    .accessibilityText(`${event.time}，${event.level}，${event.title}，${event.location}，${event.detail}`)
  }

  @Builder
  private compactEventRow(event: DashboardEvent) {
    Column({ space: 1 }) {
      Row({ space: 4 }) {
        Text(event.title)
          .layoutWeight(1)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(event.time)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      Text(`${event.location} · ${event.level}`)
        .width('100%')
        .fontSize($r('sys.float.Caption_S'))
        .fontColor(dashboardToneColor(event.tone))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 4, right: 4 })
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
    .accessibilityGroup(true)
    .accessibilityText(`${event.time}，${event.level}，${event.title}，${event.location}，${event.detail}`)
  }
}

@ComponentV2
struct ReadinessPanel {
  private wards: WardStatus[] = WARD_STATUSES;
  private facilities: FacilityStatus[] = FACILITY_STATUSES;

  private onlineRatio(item: FacilityStatus): number {
    return Math.round(item.online / item.total * 1000) / 10;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('资源保障')
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('床位负荷与设备健康')
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('2 项关注')
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.status_warning'))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.readinessMetric('最高床位负荷', '97.9%', this.wards[0].name, 'warning')
        this.readinessMetric('设备在线率', '97.8%', '8 台待排查', 'success')
      }
      .width('100%')

      Column({ space: 6 }) {
        this.progressItem(this.facilities[0].label, this.onlineRatio(this.facilities[0]))
        this.progressItem(this.facilities[1].label, this.onlineRatio(this.facilities[1]))
        this.progressItem(this.facilities[3].label, this.onlineRatio(this.facilities[3]))
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .borderRadius(20)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private readinessMetric(label: string, value: string, note: string, tone: DashboardTone) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
      Text(note)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .borderRadius(12)
    .backgroundColor($r('app.color.room_metric_surface'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private progressItem(label: string, ratio: number) {
    Column({ space: 3 }) {
      Row() {
        Text(label)
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${ratio}%`)
          .fontSize($r('sys.float.Caption_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor(ratio < 97 ? $r('app.color.status_warning') : $r('app.color.status_success'))
      }
      .width('100%')
      Progress({ value: ratio, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(4)
        .color(ratio < 97 ? $r('app.color.status_warning') : $r('app.color.status_success'))
        .backgroundColor($r('app.color.chart_track'))
    }
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityText(`${label}在线率${ratio}%`)
  }
}

@ComponentV2
struct FacilityPanel {
  @Param compact: boolean = false;
  private facilities: FacilityStatus[] = FACILITY_STATUSES;

  private onlineRatio(item: FacilityStatus): number {
    return Math.round(item.online / item.total * 1000) / 10;
  }

  build() {
    Column({ space: this.compact ? 4 : 8 }) {
      Text(this.compact ? '设备' : '设备与空间')
        .width('100%')
        .fontSize(this.compact ? $r('sys.float.Body_M') : $r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      ForEach(this.facilities, (item: FacilityStatus) => {
        Column({ space: 2 }) {
          Row() {
            Text(item.label)
              .fontSize($r('sys.float.Caption_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Blank()
            Text(`${this.onlineRatio(item)}%`)
              .fontSize($r('sys.float.Caption_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
                $r('app.color.status_success'))
          }
          .width('100%')
          Progress({ value: this.onlineRatio(item), total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(this.compact ? 3 : 4)
            .color(this.onlineRatio(item) < 97 ? $r('app.color.status_warning') :
              $r('app.color.status_success'))
            .backgroundColor($r('app.color.chart_track'))
          if (!this.compact) {
            Text(item.note)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .accessibilityGroup(true)
        .accessibilityText(`${item.label}在线率${this.onlineRatio(item)}%，${item.note}`)
      }, (item: FacilityStatus) => item.id)
    }
    .width('100%')
    .height('100%')
    .padding(this.compact ? 8 : 12)
    .borderRadius(this.compact ? 16 : $r('sys.float.corner_radius_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }
}
