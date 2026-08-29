import DashboardStore from '../../network/DashboardStore';
import {
  CareWorkItem,
  DashboardEvent,
  DashboardTone,
  FacilityStatus,
  RiskSummary,
  RoomOperation,
  WardStatus
} from '../../model/DashboardModels';
import { dashboardProgressWidth, dashboardToneColor, dashboardToneSoftColor } from './DashboardStyle';

@ComponentV2
export struct CockpitOverview {
  @Param compact: boolean = false;
  @Param layoutWidth: number = 0;
  @Param layoutHeight: number = 0;
  @Param @Require store: DashboardStore;

  private occupancy(): number {
    const total: number = this.store.snapshot.summary.total_beds;
    return total > 0 ? this.store.snapshot.summary.occupied_beds * 100 / total : 0;
  }

  private deviceRatio(): number {
    const total: number = this.store.snapshot.summary.devices_total;
    return total > 0 ? this.store.snapshot.summary.devices_online * 100 / total : 0;
  }

  private updatedLabel(): string {
    const value: string = this.store.snapshot.updated_at;
    if (value.length < 16) {
      return '尚未同步';
    }
    return `${value.substring(5, 10).replace('-', '/')} ${value.substring(11, 16)}`;
  }

  private careLevel(level: number): string {
    if (level <= 0) {
      return '未评级';
    }
    return `${level} 级照护`;
  }

  private residentNames(room: RoomOperation): string {
    return room.resident_names.length > 0 ? room.resident_names.join('、') : '暂无入住长者';
  }

  private eventIcon(event: DashboardEvent): Resource {
    return event.tone === 'success' ? $r('sys.symbol.checkmark_circle_fill') :
      $r('sys.symbol.exclamationmark_triangle_fill');
  }

  private facilityRatio(item: FacilityStatus): number {
    return item.total > 0 ? item.online * 100 / item.total : 0;
  }

  private isOccupancyWarning(value: number): boolean {
    const threshold: number = this.store.snapshot.policy.occupancy_warning_percent;
    return threshold > 0 && value >= threshold;
  }

  private isDeviceWarning(value: number): boolean {
    const threshold: number = this.store.snapshot.policy.device_online_warning_percent;
    return threshold > 0 && value < threshold;
  }

  private workCompletion(item: CareWorkItem): number {
    return item.total > 0 ? item.completed * 100 / item.total : 0;
  }

