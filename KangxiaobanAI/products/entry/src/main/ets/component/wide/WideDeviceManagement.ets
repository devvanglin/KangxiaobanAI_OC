import { BusinessStore } from '../../network/BusinessStore';
import { Area, IotDevice, Room } from '../../network/Dto';
import ApiClient from '../../network/ApiClient';

interface DeviceCreateRequest { device_id: string; product: string; device_type: string; room: string; building: string; bed: string; area_id?: number; stream_url?: string; }
interface DeviceUpdateRequest { device_type: string; room: string; building: string; bed: string; area_id?: number; stream_url?: string; }
interface AreaPage { list: Area[]; }
interface SignalRecord { id: number; type: string; value: string; ts: string; }
interface SignalPage { list: SignalRecord[]; }

@ComponentV2
export struct WideDeviceManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local areas: Area[] = [];
  @Local showCreate: boolean = false;
  @Local editingDeviceId: number = 0;
  @Local deviceId: string = '';
  @Local deviceType: string = '毫米波雷达';
  @Local room: string = '';
  @Local bed: string = '';
  @Local cameraIp: string = '';
  @Local areaId: number = 0;
  @Local showSignals: boolean = false;
  @Local signalDeviceName: string = '';
  @Local signals: SignalRecord[] = [];
  @Local previewUrl: string = '';
  private videoController: VideoController = new VideoController();
  @Local error: string = '';

  aboutToAppear(): void { this.businessStore.load(); this.loadAreas(); }

  private async loadAreas(): Promise<void> { try { const response = await ApiClient.get<AreaPage>('/areas'); if (response.code === 0 && response.data !== undefined) this.areas = response.data.list ?? []; } catch (_error) {} }

  private productName(product: string): string { return product === 'fall_radar' ? '毫米波跌倒雷达' : product === 'breath_radar' ? '毫米波呼吸雷达' : product === 'camera' ? '摄像头' : product || '未知设备'; }
  private productSymbol(product: string): Resource {
    return product === 'camera' ? $r('sys.symbol.camera_fill') :
      product === 'fall_radar' || product === 'breath_radar' ? $r('sys.symbol.dot_radiowaves_left_and_right') :
      $r('sys.symbol.device_2');
  }

  private productTint(product: string): Resource {
    return product === 'camera' ? $r('app.color.brand_blue') :
      product === 'fall_radar' || product === 'breath_radar' ? $r('app.color.doctor_workspace_accent') :
      $r('sys.color.icon_secondary');
  }

  private async createDevice(): Promise<void> {
    const target: Room | undefined = this.businessStore.rooms.find((item: Room) => item.room_no === this.room);
    const isCamera: boolean = this.deviceType === '摄像头';
    const request: DeviceCreateRequest = { device_id: this.deviceId.trim(), product: isCamera ? 'camera' : 'fall_radar', device_type: isCamera ? 'camera' : 'millimeter_wave', room: this.room, building: target?.building ?? '', bed: this.bed, area_id: this.areaId > 0 ? this.areaId : undefined, stream_url: isCamera ? `rtsp://${this.cameraIp.trim()}:8554/stream0` : '' };
    if (!request.device_id) { this.error = '设备编号不能为空'; return; }
    if (isCamera && this.cameraIp.trim().length === 0) { this.error = '摄像头 IP 不能为空'; return; }
    try { const response = await ApiClient.post<IotDevice>('/iot/devices', request); if (response.code !== 0) throw new Error(response.msg); this.showCreate = false; this.deviceId = ''; this.room = ''; this.bed = ''; this.cameraIp = ''; this.areaId = 0; await this.businessStore.load(true); } catch (_error) { this.error = '设备添加失败'; }
  }

  private extractCameraIp(streamUrl: string | null | undefined): string {
    const value: string = streamUrl ?? '';
    if (!value.startsWith('rtsp://')) {
      return '';
    }
    const hostPart: string = value.substring(7).split('/')[0];
    return hostPart.split(':')[0];
  }

  private openEdit(device: IotDevice): void {
    this.editingDeviceId = device.id;
    this.deviceId = device.device_id ?? '';
    this.deviceType = device.device_type === 'camera' ? '摄像头' : device.device_type === 'other' ? '其他' : '毫米波雷达';
    this.room = device.room ?? '';
    this.bed = device.bed ?? '';
    this.areaId = device.area_id ?? 0;
    this.cameraIp = this.extractCameraIp(device.stream_url);
    this.error = '';
    this.showCreate = true;
  }

  private resetEditor(): void {
    this.editingDeviceId = 0;
    this.deviceId = '';
    this.deviceType = '毫米波雷达';
    this.room = '';
    this.bed = '';
    this.cameraIp = '';
    this.areaId = 0;
  }

  private async saveDevice(): Promise<void> {
    if (this.editingDeviceId === 0) {
      await this.createDevice();
      return;
    }
    const isCamera: boolean = this.deviceType === '摄像头';
    if (isCamera && this.cameraIp.trim().length === 0) {
      this.error = '摄像头 IP 不能为空';
      return;
    }
    const target: Room | undefined = this.businessStore.rooms.find((item: Room) => item.room_no === this.room);
    const request: DeviceUpdateRequest = {
      device_type: isCamera ? 'camera' : this.deviceType === '其他' ? 'other' : 'millimeter_wave',
      room: this.room.trim(),
      building: target?.building ?? '',
      bed: this.bed.trim(),
      area_id: this.areaId > 0 ? this.areaId : undefined,
      stream_url: isCamera ? `rtsp://${this.cameraIp.trim()}:8554/stream0` : ''
    };
    try {
      const response = await ApiClient.patch<IotDevice>(`/iot/devices/${this.editingDeviceId}`, request);
      if (response.code !== 0) {
        throw new Error(response.msg);
      }
      this.showCreate = false;
      this.resetEditor();
      await this.businessStore.load(true);
    } catch (_error) {
      this.error = '设备更新失败';
    }
  }

  private openPreview(device: IotDevice): void { this.previewUrl = device.stream_url ?? ''; }

  private async openSignals(device: IotDevice): Promise<void> {
    try {
      const response = await ApiClient.get<SignalPage>(`/iot/devices/${device.id}/signals?limit=40`);
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.signals = response.data.list ?? []; this.signalDeviceName = device.device_id; this.showSignals = true;
    } catch (_error) { this.error = '毫米波信号加载失败'; }
  }

  private deviceLocation(device: IotDevice): string {
    const area: Area | undefined = device.area_id === undefined ? undefined :
      this.areas.find((item: Area) => item.id === device.area_id);
    if (area !== undefined) {
      return area.name;
    }
    const building: string = device.building ?? '';
    const room: string = device.room ?? '';
    if (building.length > 0 || room.length > 0) {
      return `${building}${building.length > 0 && room.length > 0 ? ' · ' : ''}${room}`;
    }
    return '未分配区域';
  }

  private deviceStatus(device: IotDevice): string {
    if (device.discovery_status === 'pending') {
      return '待认领';
    }
    return device.online === 1 ? '在线' : '离线';
  }

  private deviceStatusColor(device: IotDevice): ResourceColor {
    if (device.discovery_status === 'pending') {
      return $r('app.color.doctor_workspace_warning');
    }
    return device.online === 1 ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary');
  }

  private streamValue(device: IotDevice): string {
    return device.stream_url ?? '';
  }

  private deviceIdValue(device: IotDevice): string {
    return device.device_id ?? '--';
  }

  private batteryValue(device: IotDevice): string {
    return device.battery === undefined || device.battery === null ? '毫米波信号等待上报' : `电量 ${device.battery}% · 毫米波信号`;
  }

  @Builder
  private deviceCard(device: IotDevice) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph(this.productSymbol(device.product)).fontSize(24).fontColor([this.productTint(device.product)])
        }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(12)
        Column({ space: 4 }) {
          Text(this.productName(device.product)).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text(this.deviceIdValue(device)).fontSize(11).fontColor($r('sys.color.font_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.deviceStatus(device)).fontSize(11).fontColor(this.deviceStatusColor(device)).padding({ left: 9, right: 9, top: 5, bottom: 5 }).backgroundColor(device.online === 1 ? $r('app.color.status_normal_bg') : $r('sys.color.comp_background_secondary')).borderRadius(12)
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text('绑定位置').fontSize(11).fontColor($r('sys.color.font_tertiary'))
          Text(this.deviceLocation(device)).fontSize(13).fontColor($r('sys.color.font_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 5 }) {
          Text('接入协议').fontSize(11).fontColor($r('sys.color.font_tertiary'))
          Text(device.protocol === 'RTSP' ? 'RTSP' : 'MQTT').fontSize(13).fontColor($r('sys.color.font_primary'))
        }.width(82).alignItems(HorizontalAlign.Start)
        Column({ space: 5 }) {
          Text('最近上报').fontSize(11).fontColor($r('sys.color.font_tertiary'))
          Text(device.last_seen === undefined || device.last_seen === null ? '--' : device.last_seen.slice(11, 19)).fontSize(13).fontColor($r('sys.color.font_primary'))
        }.width(82).alignItems(HorizontalAlign.Start)
      }.width('100%')
      if (device.device_type === 'camera') {
        Text(this.streamValue(device).length === 0 ? '未配置 RTSP 流地址' : this.streamValue(device)).fontSize(11).fontColor($r('sys.color.font_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text(this.batteryValue(device)).fontSize(11).fontColor($r('sys.color.font_secondary'))
      }
      Row({ space: 8 }) {
        if (device.device_type === 'camera' && this.streamValue(device).length > 0) {
          Button('预览').layoutWeight(1).height(32).fontSize(11).onClick(() => this.openPreview(device))
        }
        if (device.device_type !== 'camera') {
          Button('查看信号').layoutWeight(1).height(32).fontSize(11).onClick(() => this.openSignals(device))
        }
        Button('编辑').layoutWeight(1).height(32).fontSize(11).onClick(() => this.openEdit(device))
      }.width('100%')
    }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(14).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private createDialog() {
    if (this.showCreate) {
      Column({ space: 12 }) {
        Text(this.editingDeviceId > 0 ? '编辑设备' : '添加设备').fontSize(20).fontWeight(FontWeight.Medium)
        TextInput({ placeholder: '设备编号', text: $$this.deviceId }).height(42).enabled(this.editingDeviceId === 0)
        Row({ space: 8 }) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right')).fontSize(16)
                .fontColor([this.deviceType === '毫米波雷达' ? Color.White : $r('sys.color.icon_secondary')])
              Text('毫米波').fontSize(13)
                .fontColor(this.deviceType === '毫米波雷达' ? Color.White : $r('sys.color.font_secondary'))
            }
          }.layoutWeight(1).height(36).backgroundColor(this.deviceType === '毫米波雷达' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
            .accessibilityText('选择毫米波雷达').onClick(() => this.deviceType = '毫米波雷达')
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(16)
                .fontColor([this.deviceType === '摄像头' ? Color.White : $r('sys.color.icon_secondary')])
              Text('摄像头').fontSize(13)
                .fontColor(this.deviceType === '摄像头' ? Color.White : $r('sys.color.font_secondary'))
            }
          }.layoutWeight(1).height(36).backgroundColor(this.deviceType === '摄像头' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
            .accessibilityText('选择摄像头').onClick(() => this.deviceType = '摄像头')
          Button('其他').layoutWeight(1).height(36).fontSize(13).backgroundColor(this.deviceType === '其他' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.deviceType === '其他' ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.deviceType = '其他')
        }.width('100%')
        if (this.deviceType === '摄像头') { TextInput({ placeholder: '摄像头 IP，例如 192.168.1.20', text: $$this.cameraIp }).height(42) }
        TextInput({ placeholder: '绑定房间号，可选，例如 101', text: $$this.room }).height(42)
        TextInput({ placeholder: '床位号，可选，例如 1', text: $$this.bed }).height(42)
        Text('绑定区域（可选）').fontSize(12).fontColor($r('sys.color.font_secondary'))
        ForEach(this.areas, (area: Area) => Button(area.name).width('100%').height(32).fontSize(11).backgroundColor(this.areaId === area.id ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.areaId === area.id ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.areaId = area.id), (area: Area) => `device-area-${area.id}`)
        Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => { this.showCreate = false; this.resetEditor(); }); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.saveDevice()) }.width('100%')
      }.width(this.compactWidth ? '90%' : 440).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) { Column({ space: 16 }) {
        Row() { Column({ space: 4 }) { Text('设备管理').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold); Text('添加毫米波设备或摄像头，并绑定到房间').fontSize(11).fontColor($r('sys.color.font_secondary')) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Button('添加设备').height(36).fontSize(12).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.showCreate = true) }.width('100%')
        if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
        if (this.businessStore.devices.length > 0) {
          GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
            ForEach(this.businessStore.devices, (device: IotDevice) => {
              GridCol({ span: this.compactWidth ? 12 : 6 }) {
                this.deviceCard(device)
              }
            }, (device: IotDevice) => `device-card-${device.id}`)
          }.width('100%')
        } else if (!this.businessStore.loading) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.beacon_tower_fill')).fontSize(32).fontColor([$r('sys.color.icon_secondary')])
            Text('暂无设备').fontSize(15).fontWeight(FontWeight.Medium)
            Text('毫米波设备可通过 MQTT 自动发现，摄像头可手动添加。').fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.width('100%').padding({ top: 48, bottom: 48 }).alignItems(HorizontalAlign.Center)
        }
      }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }) }.width('100%').height('100%').scrollBar(BarState.Off)
      if (this.showCreate) Row() { this.createDialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      if (this.previewUrl.length > 0) Row() {
        Column({ space: 12 }) {
          Text('摄像头预览').fontSize(18).fontWeight(FontWeight.Medium)
          Video({ src: this.previewUrl, controller: this.videoController }).width(this.compactWidth ? '100%' : 620).height(this.compactWidth ? 220 : 360).controls(true).objectFit(ImageFit.Contain).onError(() => this.error = 'RTSP 播放失败，请检查摄像头或转码服务')
          Button('关闭').width('100%').height(40).onClick(() => { this.videoController.pause(); this.previewUrl = ''; })
        }.width(this.compactWidth ? '90%' : 660).padding(20).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      if (this.showSignals) Row() {
        Column({ space: 12 }) {
          Text(`毫米波信号 · ${this.signalDeviceName}`).fontSize(18).fontWeight(FontWeight.Medium)
          if (this.signals.length === 0) Text('暂无信号记录，等待设备上报').fontSize(13).fontColor($r('sys.color.font_secondary')).padding(24)
          ForEach(this.signals, (signal: SignalRecord) => Row() { Text(signal.type).width(150).fontSize(12); Text(signal.value).layoutWeight(1).fontSize(13); Text(signal.ts.length >= 19 ? signal.ts.slice(11, 19) : signal.ts).fontSize(11).fontColor($r('sys.color.font_secondary')) }.width('100%').height(36), (signal: SignalRecord) => `signal-${signal.id}`)
          Button('关闭').width('100%').height(40).onClick(() => this.showSignals = false)
        }.width(this.compactWidth ? '90%' : 520).padding(20).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%')
  }
}
