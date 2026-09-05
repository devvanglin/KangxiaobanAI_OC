import { BusinessStore } from '../../network/BusinessStore';
import { Area, IotDevice, Room } from '../../network/Dto';
import ApiClient from '../../network/ApiClient';
import { ApiConfig } from '../../network/ApiConfig';

interface PreviewResult { id: number; url: string; stream_url: string; }

interface DeviceCreateRequest { device_id: string; product: string; device_type: string; room: string; building: string; bed: string; area_id?: number; stream_url?: string; }
interface DeviceUpdateRequest { device_type: string; room: string; building: string; bed: string; area_id?: number; stream_url?: string; }
interface AreaPage { list: Area[]; }
interface SignalRecord { id: number; type: string; value: string; ts: string; }
interface SignalPage { list: SignalRecord[]; }
interface StatCardParam { label: string; value: string; subtitle: string; valueColor?: string; }

const DARK_BUTTON_BG: string = '#1F1F1F';

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
  @Local searchQuery: string = '';
  @Local typeFilter: string = '全部';
  private readonly typeFilters: string[] = ['全部', '毫米波雷达', '摄像头', '其他'];

  aboutToAppear(): void { this.businessStore.load(); this.loadAreas(); }

  private deviceTypeName(device: IotDevice): string {
    if (device.device_type === 'camera' || device.product === 'camera') { return '摄像头'; }
    if (device.device_type === 'other') { return '其他'; }
    return this.productName(device.product);
  }

  private filteredDevices(): IotDevice[] {
    const query: string = this.searchQuery.trim().toLowerCase();
    return this.businessStore.devices.filter((device: IotDevice) => {
      if (this.typeFilter === '毫米波雷达' && device.product !== 'fall_radar' && device.product !== 'breath_radar') { return false; }
      if (this.typeFilter === '摄像头' && device.product !== 'camera' && device.device_type !== 'camera') { return false; }
      if (this.typeFilter === '其他' && device.device_type !== 'other') { return false; }
      if (query.length === 0) { return true; }
      return (device.device_id ?? '').toLowerCase().includes(query) ||
        this.productName(device.product).toLowerCase().includes(query) ||
        this.deviceTypeName(device).toLowerCase().includes(query);
    });
  }

  private onlineCount(): number {
    return this.businessStore.devices.filter((device: IotDevice) => device.online === 1).length;
  }

  private offlineCount(): number {
    return this.businessStore.devices.filter((device: IotDevice) => device.online !== 1).length;
  }

  private pendingCount(): number {
    return this.businessStore.devices.filter((device: IotDevice) => device.discovery_status === 'pending').length;
  }

  private onlineRate(): string {
    const total: number = this.businessStore.devices.length;
    if (total === 0) { return '0%'; }
    return String(Math.round(this.onlineCount() / total * 1000) / 10) + '%';
  }

  private relativeHeartbeat(lastSeen: string | null | undefined): string {
    if (lastSeen === undefined || lastSeen === null || lastSeen.length === 0) { return '—'; }
    const normalized: string = lastSeen.endsWith('Z') ? lastSeen : lastSeen + 'Z';
    const ts: number = Date.parse(normalized);
    if (Number.isNaN(ts)) { return lastSeen.slice(11, 19); }
    const seconds: number = Math.max(0, Math.floor((Date.now() - ts) / 1000));
    if (seconds < 60) { return seconds + '秒前'; }
    const minutes: number = Math.floor(seconds / 60);
    if (minutes < 60) { return minutes + '分钟前'; }
    const hours: number = Math.floor(minutes / 60);
    if (hours < 24) { return hours + '小时前'; }
    return Math.floor(hours / 24) + '天前';
  }

  private statusTintBg(device: IotDevice): string {
    if (device.discovery_status === 'pending') { return '#FDF3E0'; }
    return device.online === 1 ? '#E8F5EE' : '#FDECEC';
  }

  private statusTintFg(device: IotDevice): string {
    if (device.discovery_status === 'pending') { return '#B7791F'; }
    return device.online === 1 ? '#2E8B57' : '#C0392B';
  }

  private openDeviceDetail(device: IotDevice): void {
    if (device.device_type === 'camera' || device.product === 'camera') {
      this.openPreview(device);
    } else {
      this.openSignals(device);
    }
  }

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

  private async openPreview(device: IotDevice): Promise<void> {
    this.error = '';
    this.videoController.pause();
    try {
      const response = await ApiClient.get<PreviewResult>(`/iot/devices/${device.id}/preview`);
      if (response.code !== 0 || response.data === undefined) {
        throw new Error(response.msg);
      }
      // 后端把 RTSP 转成 HLS，这里播放 HLS 地址（HarmonyOS Video 不直接支持 RTSP）。
      this.previewUrl = ApiConfig.API_BASE + response.data.url;
    } catch (_error) {
      this.error = '视频预览启动失败：请确认后端已部署 ffmpeg 且摄像头 RTSP 可达';
    }
  }

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
  private statCard($$: StatCardParam) {
    Column({ space: 6 }) {
      Text($$.label).fontSize(12).fontColor($r('sys.color.font_secondary'))
      Text($$.value).fontSize(24).fontWeight(FontWeight.Bold)
        .fontColor($$.valueColor !== undefined && $$.valueColor.length > 0 ? $$.valueColor : $r('sys.color.font_primary'))
      Text($$.subtitle).fontSize(11).fontColor($r('sys.color.font_tertiary'))
    }.alignItems(HorizontalAlign.Start)
      .layoutWeight(1).padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private statCards() {
    Row({ space: 12 }) {
      this.statCard({ label: '设备总数', value: String(this.businessStore.devices.length), subtitle: '毫米波雷达 + 摄像头' })
      this.statCard({ label: '在线设备', value: String(this.onlineCount()), subtitle: '在线率 ' + this.onlineRate() })
      this.statCard({ label: '离线设备', value: String(this.offlineCount()), subtitle: '需关注', valueColor: this.offlineCount() > 0 ? '#C0392B' : '' })
      this.statCard({ label: '待认领设备', value: String(this.pendingCount()), subtitle: 'MQTT 自动发现后认领' })
    }.width('100%')
  }

  @Builder
  private typeChipsRow() {
    Row({ space: 8 }) {
      ForEach(this.typeFilters, (label: string) => {
        Text(label)
          .fontSize(13)
          .fontColor(this.typeFilter === label ? Color.White : $r('sys.color.font_primary'))
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(8)
          .backgroundColor(this.typeFilter === label ? '#1F1F1F' : $r('sys.color.comp_background_secondary'))
          .onClick(() => this.typeFilter = label)
      }, (label: string) => 'type-chip-' + label)
    }.width('100%')
  }

  @Builder
  private tableHeaderCell(label: string, weight: number) {
    Text(label).fontSize(12).fontColor($r('sys.color.font_tertiary')).layoutWeight(weight)
  }

  @Builder
  private tableHeader() {
    Row({ space: 12 }) {
      this.tableHeaderCell('设备信息', 2.2)
      this.tableHeaderCell('设备类型', 1.3)
      this.tableHeaderCell('安装位置', 1.6)
      this.tableHeaderCell('关联床位', 1)
      this.tableHeaderCell('状态', 1)
      this.tableHeaderCell('最后心跳', 1.3)
      this.tableHeaderCell('操作', 1.4)
    }.width('100%').padding({ top: 10, bottom: 10 })
  }

  @Builder
  private tableRow(device: IotDevice) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.productName(device.product)).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.deviceIdValue(device)).fontSize(11).fontColor($r('sys.color.font_tertiary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(2.2).alignItems(HorizontalAlign.Start)
      Text(this.deviceTypeName(device)).fontSize(13).fontColor($r('sys.color.font_primary'))
        .layoutWeight(1.3).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.deviceLocation(device)).fontSize(13).fontColor($r('sys.color.font_primary'))
        .layoutWeight(1.6).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(device.bed !== undefined && device.bed.length > 0 ? device.bed + '床' : '—')
        .fontSize(13).fontColor($r('sys.color.font_primary')).layoutWeight(1)
      Row() {
        Text(this.deviceStatus(device))
          .fontSize(11).fontColor(this.statusTintFg(device))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(8)
          .backgroundColor(this.statusTintBg(device))
      }.layoutWeight(1)
      Text(this.relativeHeartbeat(device.last_seen)).fontSize(13).fontColor($r('sys.color.font_primary'))
        .layoutWeight(1.3).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 10 }) {
        Text('详情').fontSize(13).fontColor($r('sys.color.font_primary')).onClick(() => this.openDeviceDetail(device))
        Text('配置').fontSize(13).fontColor($r('sys.color.font_primary')).onClick(() => this.openEdit(device))
      }.layoutWeight(1.4)
    }.width('100%').height(76).alignItems(VerticalAlign.Center)
  }

  @Builder
  private deviceTable() {
    Column({ space: 0 }) {
      this.tableHeader()
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      if (this.filteredDevices().length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.beacon_tower_fill')).fontSize(32).fontColor([$r('sys.color.icon_secondary')])
          Text(this.searchQuery.length > 0 || this.typeFilter !== '全部' ? '没有符合条件的设备' : '暂无设备')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text('毫米波设备可通过 MQTT 自动发现，摄像头可手动添加。')
            .fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.width('100%').padding({ top: 36, bottom: 36 }).alignItems(HorizontalAlign.Center)
      } else {
        ForEach(this.filteredDevices(), (device: IotDevice, index: number) => {
          Column() {
            this.tableRow(device)
            if (index < this.filteredDevices().length - 1) {
              Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
            }
          }.width('100%')
        }, (device: IotDevice) => 'device-row-' + String(device.id) + '-' + String(device.online) + '-' + (device.last_seen ?? ''))
      }
    }.width('100%').padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
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
        Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => { this.showCreate = false; this.resetEditor(); }); Button('保存').layoutWeight(1).height(40).borderRadius(8).fontColor(Color.White).backgroundColor(DARK_BUTTON_BG).onClick(() => this.saveDevice()) }.width('100%')
      }.width(this.compactWidth ? '90%' : 440).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) { Column({ space: 16 }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('设备管理').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('添加毫米波设备或摄像头，并绑定到房间').fontSize(11).fontColor($r('sys.color.font_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Search({ value: this.searchQuery, placeholder: '搜索设备编号/名称' })
            .width(this.compactWidth ? '100%' : 260).height(38)
            .onChange((value: string) => this.searchQuery = value)
          Button('新增设备').height(38).fontSize(13).borderRadius(8)
            .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
            .onClick(() => { this.resetEditor(); this.showCreate = true; })
        }.width('100%').alignItems(VerticalAlign.Center)
        this.typeChipsRow()
        if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
        this.statCards()
        this.deviceTable()
      }.width('100%').constraintSize({ minHeight: '100%' }).padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }) }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
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
