import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import ApiClient from '../../network/ApiClient';
import { Area as AreaDto, Bed, Room } from '../../network/Dto';
import { BusinessStore } from '../../network/BusinessStore';
import { PreferenceManager } from '../../util/PreferenceManager';
import { GlobalInfoModel } from '../../model/GlobalInfoModel';
import { StorageKey } from '../../common/CommonConstants';

interface AreaPage { list: AreaDto[]; }
interface AreaSaveRequest {
  parent_id?: number;
  type: string;
  code: string;
  name: string;
  building: string;
  floor_no: number;
  status: string;
  sort_order?: number;
  description?: string;
  pos_x: number;
  pos_y: number;
  size_w: number;
  size_h: number;
}
interface BedCreateRequest { room_id?: number; area_id?: number; bed_no: string; status: string; }

/** “在平面图上新增”行里的一个区域类型按钮。 */
interface AreaKind {
  value: string;
  label: string;
  builtin: boolean;
}

interface AreaKindsPref {
  hidden: string[];
  extra: string[];
}

const AREA_KINDS_PREF_KEY = 'kanxiaoban_area_custom_kinds';

const GRID_COLS: number = 26;
const GRID_ROWS: number = 10;
const ACTION_BUTTON_BG: string = '#1F1F1F';

@ComponentV2
export struct WideAreaManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local areas: AreaDto[] = [];
  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local globalInfo: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ?? new GlobalInfoModel();
  @Local toolbarHeight: number = 0;
  @Local dragAreaId: number = 0;
  @Local selectedFloorId: number = 0;
  @Local selectedAreaId: number = 0;
  @Local placingId: number = 0;
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local showFloorDialog: boolean = false;
  @Local showItemDialog: boolean = false;
  @Local showSizeDialog: boolean = false;
  @Local floorEditMode: boolean = false;
  @Local kindEditMode: boolean = false;
  @Local itemEditMode: boolean = false;
  @Local itemEditId: number = 0;
  @Local customKinds: string[] = [];
  @Local hiddenBuiltinKinds: string[] = [];
  @Local showKindDialog: boolean = false;
  @Local kindDialogName: string = '';
  @Local dialogKind: string = 'room';
  @Local dialogName: string = '';
  @Local dialogCode: string = '';
  @Local dialogBuilding: string = '';
  @Local dialogFloorNo: string = '';
  @Local dialogWidth: string = '3';
  @Local dialogHeight: string = '2';
  private planContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private planWidth: number = 0;
  private cellSize: number = 0;
  private dragOffsetCol: number = 0;
  private dragOffsetRow: number = 0;
  private dragMoved: boolean = false;

  aboutToAppear(): void { this.loadCustomKinds(); this.load(); this.businessStore.load(); }

  /** 切换楼层后清空旧楼层的选中/放置状态并重绘平面图。 */
  @Monitor('selectedFloorId')
  onSelectedFloorChange(): void {
    this.selectedAreaId = 0;
    this.placingId = 0;
    this.drawPlan();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const response = await ApiClient.get<AreaPage>('/areas');
      if (response.code !== 0 || response.data === undefined) { throw new Error(response.msg); }
      this.areas = response.data.list ?? [];
      this.clampLegacyPlacements();
      if (!this.areas.some((area: AreaDto) => area.id === this.selectedFloorId)) {
        this.selectedFloorId = this.floors().length > 0 ? this.floors()[0].id : 0;
      }
      if (this.selectedAreaId > 0 && !this.areas.some((area: AreaDto) => area.id === this.selectedAreaId)) {
        this.selectedAreaId = 0;
      }
      this.drawPlan();
    } catch (_error) { this.error = '区域数据加载失败'; }
    this.loading = false;
  }

  /** 历史数据按旧网格放置时超出当前网格的部分收进网格并回存。 */
  private clampLegacyPlacements(): void {
    const legacy: AreaDto[] = this.placedAreas().filter((area: AreaDto) => {
      return (area.pos_x ?? 0) + (area.size_w ?? 0) > GRID_COLS || (area.pos_y ?? 0) + (area.size_h ?? 0) > GRID_ROWS;
    });
    legacy.forEach((area: AreaDto) => {
      area.size_w = Math.min(Math.max(1, area.size_w ?? 1), GRID_COLS - 1);
      area.size_h = Math.min(Math.max(1, area.size_h ?? 1), GRID_ROWS - 1);
      area.pos_x = Math.max(1, Math.min(area.pos_x ?? 1, GRID_COLS - 1 - area.size_w));
      area.pos_y = Math.max(1, Math.min(area.pos_y ?? 1, GRID_ROWS - 1 - area.size_h));
      this.saveArea(area);
    });
  }

  private floors(): AreaDto[] {
    return this.areas.filter((area: AreaDto) => area.type === 'floor');
  }

  private selectedFloor(): AreaDto | undefined {
    return this.areas.find((area: AreaDto) => area.id === this.selectedFloorId && area.type === 'floor');
  }

  private selectedFloorAreas(): AreaDto[] {
    const floor: AreaDto | undefined = this.selectedFloor();
    if (floor === undefined) { return []; }
    return this.areas.filter((area: AreaDto) => area.type !== 'floor' && area.id !== floor.id &&
      (area.parent_id === floor.id ||
        ((area.parent_id ?? 0) === 0 && area.building === floor.building && (area.floor_no ?? 0) === floor.floor_no)));
  }

  private placedAreas(): AreaDto[] {
    return this.selectedFloorAreas().filter((area: AreaDto) => (area.size_w ?? 0) > 0 && (area.pos_x ?? 0) > 0);
  }

  private unplacedAreas(): AreaDto[] {
    return this.selectedFloorAreas().filter((area: AreaDto) => !((area.size_w ?? 0) > 0 && (area.pos_x ?? 0) > 0));
  }

  private selectedArea(): AreaDto | undefined {
    return this.areas.find((area: AreaDto) => area.id === this.selectedAreaId);
  }

  private bedCountOfSelected(): number {
    const area: AreaDto | undefined = this.selectedArea();
    return area === undefined ? 0 : this.bedCount(area);
  }

  private typeLabel(value: string): string {
    switch (value) {
      case 'floor': return '楼层';
      case 'room': return '房间';
      case 'corridor': return '走廊';
      case 'stair': return '楼梯';
      case 'common': return '公共区';
      default: return value;
    }
  }

  private roomForArea(area: AreaDto): Room | undefined {
    return this.businessStore.rooms.find((room: Room) => area.type === 'room' && room.building === area.building &&
      room.floor === (area.floor_no ?? 0) && room.room_no === area.name);
  }

  private bedCount(area: AreaDto): number {
    return this.bedsOfArea(area).length;
  }

  /** 床位优先按 area_id 关联统计，兼容尚未回填 area_id 的历史床位。 */
  private bedsOfArea(area: AreaDto): Bed[] {
    const linked: Bed[] = this.businessStore.beds.filter((bed: Bed) => bed.area_id === area.id);
    if (linked.length > 0) {
      return linked;
    }
    const room: Room | undefined = this.roomForArea(area);
    return room === undefined ? [] : this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id);
  }

  private bedsOfSelected(): Bed[] {
    const area: AreaDto | undefined = this.selectedArea();
    return area === undefined ? [] : this.bedsOfArea(area);
  }

  /** 把选中房间设置为 target 张床：不足则补建，超出则删除空闲床位。 */
  private async setBedCount(target: number): Promise<void> {
    const area: AreaDto | undefined = this.selectedArea();
    if (area === undefined || area.type !== 'room') { return; }
    const beds: Bed[] = this.bedsOfArea(area);
    const current: number = beds.length;
    if (current === target) { return; }
    if (current < target) {
      const used: string[] = beds.map((bed: Bed) => bed.bed_no);
      let created = 0;
      for (const no of ['1', '2']) {
        if (created >= target - current) { break; }
        if (used.indexOf(no) >= 0) { continue; }
        const room: Room | undefined = this.roomForArea(area);
        const request: BedCreateRequest = {
          area_id: area.id, bed_no: no, status: 'free',
          room_id: room === undefined ? undefined : room.id
        };
        try {
          const response = await ApiClient.post<Object>('/beds', request);
          if (response.code !== 0) { this.error = response.msg || '床位创建失败'; return; }
          created++;
        } catch (_error) { this.error = '床位创建失败，请稍后重试'; return; }
      }
      if (created < target - current) { this.error = '床位创建失败'; return; }
    } else {
      const need: number = current - target;
      // 优先删空闲床；不足时允许删占用床，后端会先解除长者绑定。
      const removable: Bed[] = beds.slice()
        .sort((left: Bed, right: Bed) => {
          const leftFree: number = left.status === 'free' && left.elder_id === undefined ? 0 : 1;
          const rightFree: number = right.status === 'free' && right.elder_id === undefined ? 0 : 1;
          if (leftFree !== rightFree) { return leftFree - rightFree; }
          return right.bed_no.localeCompare(left.bed_no);
        });
      for (let i = 0; i < need; i++) {
        try {
          const response = await ApiClient.delete<Object>(`/beds/${removable[i].id}`);
          if (response.code !== 0) { this.error = response.msg || '床位删除失败'; return; }
        } catch (_error) { this.error = '床位删除失败，请稍后重试'; return; }
      }
    }
    this.error = '';
    await this.businessStore.load(true);
    this.drawPlan();
  }

  private async saveArea(area: AreaDto): Promise<boolean> {
    const request: AreaSaveRequest = {
      parent_id: area.parent_id, type: area.type, code: area.code, name: area.name,
      building: area.building ?? '', floor_no: area.floor_no ?? 0, status: area.status,
      sort_order: area.sort_order ?? 0, description: area.description,
      pos_x: Math.max(0, area.pos_x ?? 0), pos_y: Math.max(0, area.pos_y ?? 0),
      size_w: Math.max(0, area.size_w ?? 0), size_h: Math.max(0, area.size_h ?? 0)
    };
    try {
      const response = await ApiClient.put<AreaDto>(`/areas/${area.id}`, request);
      if (response.code !== 0 || response.data === undefined) { this.error = response.msg || '区域保存失败'; return false; }
      const saved: AreaDto = response.data;
      this.areas = this.areas.map((item: AreaDto) => item.id === saved.id ? saved : item);
      this.drawPlan();
      return true;
    } catch (_error) { this.error = '区域保存失败，请稍后重试'; return false; }
  }

  private async deleteArea(area: AreaDto): Promise<void> {
    try {
      const response = await ApiClient.delete<Object>(`/areas/${area.id}`);
      if (response.code !== 0) { this.error = response.msg || '区域删除失败'; return; }
      this.selectedAreaId = 0;
      await this.load();
    } catch (_error) { this.error = '区域删除失败'; }
  }

  private async createFloor(): Promise<void> {
    if (this.dialogName.trim() === '' || this.dialogCode.trim() === '') { this.error = '楼层名称和编码不能为空'; return; }
    const request: AreaSaveRequest = {
      type: 'floor', code: this.dialogCode.trim(), name: this.dialogName.trim(),
      building: this.dialogBuilding.trim(), floor_no: Number(this.dialogFloorNo) || 0,
      status: 'active', pos_x: 0, pos_y: 0, size_w: 0, size_h: 0
    };
    try {
      const response = await ApiClient.post<AreaDto>('/areas', request);
      if (response.code !== 0 || response.data === undefined) { this.error = response.msg || '楼层创建失败'; return; }
      this.showFloorDialog = false;
      this.selectedFloorId = response.data.id;
      await this.load();
    } catch (_error) { this.error = '楼层创建失败'; }
  }

  private openFloorEdit(floor: AreaDto): void {
    this.floorEditMode = true;
    this.dialogName = floor.name;
    this.dialogCode = floor.code;
    this.dialogBuilding = floor.building ?? '';
    this.dialogFloorNo = String(floor.floor_no ?? 0);
    this.showFloorDialog = true;
  }

  private async updateFloor(): Promise<void> {
    const floor: AreaDto | undefined = this.selectedFloor();
    if (floor === undefined) { this.showFloorDialog = false; return; }
    if (this.dialogName.trim() === '' || this.dialogCode.trim() === '') { this.error = '楼层名称和编码不能为空'; return; }
    floor.name = this.dialogName.trim();
    floor.code = this.dialogCode.trim();
    floor.building = this.dialogBuilding.trim();
    floor.floor_no = Number(this.dialogFloorNo) || 0;
    const ok: boolean = await this.saveArea(floor);
    if (ok) { this.showFloorDialog = false; }
  }

  private async createPlacingItem(placeAfter: boolean): Promise<void> {
    const floor: AreaDto | undefined = this.selectedFloor();
    if (floor === undefined) { this.error = '请先选择楼层'; return; }
    const width: number = Math.max(1, Number(this.dialogWidth) || 1);
    const height: number = Math.max(1, Number(this.dialogHeight) || 1);
    if (this.dialogName.trim() === '' || this.dialogCode.trim() === '') { this.error = '名称和编码不能为空'; return; }
    const request: AreaSaveRequest = {
      parent_id: floor.id, type: this.dialogKind, code: this.dialogCode.trim(), name: this.dialogName.trim(),
      building: floor.building ?? '', floor_no: floor.floor_no ?? 0, status: 'active',
      pos_x: 0, pos_y: 0, size_w: Math.min(width, GRID_COLS - 1), size_h: Math.min(height, GRID_ROWS - 1)
    };
    try {
      const response = await ApiClient.post<AreaDto>('/areas', request);
      if (response.code !== 0 || response.data === undefined) { this.error = response.msg || '创建失败'; return; }
      this.showItemDialog = false;
      this.placingId = placeAfter ? response.data.id : 0;
      this.selectedAreaId = response.data.id;
      await this.load();
      this.error = '';
    } catch (_error) { this.error = '创建失败，请稍后重试'; }
  }

  /** 打开区域编辑对话框：平面图选中项与未布置项共用。 */
  private openItemEdit(area: AreaDto): void {
    this.itemEditMode = true;
    this.itemEditId = area.id;
    this.dialogKind = area.type;
    this.dialogName = area.name;
    this.dialogCode = area.code;
    this.dialogWidth = String(this.effectiveWidth(area));
    this.dialogHeight = String(this.effectiveHeight(area));
    this.showItemDialog = true;
  }

  /** 保存区域编辑：名称、编码、尺寸；已布置项超出网格时回夹位置。 */
  private async updateItem(): Promise<void> {
    const area: AreaDto | undefined = this.areas.find((item: AreaDto) => item.id === this.itemEditId);
    if (area === undefined) { this.showItemDialog = false; return; }
    if (this.dialogName.trim() === '' || this.dialogCode.trim() === '') { this.error = '名称和编码不能为空'; return; }
    area.name = this.dialogName.trim();
    area.code = this.dialogCode.trim();
    area.size_w = Math.min(Math.max(1, Number(this.dialogWidth) || 1), GRID_COLS - 1);
    area.size_h = Math.min(Math.max(1, Number(this.dialogHeight) || 1), GRID_ROWS - 1);
    if ((area.pos_x ?? 0) > 0) {
      area.pos_x = Math.max(1, Math.min(area.pos_x ?? 0, GRID_COLS - area.size_w));
      area.pos_y = Math.max(1, Math.min(area.pos_y ?? 0, GRID_ROWS - area.size_h));
    }
    const ok: boolean = await this.saveArea(area);
    if (ok) { this.showItemDialog = false; }
  }

  private suggestCode(prefix: string): string {
    return `${prefix}-${Math.floor(Math.random() * 9000 + 1000)}`;
  }

  // ---- floor plan canvas ----

  private planHeight(): number {
    return this.planWidth > 0 ? (this.planWidth / GRID_COLS) * GRID_ROWS : 360;
  }

  /** 地图卡片高度：视口高度减去卡片顶部起点（页面上边距+工具栏）和页面底部留白，让卡片铺满屏幕剩余空间。 */
  private mapCardMinHeight(): number {
    const viewport: number = this.globalInfo.deviceHeight > 0 ? this.globalInfo.deviceHeight : 800;
    const toolbar: number = this.toolbarHeight > 0 ? this.toolbarHeight : 150;
    const cardTop: number = 88 + this.statusBarHeight + toolbar + 16;
    return Math.max(480, viewport - cardTop - 24 - this.naviIndicatorHeight);
  }

  private drawPlan(): void {
    const context = this.planContext;
    const width: number = this.planWidth;
    if (width <= 0) { return; }
    const cell: number = width / GRID_COLS;
    this.cellSize = cell;
    const height: number = context.height;
    context.clearRect(0, 0, width, height);
    context.fillStyle = '#FBFCFE';
    context.fillRect(0, 0, width, height);
    context.lineWidth = 1;
    for (let col: number = 0; col <= GRID_COLS; col++) {
      context.strokeStyle = col % 5 === 0 ? '#D9DEE7' : '#EBEEF3';
      context.beginPath();
      context.moveTo(Math.min(col * cell, width), 0);
      context.lineTo(Math.min(col * cell, width), height);
      context.stroke();
    }
    for (let y: number = 0; y <= height; y += cell) {
      context.strokeStyle = Math.round(y / cell) % 5 === 0 ? '#D9DEE7' : '#EBEEF3';
      context.beginPath();
      context.moveTo(0, y);
      context.lineTo(width, y);
      context.stroke();
    }
    context.strokeStyle = '#D9DEE7';
    context.beginPath();
    context.moveTo(0, height);
    context.lineTo(width, height);
    context.stroke();
    const placed: AreaDto[] = this.placedAreas().slice().sort((left: AreaDto, right: AreaDto) => {
      return (left.type === 'corridor' ? 0 : 1) - (right.type === 'corridor' ? 0 : 1);
    });
    placed.forEach((area: AreaDto) => {
      this.drawAreaRect(area, cell, area.id === this.selectedAreaId);
    });
    if (this.placingId > 0) {
      context.strokeStyle = '#317AF7';
      context.setLineDash([8, 6]);
      context.lineWidth = 2;
      context.strokeRect(3, 3, width - 6, height - 6);
      context.setLineDash([]);
    }
  }

  private drawAreaRect(area: AreaDto, cell: number, selected: boolean): void {
    const context = this.planContext;
    const x: number = (area.pos_x ?? 0) * cell;
    const y: number = (area.pos_y ?? 0) * cell;
    const w: number = (area.size_w ?? 0) * cell;
    const h: number = (area.size_h ?? 0) * cell;
    let fill = '#EDE7F6';
    let border = '#9575CD';
    if (area.type === 'room') { fill = '#DCE9FB'; border = '#4A7AD9'; }
    else if (area.type === 'corridor') { fill = '#ECEFF3'; border = '#A9B2BF'; }
    else if (area.type === 'stair') { fill = '#F5ECDD'; border = '#C9A96A'; }
    else if (area.type === 'common') { fill = '#E3F0E5'; border = '#6FA97A'; }
    context.fillStyle = fill;
    context.fillRect(x + 1.5, y + 1.5, w - 3, h - 3);
    context.strokeStyle = selected ? '#317AF7' : border;
    context.lineWidth = selected ? 2.5 : 1.5;
    context.strokeRect(x + 1.5, y + 1.5, w - 3, h - 3);
    context.fillStyle = '#1F2329';
    const fontSize: number = Math.max(16, Math.min(24, Math.round(cell * 0.45)));
    context.font = `600 ${fontSize}px sans-serif`;
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    let label: string = area.name;
    if (area.type === 'room') {
      label = `${area.name} ${this.bedCount(area)}床`;
    }
    if (w > fontSize * 1.8) {
      context.fillText(label, x + w / 2, y + h / 2, Math.max(10, w - 8));
    }
    if (selected) {
      context.fillStyle = '#317AF7';
      const handle: number = 6;
      [[x, y], [x + w - handle, y], [x, y + h - handle], [x + w - handle, y + h - handle]].forEach((point: number[]) => {
        context.fillRect(point[0], point[1], handle, handle);
      });
    }
  }

  private handleTouch(event: TouchEvent): void {
    if (this.cellSize <= 0) { return; }
    const touch: TouchObject | undefined = event.touches.length > 0 ? event.touches[0] : event.changedTouches[0];
    if (touch === undefined) { return; }
    const col: number = Math.floor(touch.x / this.cellSize);
    const row: number = Math.floor(touch.y / this.cellSize);
    if (event.type === TouchType.Down) {
      this.onPlanDown(col, row);
    } else if (event.type === TouchType.Move) {
      this.onPlanMove(col, row);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.onPlanUp();
    }
  }

  private effectiveWidth(area: AreaDto): number {
    const sw: number = area.size_w ?? 0;
    return sw > 0 ? Math.min(sw, GRID_COLS - 1) : (area.type === 'corridor' ? 6 : 3);
  }

  private effectiveHeight(area: AreaDto): number {
    const sh: number = area.size_h ?? 0;
    return sh > 0 ? Math.min(sh, GRID_ROWS - 1) : (area.type === 'corridor' ? 1 : 2);
  }

  private onPlanDown(col: number, row: number): void {
    if (this.placingId > 0) {
      const area = this.areas.find((item: AreaDto) => item.id === this.placingId);
      if (area === undefined) { this.placingId = 0; return; }
      const w: number = this.effectiveWidth(area);
      const h: number = this.effectiveHeight(area);
      area.size_w = w;
      area.size_h = h;
      area.pos_x = Math.max(1, Math.min(col, GRID_COLS - 1 - w));
      area.pos_y = Math.max(1, Math.min(row, GRID_ROWS - 1 - h));
      this.saveArea(area);
      this.placingId = 0;
      return;
    }
    const hit = this.placedAreas().reverse().find((area: AreaDto) => {
      return col >= (area.pos_x ?? 0) && col < (area.pos_x ?? 0) + (area.size_w ?? 0) &&
        row >= (area.pos_y ?? 0) && row < (area.pos_y ?? 0) + (area.size_h ?? 0);
    });
    if (hit !== undefined) {
      this.selectedAreaId = hit.id;
      this.dragAreaId = hit.id;
      this.dragOffsetCol = col - (hit.pos_x ?? 0);
      this.dragOffsetRow = row - (hit.pos_y ?? 0);
      this.dragMoved = false;
    } else {
      this.selectedAreaId = 0;
    }
    this.drawPlan();
  }

  private onPlanMove(col: number, row: number): void {
    if (this.dragAreaId === 0) { return; }
    const area = this.areas.find((item: AreaDto) => item.id === this.dragAreaId);
    if (area === undefined) { return; }
    const w: number = area.size_w ?? 1;
    const h: number = area.size_h ?? 1;
    const nextX: number = Math.max(1, Math.min(col - this.dragOffsetCol, GRID_COLS - 1 - w));
    const nextY: number = Math.max(1, Math.min(row - this.dragOffsetRow, GRID_ROWS - 1 - h));
    if (nextX !== area.pos_x || nextY !== area.pos_y) {
      area.pos_x = nextX;
      area.pos_y = nextY;
      this.dragMoved = true;
      this.drawPlan();
    }
  }

  private onPlanUp(): void {
    if (this.dragAreaId === 0) { return; }
    const area = this.areas.find((item: AreaDto) => item.id === this.dragAreaId);
    this.dragAreaId = 0;
    if (area === undefined || !this.dragMoved) { return; }
    this.saveArea(area);
  }

  // ---- UI builders ----

  @Builder
  private floorChip(floor: AreaDto) {
    Row({ space: 4 }) {
      Text(floor.name)
        .fontSize(12)
        .fontColor(floor.id === this.selectedFloorId ? Color.White : $r('sys.color.font_primary'))
      if (this.floorEditMode) {
        Text('✕').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_danger'))
          .onClick(() => this.deleteArea(floor))
      }
    }
      .padding({ left: 16, right: this.floorEditMode ? 10 : 16 })
      .height(34)
      .borderRadius(8)
      .backgroundColor(floor.id === this.selectedFloorId ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
      .onClick(() => {
        this.selectedFloorId = floor.id;
        if (this.floorEditMode) { this.openFloorEdit(floor); }
      })
  }

  @Builder
  private floorToolbarCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text('楼层').fontSize(13).fontColor($r('sys.color.font_secondary'))
        Scroll() {
          Row({ space: 8 }) {
            Repeat(this.floors())
              .each((ri: RepeatItem<AreaDto>) => {
                this.floorChip(ri.item)
              })
              .key((floor: AreaDto) => `floor-${floor.id}`)
          }
        }.layoutWeight(1).align(Alignment.Start).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        if (this.floorEditMode) {
          Button() {
            Row({ space: 4 }) {
              Text('编辑楼层').fontSize(12).fontColor(Color.White)
              Text('✕').fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
            }.padding({ left: 12, right: 12 })
          }.height(34).borderRadius(8)
            .backgroundColor($r('app.color.doctor_workspace_danger'))
            .onClick(() => { this.floorEditMode = false; })
        } else {
          Button('编辑楼层').height(34).fontSize(12).borderRadius(8)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .enabled(this.selectedFloorId > 0)
            .opacity(this.selectedFloorId > 0 ? 1 : 0.4)
            .onClick(() => { this.floorEditMode = true; this.kindEditMode = false; })
        }
        Button('新增楼层').height(34).fontSize(12).borderRadius(8)
          .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => {
            this.floorEditMode = false;
            this.kindEditMode = false;
            this.dialogName = '';
            this.dialogCode = this.suggestCode('floor');
            this.dialogBuilding = '';
            this.dialogFloorNo = String(this.floors().length + 1);
            this.showFloorDialog = true;
          })
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 10 }) {
        Text('在平面图上新增：').fontSize(13).fontColor($r('sys.color.font_secondary'))
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          Repeat(this.areaKinds())
            .each((ri: RepeatItem<AreaKind>) => {
              Row({ space: 6 }) {
                Text(ri.item.label).fontSize(12).fontColor(Color.White)
                  .onClick(() => this.openItemDialog(ri.item.value))
                if (this.kindEditMode) {
                  Text('✕').fontSize(11).fontWeight(FontWeight.Medium).fontColor(Color.White)
                    .width(18).height(18).textAlign(TextAlign.Center)
                    .borderRadius(9).backgroundColor($r('app.color.doctor_workspace_danger'))
                    .onClick(() => this.removeKind(ri.item))
                }
              }
                .padding({ left: 12, right: this.kindEditMode ? 6 : 12 })
                .height(34).borderRadius(8)
                .backgroundColor($r('app.color.brand_blue'))
            })
            .key((kind: AreaKind) => `kind-${kind.value}`)
        }.layoutWeight(1)
        if (this.kindEditMode) {
          Button() {
            Row({ space: 4 }) {
              Text('编辑区域').fontSize(12).fontColor(Color.White)
              Text('✕').fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
            }.padding({ left: 12, right: 12 })
          }.height(34).borderRadius(8)
            .backgroundColor($r('app.color.doctor_workspace_danger'))
            .onClick(() => { this.kindEditMode = false; })
        } else {
          Button('编辑区域').height(34).fontSize(12).borderRadius(8)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => {
              this.kindEditMode = true;
              this.floorEditMode = false;
            })
        }
        Button('新增区域').height(34).fontSize(12).borderRadius(8)
          .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.kindDialogName = ''; this.showKindDialog = true; })
      }.width('100%').alignItems(VerticalAlign.Center)
      if (this.unplacedAreas().length > 0) {
        Column({ space: 8 }) {
          Text('未布置（点击标签放到平面图上）').fontSize(13).fontColor($r('sys.color.font_secondary'))
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            Repeat(this.unplacedAreas())
              .each((ri: RepeatItem<AreaDto>) => {
                Text(`${this.typeLabel(ri.item.type)} · ${ri.item.name}`)
                  .fontSize(13)
                  .fontColor(this.placingId === ri.item.id ? Color.White : $r('sys.color.font_primary'))
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .borderRadius(6)
                  .backgroundColor(this.placingId === ri.item.id ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
                  .onClick(() => { this.placingId = ri.item.id; })
              })
              .key((area: AreaDto) => `unplaced-${area.id}`)
          }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
    }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.toolbarHeight = Number(newArea.height);
      })
  }

  /** “在平面图上新增”行的类型按钮：内置四类 + 自定义类型，内置类型可被隐藏。 */
  private builtinAreaKinds(): AreaKind[] {
    return [
      { value: 'room', label: '房间', builtin: true },
      { value: 'corridor', label: '走廊', builtin: true },
      { value: 'stair', label: '楼梯', builtin: true },
      { value: 'common', label: '公共区', builtin: true }
    ];
  }

  private areaKinds(): AreaKind[] {
    const visibleBuiltins: AreaKind[] = this.builtinAreaKinds().filter((kind: AreaKind) => {
      return !this.hiddenBuiltinKinds.includes(kind.value);
    });
    const extras: AreaKind[] = this.customKinds.map((label: string): AreaKind => {
      return { value: label, label: label, builtin: false };
    });
    return visibleBuiltins.concat(extras);
  }

  private loadCustomKinds(): void {
    const stored: AreaKindsPref | null = PreferenceManager.getInstance().getValue<AreaKindsPref>(AREA_KINDS_PREF_KEY);
    this.customKinds = stored?.extra ?? [];
    this.hiddenBuiltinKinds = stored?.hidden ?? [];
  }

  private persistCustomKinds(): void {
    const pref: AreaKindsPref = { hidden: this.hiddenBuiltinKinds, extra: this.customKinds };
    PreferenceManager.getInstance().setValue<AreaKindsPref>(AREA_KINDS_PREF_KEY, pref);
  }

  /** 新增区域类型：与内置同名的恢复内置按钮，其余作为自定义类型追加。 */
  private saveKind(): void {
    const name: string = this.kindDialogName.trim();
    if (name === '') { this.error = '请输入区域名称'; return; }
    if (name === '楼层') { this.error = '该名称已被楼层使用'; return; }
    const builtinByLabel: AreaKind[] = this.builtinAreaKinds().filter((kind: AreaKind) => kind.label === name);
    if (builtinByLabel.length > 0) {
      this.hiddenBuiltinKinds = this.hiddenBuiltinKinds.filter((value: string) => value !== builtinByLabel[0].value);
      this.customKinds = this.customKinds.filter((label: string) => label !== name);
    } else {
      if (this.areaKinds().some((kind: AreaKind) => kind.label === name)) { this.error = '该区域类型已存在'; return; }
      this.customKinds = this.customKinds.concat([name]);
    }
    this.persistCustomKinds();
    this.showKindDialog = false;
    this.kindDialogName = '';
    this.error = '';
  }

  /** 移除类型按钮：内置类型仅从按钮行隐藏，已布置的区域记录不受影响。 */
  private removeKind(kind: AreaKind): void {
    if (kind.builtin) {
      this.hiddenBuiltinKinds = this.hiddenBuiltinKinds.concat([kind.value]);
    } else {
      this.customKinds = this.customKinds.filter((label: string) => label !== kind.value);
    }
    this.persistCustomKinds();
  }

  private openItemDialog(kind: string): void {
    if (this.selectedFloorId === 0) { this.error = '请先选择或新增楼层'; return; }
    this.itemEditMode = false;
    this.itemEditId = 0;
    this.dialogKind = kind;
    this.dialogName = '';
    this.dialogCode = this.suggestCode(kind);
    this.dialogWidth = kind === 'corridor' ? '6' : '3';
    this.dialogHeight = kind === 'corridor' ? '1' : '2';
    this.showItemDialog = true;
  }

  @Builder
  private mapCard() {
    Column({ space: 10 }) {
      Row() {
        Text(this.selectedFloor()?.name ?? '楼层平面图').fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        if (this.placingId > 0) {
          Text('点击地图放置，放置后可拖动').fontSize(12).fontColor($r('app.color.brand_blue'))
        } else if (this.kindEditMode) {
          Text('编辑中：点类型按钮的✕移除该类型').fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
        } else {
          Text('点选房间后可拖动改位').fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }
      }.width('100%')
      Stack() {
        Canvas(this.planContext)
          .width('100%').height('100%')
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.planWidth = Number(newArea.width);
            this.drawPlan();
          })
          .onReady(() => this.drawPlan())
          .onTouch((event: TouchEvent) => this.handleTouch(event))
        if (this.selectedFloorId === 0 && !this.loading) {
          Column({ space: 8 }) {
            Text('暂无楼层').fontSize(14).fontColor($r('sys.color.font_tertiary'))
            Text('请先在上方新增楼层').fontSize(12).fontColor($r('sys.color.font_tertiary'))
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
            .backgroundColor('#FBFCFE')
        }
      }.width('100%').layoutWeight(1)
      Row({ space: 14 }) {
        this.legendSwatch('#DCE9FB', '#4A7AD9', '房间')
        this.legendSwatch('#ECEFF3', '#A9B2BF', '走廊')
        this.legendSwatch('#F5ECDD', '#C9A96A', '楼梯')
        this.legendSwatch('#E3F0E5', '#6FA97A', '公共区')
      }.width('100%')
    }.width('100%').height(this.mapCardMinHeight()).padding(16).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private legendSwatch(fill: string, border: string, label: string) {
    Row({ space: 6 }) {
      Row().width(12).height(12).backgroundColor(fill).borderRadius(3)
        .border({ width: 1, color: border })
      Text(label).fontSize(12).fontColor($r('sys.color.font_secondary'))
    }
  }

  @Builder
  private selectedPanelCard() {
    Column({ space: 10 }) {
      if (this.error.length > 0) {
        Text(this.error).fontSize(13).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 8 }) {
        Text('已选中').fontSize(13).fontColor($r('sys.color.font_secondary'))
        Text(`${this.typeLabel(this.selectedArea()?.type ?? '')} · ${this.selectedArea()?.name ?? ''}`)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Blank()
        Text('取消选择').fontSize(12).fontColor($r('app.color.brand_blue'))
          .onClick(() => { this.selectedAreaId = 0; this.drawPlan(); })
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 10 }) {
        Text(`编码 ${this.selectedArea()?.code ?? '--'}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        if (this.selectedArea()?.type === 'room') {
          Text(`床位 ${this.bedCountOfSelected()}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        }
        Text(`尺寸 ${this.selectedArea()?.size_w ?? 0}×${this.selectedArea()?.size_h ?? 0} 格`).fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }.width('100%')
      Row({ space: 10 }) {
        Button('编辑').height(34).fontSize(12).borderRadius(8)
          .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => {
            const area = this.selectedArea();
            if (area !== undefined) { this.openItemEdit(area); }
          })
        Button('调整尺寸').height(34).fontSize(12).borderRadius(8)
          .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => {
            this.dialogWidth = String(this.selectedArea()?.size_w ?? 3);
            this.dialogHeight = String(this.selectedArea()?.size_h ?? 2);
            this.showSizeDialog = true;
          })
        Button('删除').height(34).fontSize(12).borderRadius(8)
          .fontColor(Color.White).backgroundColor($r('app.color.doctor_workspace_danger'))
          .onClick(() => {
            const area = this.selectedArea();
            if (area !== undefined) { this.deleteArea(area); }
          })
      }.width('100%')
      if (this.selectedArea()?.type === 'room') {
        Row({ space: 8 }) {
          Text('床位设置').fontSize(13).fontColor($r('sys.color.font_secondary'))
          Button('1 床').height(34).fontSize(12).borderRadius(8)
            .fontColor(this.bedCountOfSelected() === 1 ? Color.White : $r('sys.color.font_primary'))
            .backgroundColor(this.bedCountOfSelected() === 1 ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
            .onClick(() => this.setBedCount(1))
          Button('2 床').height(34).fontSize(12).borderRadius(8)
            .fontColor(this.bedCountOfSelected() === 2 ? Color.White : $r('sys.color.font_primary'))
            .backgroundColor(this.bedCountOfSelected() === 2 ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
            .onClick(() => this.setBedCount(2))
          Text(`当前 ${this.bedCountOfSelected()} 张`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }.width('100%').alignItems(VerticalAlign.Center)
      }
    }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private numberField(label: string, value: string, onChange: (text: string) => void) {
    Row({ space: 8 }) {
      Text(label).fontSize(13).fontColor($r('sys.color.font_secondary'))
      TextInput({ text: value }).width(72).height(38).fontSize(13).borderRadius(6).type(InputType.Number)
        .onChange((text: string) => onChange(text))
    }.alignItems(VerticalAlign.Center)
  }

  @Builder
  private kindDialog() {
    Column({ space: 12 }) {
      Text('新增区域').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '区域名称，例如 电梯', text: $$this.kindDialogName }).height(42)
        .onSubmit(() => this.saveKind())
      Text('保存后会出现在上方的类型按钮行，可在平面图上放置该类型区域')
        .fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showKindDialog = false)
        Button('保存').layoutWeight(1).height(40)
          .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
          .onClick(() => this.saveKind())
      }.width('100%')
    }.width(this.compactWidth ? '90%' : 400).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  @Builder
  private floorDialog() {
    Column({ space: 12 }) {
      Text(this.floorEditMode ? '编辑楼层' : '新增楼层').fontSize(20).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '楼层名称，例如 1 号楼 3 层', text: $$this.dialogName }).height(42)
      TextInput({ placeholder: '楼栋，例如 1 号楼', text: $$this.dialogBuilding }).height(42)
      TextInput({ placeholder: '楼层号，例如 3', text: $$this.dialogFloorNo }).height(42).type(InputType.Number)
      TextInput({ placeholder: '楼层编码', text: $$this.dialogCode }).height(42)
      if (this.floorEditMode) {
        Text('删除楼层前需先删除楼层内的房间、走廊等区域').fontSize(12).fontColor($r('sys.color.font_tertiary'))
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showFloorDialog = false)
        Button('保存').layoutWeight(1).height(40)
          .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
          .onClick(() => this.floorEditMode ? this.updateFloor() : this.createFloor())
      }.width('100%')
      if (this.floorEditMode) {
        Button('删除楼层').width('100%').height(40)
          .fontColor(Color.White).backgroundColor($r('app.color.doctor_workspace_danger'))
          .onClick(() => {
            const floor: AreaDto | undefined = this.selectedFloor();
            this.showFloorDialog = false;
            if (floor !== undefined) { this.deleteArea(floor); }
          })
      }
    }.width(this.compactWidth ? '90%' : 440).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  @Builder
  private itemDialog() {
    Column({ space: 12 }) {
      Text(this.itemEditMode ? `编辑${this.typeLabel(this.dialogKind)}` :
        this.typeLabel(this.dialogKind) === '房间' ? '新增房间' :
        this.typeLabel(this.dialogKind) === '走廊' ? '新增走廊' : `新增${this.typeLabel(this.dialogKind)}`)
        .fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '名称，例如 103', text: $$this.dialogName }).height(42)
      TextInput({ placeholder: '编码', text: $$this.dialogCode }).height(42)
      Row({ space: 14 }) {
        this.numberField('宽（格）', this.dialogWidth, (text: string) => this.dialogWidth = text)
        this.numberField('高（格）', this.dialogHeight, (text: string) => this.dialogHeight = text)
      }.width('100%')
      if (this.itemEditMode) {
        Text('未布置的区域保存后仍停留在未布置区，点击标签即可放置').fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      } else {
        Text('可立即放置到平面图，或先保存到未布置区稍后再放').fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      if (this.itemEditMode) {
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(40)
            .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.showItemDialog = false)
          Button('保存').layoutWeight(1).height(40)
            .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
            .onClick(() => this.updateItem())
        }.width('100%')
      } else {
        Row({ space: 10 }) {
          Button('取消').height(40)
            .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.showItemDialog = false)
          Button('存到未布置').layoutWeight(1).height(40)
            .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.createPlacingItem(false))
          Button('保存并放置').layoutWeight(1).height(40)
            .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
            .onClick(() => this.createPlacingItem(true))
        }.width('100%')
      }
    }.width(this.compactWidth ? '90%' : 440).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  @Builder
  private sizeDialog() {
    Column({ space: 12 }) {
      Text('调整尺寸').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Row({ space: 14 }) {
        this.numberField('宽（格）', this.dialogWidth, (text: string) => this.dialogWidth = text)
        this.numberField('高（格）', this.dialogHeight, (text: string) => this.dialogHeight = text)
      }.width('100%')
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showSizeDialog = false)
        Button('保存').layoutWeight(1).height(40)
          .fontColor(Color.White).backgroundColor(ACTION_BUTTON_BG)
          .onClick(async () => {
            const area = this.selectedArea();
            if (area === undefined) { this.showSizeDialog = false; return; }
            area.size_w = Math.min(Math.max(1, Number(this.dialogWidth) || 1), GRID_COLS - 1);
            area.size_h = Math.min(Math.max(1, Number(this.dialogHeight) || 1), GRID_ROWS - 1);
            if ((area.pos_x ?? 0) > 0) {
              area.pos_x = Math.max(1, Math.min(area.pos_x ?? 0, GRID_COLS - area.size_w));
              area.pos_y = Math.max(1, Math.min(area.pos_y ?? 0, GRID_ROWS - area.size_h));
            }
            const ok: boolean = await this.saveArea(area);
            if (ok) { this.showSizeDialog = false; }
          })
      }.width('100%')
    }.width(this.compactWidth ? '90%' : 400).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          this.floorToolbarCard()
          if (this.error.length > 0) {
            Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          this.mapCard()
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
          top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        .scrollable(this.dragAreaId > 0 ? ScrollDirection.None : ScrollDirection.Vertical)
      if (this.selectedAreaId > 0 && this.selectedArea() !== undefined) {
        Column() { this.selectedPanelCard() }
          .constraintSize({ maxWidth: 640 })
          .width('100%')
          .margin({ left: 16, right: 16, bottom: 16 + this.naviIndicatorHeight })
          .shadow({ radius: 24, color: '#1A000000', offsetY: 4 })
      }
      if (this.showFloorDialog) {
        Row() { this.floorDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showKindDialog) {
        Row() { this.kindDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showItemDialog) {
        Row() { this.itemDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showSizeDialog) {
        Row() { this.sizeDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