  @Builder
  private header() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text('全院运营驾驶舱')
          .fontSize(this.compact ? 22 : 26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Row({ space: 6 }) {
          Row().width(7).height(7).borderRadius(4).backgroundColor($r('app.color.status_success'))
          Text(`数据库同步 ${this.updatedLabel()}`)
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (!this.compact) {
        Text(this.store.displayName())
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
      }

      Button({ type: ButtonType.Circle }) {
        if (this.store.loading) {
          LoadingProgress().width(20).height(20).color($r('app.color.brand_primary'))
        } else {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(19)
            .fontColor([$r('app.color.brand_primary')])
        }
      }
      .width(40)
      .height(40)
      .backgroundColor($r('app.color.brand_soft'))
      .enabled(!this.store.loading)
      .accessibilityText('刷新驾驶舱')
      .onClick(() => this.store.load())

      Button({ type: ButtonType.Normal }) {
        Text('退出')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .height(40)
      .padding({ left: 14, right: 14 })
      .borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('app.color.cockpit_border') })
      .onClick(() => this.store.logout())
    }
    .width('100%')
    .height(54)
  }

  @Builder
  private metric(label: string, value: string, note: string, tone: DashboardTone) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize(this.compact ? 22 : 27)
        .fontWeight(FontWeight.Bold)
        .fontColor(dashboardToneColor(tone))
        .maxLines(1)
      Text(note)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(this.compact ? 92 : 102)
    .padding({ left: 14, right: 12, top: 12, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private summaryStrip() {
    if (this.compact) {
      GridRow({ columns: 2, gutter: { x: 8, y: 8 } }) {
        GridCol({ span: 1 }) {
          this.metric('在院长者', `${this.store.snapshot.summary.residents}`, `空床 ${this.store.snapshot.summary.free_beds}`, 'brand')
        }
        GridCol({ span: 1 }) {
          this.metric('床位使用', `${this.occupancy().toFixed(1)}%`, `${this.store.snapshot.summary.occupied_beds}/${this.store.snapshot.summary.total_beds}`, 'warning')
        }
        GridCol({ span: 1 }) {
          this.metric('今日在岗', `${this.store.snapshot.summary.staff_on_duty}`, '排班数据库', 'success')
        }
        GridCol({ span: 1 }) {
          this.metric('待闭环', `${this.store.snapshot.summary.open_tasks + this.store.snapshot.summary.open_alerts}`, `紧急 ${this.store.snapshot.summary.emergency_alerts}`, 'danger')
        }
      }
      .width('100%')
      .padding(6)
      .borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('app.color.cockpit_border') })
    } else {
      Row() {
        this.metric('在院长者', `${this.store.snapshot.summary.residents}`, `空床 ${this.store.snapshot.summary.free_beds}`, 'brand')
        this.divider()
        this.metric('床位使用', `${this.occupancy().toFixed(1)}%`, `${this.store.snapshot.summary.occupied_beds}/${this.store.snapshot.summary.total_beds}`, 'warning')
        this.divider()
        this.metric('今日在岗', `${this.store.snapshot.summary.staff_on_duty}`, '来自当日排班', 'success')
        this.divider()
        this.metric('护理待办', `${this.store.snapshot.summary.open_tasks}`, '未完成任务', 'warning')
        this.divider()
        this.metric('未闭环告警', `${this.store.snapshot.summary.open_alerts}`, `紧急 ${this.store.snapshot.summary.emergency_alerts}`, 'danger')
        this.divider()
        this.metric('设备在线', `${this.deviceRatio().toFixed(1)}%`, `${this.store.snapshot.summary.devices_online}/${this.store.snapshot.summary.devices_total}`, 'success')
      }
      .width('100%')
      .height(104)
      .borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('app.color.cockpit_border') })
    }
  }

  @Builder
  private divider() {
    Row().width(1).height(54).backgroundColor($r('sys.color.comp_divider'))
  }

  @Builder
  private panelTitle(title: string, subtitle: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(subtitle)
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private roomPanel() {
    Column({ space: 10 }) {
      this.panelTitle('房间运行', '入住、任务、告警与设备状态')
      if (this.store.snapshot.rooms.length === 0) {
        this.emptyState('服务器暂无房间数据')
      } else {
        List({ space: 0 }) {
          ForEach(this.store.snapshot.rooms, (room: RoomOperation) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 10 }) {
                  Column({ space: 2 }) {
                    Text(`${room.building} ${room.floor}层 · ${room.room_number}房`)
                      .fontSize($r('sys.float.Body_M'))
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('sys.color.font_primary'))
                    Text(this.residentNames(room))
                      .fontSize($r('sys.float.Caption_S'))
                      .fontColor($r('sys.color.font_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(room.status)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(dashboardToneColor(room.tone))
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .borderRadius(8)
                    .backgroundColor(dashboardToneSoftColor(room.tone))
                }
                .width('100%')

                Row({ space: 12 }) {
                  Text(`${room.occupied_beds}/${room.total_beds} 床`)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_secondary'))
                  Text(this.careLevel(room.care_level))
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_secondary'))
                  Text(`待办 ${room.open_tasks}`)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_secondary'))
                  Text(`告警 ${room.alerts}`)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_secondary'))
                  Text(`设备 ${room.devices_online}/${room.devices_total}`)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')

                Row() {
                  Text(`${room.vital_status} · 上次照护 ${room.last_round}`)
                    .layoutWeight(1)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(room.next_task)
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }
          }, (room: RoomOperation) => room.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider') })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private eventPanel() {
    Column({ space: 10 }) {
      this.panelTitle('实时告警', '按发生时间读取服务器告警记录')
      if (this.store.snapshot.events.length === 0) {
        this.emptyState('当前没有告警记录')
      } else {
        List() {
          ForEach(this.store.snapshot.events, (event: DashboardEvent) => {
            ListItem() {
              Row({ space: 10 }) {
                Stack() {
                  SymbolGlyph(this.eventIcon(event))
                    .fontSize(17)
                    .fontColor([dashboardToneColor(event.tone)])
                }
                .width(34)
                .height(34)
                .borderRadius(8)
                .backgroundColor(dashboardToneSoftColor(event.tone))
                Column({ space: 2 }) {
                  Row() {
                    Text(event.title)
                      .layoutWeight(1)
                      .fontSize($r('sys.float.Body_M'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Text(event.time)
                      .fontSize($r('sys.float.Caption_S'))
                      .fontColor($r('sys.color.font_tertiary'))
                  }
                  .width('100%')
                  Text(`${event.location} · ${event.detail}`)
                    .width('100%')
                    .fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_secondary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }
          }, (event: DashboardEvent) => event.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider'), startMargin: 44 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private wardPanel() {
    Column({ space: 10 }) {
      this.panelTitle('楼层负荷', '床位、当日排班、任务与风险')
      if (this.store.snapshot.wards.length === 0) {
        this.emptyState('服务器暂无楼层数据')
      } else {
        ForEach(this.store.snapshot.wards, (ward: WardStatus) => {
          Column({ space: 5 }) {
            Row() {
              Text(`${ward.name} ${ward.floor}`)
                .layoutWeight(1)
                .fontSize($r('sys.float.Caption_S'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text(`${ward.occupancy.toFixed(1)}%`)
                .fontSize($r('sys.float.Caption_S'))
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isOccupancyWarning(ward.occupancy) ?
                  $r('app.color.status_warning') : $r('app.color.brand_primary'))
            }
            .width('100%')
            Progress({ value: ward.occupancy, total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(5)
              .color(this.isOccupancyWarning(ward.occupancy) ?
                $r('app.color.status_warning') : $r('app.color.brand_primary'))
              .backgroundColor($r('app.color.chart_track'))
            Text(`${ward.residents}/${ward.capacity} 床 · 在岗 ${ward.staffOnDuty} · 待办 ${ward.openTasks} · 风险 ${ward.riskCount}`)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
        }, (ward: WardStatus) => ward.id)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private facilityPanel() {
    Column({ space: 10 }) {
      this.panelTitle('设备运行', '按设备产品统计在线状态')
      if (this.store.snapshot.facilities.length === 0) {
        this.emptyState('服务器暂无设备数据')
      } else {
        ForEach(this.store.snapshot.facilities, (item: FacilityStatus) => {
          Row({ space: 10 }) {
            Text(item.label)
              .layoutWeight(1)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_primary'))
            Text(`${item.online}/${item.total}`)
              .fontSize($r('sys.float.Caption_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDeviceWarning(this.facilityRatio(item)) ?
                $r('app.color.status_warning') : $r('app.color.status_success'))
            Progress({ value: this.facilityRatio(item), total: 100, type: ProgressType.Linear })
              .width(74)
              .height(5)
              .color(this.isDeviceWarning(this.facilityRatio(item)) ?
                $r('app.color.status_warning') : $r('app.color.status_success'))
              .backgroundColor($r('app.color.chart_track'))
          }
          .width('100%')
        }, (item: FacilityStatus) => item.id)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private workPanel() {
    Column({ space: 10 }) {
      this.panelTitle('照护执行', '按数据库任务类型汇总')
      if (this.store.snapshot.work_items.length === 0) {
        this.emptyState('服务器暂无护理任务')
      } else {
        ForEach(this.store.snapshot.work_items, (item: CareWorkItem) => {
          Column({ space: 4 }) {
            Row() {
              Text(item.label)
                .layoutWeight(1)
                .fontSize($r('sys.float.Caption_S'))
                .fontColor($r('sys.color.font_primary'))
              Text(`${item.completed}/${item.total}`)
                .fontSize($r('sys.float.Caption_S'))
                .fontColor(item.overdue > 0 ? $r('app.color.status_warning') : $r('app.color.status_success'))
            }
            .width('100%')
            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(5).borderRadius(3).backgroundColor($r('app.color.chart_track'))
              Row().width(dashboardProgressWidth(this.workCompletion(item))).height(5).borderRadius(3)
                .backgroundColor(item.overdue > 0 ? $r('app.color.status_warning') : $r('app.color.status_success'))
            }
            .width('100%')
          }
          .width('100%')
        }, (item: CareWorkItem) => item.id)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private riskPanel() {
    Column({ space: 10 }) {
      this.panelTitle('风险结构', '当前未闭环告警分布')
      if (this.store.snapshot.risks.length === 0) {
        this.emptyState('当前没有未闭环风险')
      } else {
        ForEach(this.store.snapshot.risks, (risk: RiskSummary) => {
          Row({ space: 8 }) {
            Row().width(8).height(8).borderRadius(4).backgroundColor(dashboardToneColor(risk.tone))
            Text(risk.label)
              .layoutWeight(1)
              .fontSize($r('sys.float.Caption_S'))
              .fontColor($r('sys.color.font_primary'))
            Text(`${risk.count} · ${risk.ratio.toFixed(0)}%`)
              .fontSize($r('sys.float.Caption_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor(dashboardToneColor(risk.tone))
          }
          .width('100%')
        }, (risk: RiskSummary) => risk.id)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }

  @Builder
  private emptyState(text: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(text)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private wideLayout() {
    Column({ space: 12 }) {
      this.header()
      this.summaryStrip()
      Row({ space: 12 }) {
        Column() {
          this.roomPanel()
        }
        .layoutWeight(64)
        .height('100%')
        Column() {
          this.eventPanel()
        }
        .layoutWeight(36)
        .height('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .constraintSize({ minHeight: 300 })
      Row({ space: 12 }) {
        Column() { this.wardPanel() }.layoutWeight(1).height('100%')
        Column() { this.workPanel() }.layoutWeight(1).height('100%')
        Column() { this.facilityPanel() }.layoutWeight(1).height('100%')
        Column() { this.riskPanel() }.layoutWeight(1).height('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 160, maxHeight: 230 })
      if (this.store.error.length > 0) {
        Text(this.store.error)
          .width('100%')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('app.color.status_danger'))
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private compactLayout() {
    Column({ space: 10 }) {
      this.header()
      if (this.store.error.length > 0) {
        Text(this.store.error)
          .width('100%')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('app.color.status_danger'))
      }
      Scroll() {
        Column({ space: 10 }) {
          this.summaryStrip()
          Column() { this.roomPanel() }.width('100%').height(420)
          Column() { this.eventPanel() }.width('100%').height(360)
          this.wardPanel()
          this.workPanel()
          this.facilityPanel()
          this.riskPanel()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (this.compact) {
      this.compactLayout()
    } else {
      this.wideLayout()
    }
  }
}
