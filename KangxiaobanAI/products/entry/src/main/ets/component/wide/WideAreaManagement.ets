import ApiClient from '../../network/ApiClient';
import { Area, Bed, Room } from '../../network/Dto';
import { BusinessStore } from '../../network/BusinessStore';

interface AreaPage { list: Area[]; }
interface AreaCreateRequest { type: string; code: string; name: string; building: string; floor_no: number; status: string; }
interface AreaChoice { code: string; label: string; }
interface BedCreateRequest { room_id: number; bed_no: string; status: string; }

@ComponentV2
export struct WideAreaManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local areas: Area[] = [];
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local showCreate: boolean = false;
  @Local type: string = 'room';
  @Local code: string = '';
  @Local name: string = '';
  @Local building: string = '';
  @Local floorNo: string = '';
  @Local showBedCreate: boolean = false;
  @Local bedTargetRoomId: number = 0;
  @Local bedNo: string = '';
  @Local error: string = '';
  @Local loading: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(); this.businessStore.load(); }

  private async load(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const response = await ApiClient.get<AreaPage>('/areas');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.areas = response.data.list ?? [];
    } catch (_error) { this.error = '区域数据加载失败'; }
    this.loading = false;
  }

  private typeLabel(value: string): string {
    switch (value) { case 'floor': return '楼层'; case 'room': return '房间'; case 'corridor': return '走廊'; case 'stair': return '楼梯'; case 'common': return '公共区'; default: return '其他'; }
  }

  private roomForArea(area: Area): Room | undefined {
    return this.businessStore.rooms.find((room: Room) => area.type === 'room' && room.building === area.building && room.floor === (area.floor_no ?? 0) && room.room_no === area.name);
  }

  private bedCount(area: Area): number {
    const room: Room | undefined = this.roomForArea(area);
    return room === undefined ? 0 : this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id).length;
  }

  private async create(): Promise<void> {
    if (this.code.trim().length === 0 || this.name.trim().length === 0) { this.error = '区域编码和名称不能为空'; return; }
    const request: AreaCreateRequest = { type: this.type, code: this.code.trim(), name: this.name.trim(), building: this.building.trim(), floor_no: Number(this.floorNo) || 0, status: 'active' };
    const response = await ApiClient.post<Area>('/areas', request);
    if (response.code !== 0) { this.error = response.msg || '区域创建失败'; return; }
    this.showCreate = false; this.code = ''; this.name = ''; this.building = ''; this.floorNo = ''; await this.load();
  }

  private openBedCreate(area: Area): void {
    const room: Room | undefined = this.roomForArea(area);
    if (room === undefined) { this.error = '该区域尚未关联历史房间记录'; return; }
    this.bedTargetRoomId = room.id; this.bedNo = ''; this.showBedCreate = true;
  }

  private async createBed(): Promise<void> {
    if (this.bedTargetRoomId === 0 || this.bedNo.trim() === '') { this.error = '床位号不能为空'; return; }
    const request: BedCreateRequest = { room_id: this.bedTargetRoomId, bed_no: this.bedNo.trim(), status: 'free' };
    const response = await ApiClient.post<Bed>('/beds', request);
    if (response.code !== 0) { this.error = response.msg || '床位创建失败'; return; }
    this.showBedCreate = false; this.bedNo = ''; await this.businessStore.load(true);
  }

  @Builder
  private dialog() {
    if (this.showCreate) {
      Column({ space: 12 }) {
        Text('新增区域').fontSize(20).fontWeight(FontWeight.Medium)
        Row({ space: 8 }) {
          ForEach([{ code: 'floor', label: '楼层' }, { code: 'room', label: '房间' }, { code: 'corridor', label: '走廊' }, { code: 'stair', label: '楼梯' }, { code: 'common', label: '公共区' }] as AreaChoice[], (item: AreaChoice) => {
            Button(item.label).layoutWeight(1).height(34).fontSize(11).backgroundColor(this.type === item.code ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.type === item.code ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.type = item.code)
          }, (item: AreaChoice) => item.code)
        }
        TextInput({ placeholder: '区域编码，例如 A-room-103', text: $$this.code }).height(42)
        TextInput({ placeholder: '区域名称，例如 103', text: $$this.name }).height(42)
        TextInput({ placeholder: '楼栋，可选', text: $$this.building }).height(42)
        TextInput({ placeholder: '楼层，可选', text: $$this.floorNo }).height(42).type(InputType.Number)
        Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showCreate = false); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.create()) }.width('100%')
      }.width(this.compactWidth ? '90%' : 460).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Row() { Column({ space: 4 }) { Text('区域管理').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold); Text('楼层、房间、床位以及走廊、楼梯等机构空间').fontSize(11).fontColor($r('sys.color.font_secondary')) }.layoutWeight(1); Button('新增区域').height(36).fontSize(12).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.showCreate = true) }.width('100%')
          if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
          if (this.loading) LoadingProgress().width(34).height(34)
          ForEach(this.areas, (area: Area) => {
            Row({ space: 14 }) {
              SymbolGlyph(area.type === 'room' ? $r('sys.symbol.house_fill') : $r('sys.symbol.square_grid_2x2')).fontSize(22).fontColor([area.type === 'room' ? $r('app.color.brand_blue') : $r('app.color.doctor_workspace_accent')])
              Column({ space: 4 }) { Text(area.name).fontSize(15).fontWeight(FontWeight.Medium); Text(`${this.typeLabel(area.type)} · ${area.code}`).fontSize(11).fontColor($r('sys.color.font_secondary')) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (area.type === 'room') { Text(`${this.bedCount(area)}/2 床位`).fontSize(12).fontColor($r('sys.color.font_secondary')); Button('加床').height(28).fontSize(11).onClick(() => this.openBedCreate(area)) }
              Text(area.status === 'active' ? '启用' : '停用').fontSize(12).fontColor(area.status === 'active' ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
            }.width('100%').height(62).padding({ left: 14, right: 14 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
          }, (area: Area) => `area-${area.id}`)
          if (!this.loading && this.areas.length === 0) Text('暂无区域，请先新增楼层或房间').fontSize(13).fontColor($r('sys.color.font_tertiary')).padding({ top: 48, bottom: 48 })
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      }.width('100%').height('100%').scrollBar(BarState.Off)
      if (this.showCreate) Row() { this.dialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      if (this.showBedCreate) Row() {
        Column({ space: 12 }) {
          Text('新增床位').fontSize(20).fontWeight(FontWeight.Medium)
          TextInput({ placeholder: '床位号，例如 1', text: $$this.bedNo }).height(42)
          Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showBedCreate = false); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.createBed()) }.width('100%')
        }.width(this.compactWidth ? '90%' : 420).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%')
  }
}
