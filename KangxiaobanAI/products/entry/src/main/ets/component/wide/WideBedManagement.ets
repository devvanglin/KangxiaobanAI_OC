import { BusinessStore } from '../../network/BusinessStore';
import { Bed, Room } from '../../network/Dto';

@ComponentV2
struct BedTile {
  @Param @Require bed: Bed;
  @Param @Require elderName: string;

  private statusText(): string {
    if (this.bed.status === 'occupied') return this.elderName;
    if (this.bed.status === 'maintenance') return '请假中';
    return '空闲';
  }

  private statusColor(): ResourceColor {
    if (this.bed.status === 'occupied') return $r('app.color.doctor_workspace_focus');
    if (this.bed.status === 'maintenance') return $r('app.color.doctor_workspace_warning');
    return $r('app.color.doctor_workspace_success');
  }

  build() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.house_fill')).fontSize(18).fontColor([this.statusColor()])
      Column({ space: 4 }) {
        Text(`床位号：${this.bed.bed_no}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        Text(this.statusText()).fontSize(13).fontColor(this.statusColor()).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').height(66).padding({ left: 12, right: 10 })
      .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(6)
  }
}

@ComponentV2
struct RoomCard {
  @Param @Require room: Room;
  @Param @Require beds: Bed[];
  @Param @Require elderName: (id?: number) => string;
  @Event onHint: (action: string) => void = (_action: string) => {};

  build() {
    Column({ space: 14 }) {
      Row() {
        Text(this.room.room_no).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text('  ').fontSize(12)
        Text('编辑').fontSize(11).fontColor($r('sys.color.font_secondary')).onClick(() => this.onHint('编辑房间'))
        Text('删除').fontSize(11).fontColor($r('sys.color.font_secondary')).margin({ left: 10 }).onClick(() => this.onHint('删除房间'))
        Blank().layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)
      GridRow({ columns: 2, gutter: { x: 10, y: 10 } }) {
        ForEach(this.beds, (bed: Bed) => {
          GridCol({ span: 1 }) { BedTile({ bed: bed, elderName: this.elderName(bed.elder_id) }) }
        }, (bed: Bed) => `room-bed-${bed.id}`)
      }.width('100%')
    }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }
}

@ComponentV2
export struct WideBedManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local selectedFloor: number = 0;

  aboutToAppear(): void {
    setTimeout((): void => { this.managementScroller.scrollEdge(Edge.Top); }, 0);
    this.businessStore.load();
  }

  private floors(): number[] {
    const values: number[] = [];
    this.businessStore.rooms.forEach((room: Room) => { if (values.indexOf(room.floor) < 0) values.push(room.floor); });
    return values.sort((a: number, b: number) => a - b);
  }

  private visibleRooms(): Room[] {
    const floor: number = this.selectedFloor === 0 ? (this.floors()[0] ?? 0) : this.selectedFloor;
    return this.businessStore.rooms.filter((room: Room) => room.floor === floor)
      .sort((a: Room, b: Room) => a.room_no.localeCompare(b.room_no));
  }

  private bedsForRoom(roomId: number): Bed[] { return this.businessStore.beds.filter((bed: Bed) => bed.room_id === roomId); }
  private elderName(id?: number): string { return id === undefined ? '空闲' : this.businessStore.elders.find((elder) => elder.id === id)?.name ?? '已入住'; }
  private hint(action: string): void { try { this.getUIContext().getPromptAction().showToast({ message: `${action}功能即将开放` }); } catch (_error) {} }

  @Builder
  private floorTabs() {
    Row() {
      ForEach(this.floors(), (floor: number) => {
        Text(`${floor}楼`).fontSize(14).fontWeight(this.selectedFloor === floor || (this.selectedFloor === 0 && floor === this.floors()[0]) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.selectedFloor === floor || (this.selectedFloor === 0 && floor === this.floors()[0]) ? $r('app.color.brand_blue') : $r('sys.color.font_primary'))
          .padding({ left: 20, right: 20, top: 14, bottom: 12 })
          .border({ width: { bottom: this.selectedFloor === floor || (this.selectedFloor === 0 && floor === this.floors()[0]) ? 2 : 0 }, color: { bottom: $r('app.color.brand_blue') } })
          .onClick(() => this.selectedFloor = floor)
      }, (floor: number) => `floor-${floor}`)
      Blank().layoutWeight(1)
      Text('新增楼层').fontSize(13).fontColor($r('app.color.brand_blue')).padding({ right: 10 }).onClick(() => this.hint('新增楼层'))
    }.width('100%').height(52).alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  @Builder
  private legend() {
    Row({ space: 28 }) {
      Row({ space: 8 }) { SymbolGlyph($r('sys.symbol.house_fill')).fontSize(17).fontColor([$r('app.color.doctor_workspace_success')]); Text('空闲中').fontSize(12) }
      Row({ space: 8 }) { SymbolGlyph($r('sys.symbol.house_fill')).fontSize(17).fontColor([$r('app.color.doctor_workspace_focus')]); Text('已入住').fontSize(12) }
      Row({ space: 8 }) { SymbolGlyph($r('sys.symbol.house_fill')).fontSize(17).fontColor([$r('app.color.doctor_workspace_warning')]); Text('请假中').fontSize(12) }
      Blank().layoutWeight(1)
      Button('新增房间').height(34).fontSize(12).borderRadius(6)
        .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
        .onClick(() => this.hint('新增房间'))
    }.width('100%').height(46).alignItems(VerticalAlign.Center)
  }

  build() {
    Scroll(this.managementScroller) {
      Column({ space: 0 }) {
        this.floorTabs()
        this.legend()
        if (this.businessStore.loading && this.businessStore.rooms.length === 0) {
          LoadingProgress().width(36).height(36).margin({ top: 60 })
        } else if (this.visibleRooms().length === 0) {
          Text('当前楼层暂无房间').fontSize(13).fontColor($r('sys.color.font_tertiary')).margin({ top: 60 })
        } else {
          GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
            ForEach(this.visibleRooms(), (room: Room) => {
              GridCol({ span: this.compactWidth ? 12 : 4 }) {
                RoomCard({ room: room, beds: this.bedsForRoom(room.id), elderName: (id?: number) => this.elderName(id), onHint: (action: string) => this.hint(action) })
              }
            }, (room: Room) => `room-${room.id}`)
          }.width('100%').padding({ top: 16 })
        }
      }.width('100%').padding({ left: this.compactWidth ? 12 : 20, right: this.compactWidth ? 12 : 20,
        top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }).alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
  }
}
