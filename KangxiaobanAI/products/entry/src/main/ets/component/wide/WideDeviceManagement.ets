import { BusinessStore } from '../../network/BusinessStore';
import { IotDevice, Room } from '../../network/Dto';
import ApiClient from '../../network/ApiClient';

interface DeviceCreateRequest { device_id: string; product: string; room: string; building: string; }

@ComponentV2
export struct WideDeviceManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local showCreate: boolean = false;
  @Local deviceId: string = '';
  @Local deviceType: string = '毫米波雷达';
  @Local room: string = '';
  @Local error: string = '';

  aboutToAppear(): void { this.businessStore.load(); }

  private productName(product: string): string { return product === 'fall_radar' ? '毫米波跌倒雷达' : product === 'breath_radar' ? '毫米波呼吸雷达' : product === 'camera' ? '摄像头' : product || '未知设备'; }
  private async createDevice(): Promise<void> {
    const target: Room | undefined = this.businessStore.rooms.find((item: Room) => item.room_no === this.room);
    const request: DeviceCreateRequest = { device_id: this.deviceId.trim(), product: this.deviceType === '摄像头' ? 'camera' : 'fall_radar', room: this.room, building: target?.building ?? '' };
    if (!request.device_id || !request.room) { this.error = '设备编号和绑定房间不能为空'; return; }
    try { const response = await ApiClient.post<IotDevice>('/iot/devices', request); if (response.code !== 0) throw new Error(response.msg); this.showCreate = false; this.deviceId = ''; this.room = ''; await this.businessStore.load(true); } catch (_error) { this.error = '设备添加失败'; }
  }

  @Builder
  private createDialog() {
    if (this.showCreate) {
      Column({ space: 12 }) {
        Text('添加设备').fontSize(20).fontWeight(FontWeight.Medium)
        TextInput({ placeholder: '设备编号', text: $$this.deviceId }).height(42)
        Row({ space: 8 }) { Button('毫米波').layoutWeight(1).height(36).fontColor(this.deviceType === '毫米波雷达' ? Color.White : $r('sys.color.font_secondary')).backgroundColor(this.deviceType === '毫米波雷达' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).onClick(() => this.deviceType = '毫米波雷达'); Button('摄像头').layoutWeight(1).height(36).fontColor(this.deviceType === '摄像头' ? Color.White : $r('sys.color.font_secondary')).backgroundColor(this.deviceType === '摄像头' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).onClick(() => this.deviceType = '摄像头') }.width('100%')
        TextInput({ placeholder: '绑定房间号，例如 101', text: $$this.room }).height(42)
        Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showCreate = false); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.createDevice()) }.width('100%')
      }.width(this.compactWidth ? '90%' : 440).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) { Column({ space: 16 }) {
        Row() { Column({ space: 4 }) { Text('设备管理').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold); Text('添加毫米波设备或摄像头，并绑定到房间').fontSize(11).fontColor($r('sys.color.font_secondary')) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Button('添加设备').height(36).fontSize(12).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.showCreate = true) }.width('100%')
        if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
        ForEach(this.businessStore.devices, (device: IotDevice) => { Row({ space: 14 }) { Column({ space: 4 }) { Text(this.productName(device.product)).fontSize(14).fontWeight(FontWeight.Medium); Text(device.device_id).fontSize(11).fontColor($r('sys.color.font_secondary')) }.layoutWeight(1).alignItems(HorizontalAlign.Start); Text(device.building ? `${device.building} · ${device.room}` : '未绑定房间').fontSize(12).fontColor($r('sys.color.font_secondary')); Text(device.online === 1 ? '在线' : '离线').fontSize(12).fontColor(device.online === 1 ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary')) }.width('100%').height(58).padding({ left: 14, right: 14 }).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') }) }, (device: IotDevice) => `device-${device.id}`)
      }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }) }.width('100%').height('100%').scrollBar(BarState.Off)
      if (this.showCreate) Row() { this.createDialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%')
  }
}
