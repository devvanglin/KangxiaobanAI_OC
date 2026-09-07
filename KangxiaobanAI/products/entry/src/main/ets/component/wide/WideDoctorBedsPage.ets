import { HdsNavDestination, HdsNavDestinationTitleMode, HdsSnackBar, ScrollEffectType,
  SnackBarOperationType, TitleBarStyleOptions, hdsMaterial } from '@kit.UIDesignKit';
import { ApiClient } from '../../network/ApiClient';
import { BusinessStore } from '../../network/BusinessStore';
import { Area as OrgArea, Bed, Elder, Room, Schedule } from '../../network/Dto';
import { QuickEmptyHint } from './WideDoctorQuickPageKit';

interface AreaPage {
  list: OrgArea[];
}

interface BedTileData {
  key: string;
  bedNo: string;
  status: string;
  occupant: string;
}

interface BedDetailRow {
  key: string;
  bedNo: string;
  elderName: string;
  careLevel: string;
  admittedAt: string;
  caregiver: string;
  status: string;
}

interface StatCardData {
  label: string;
  value: string;
  note: string;
}

/** 医师端「床位管理」：区域/楼层筛选 + 统计卡 + 床位分布网格 + 床位详情表。 */
@ComponentV2
export struct WideDoctorBedsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  @Local areas: OrgArea[] = [];
  @Local areaFilterKey: string = 'all';
  @Local floorFilterKey: string = 'all';
  @Local detailBed: Bed | undefined = undefined;
  @Local detailVisible: boolean = false;
  private scroller: Scroller = new Scroller();
  private snackBar?: HdsSnackBar;

  aboutToAppear(): void {
    // Idempotent refresh so beds/rooms/elders are present even if the user
    // deep-navigates before the workspace snapshot finishes loading.
    void this.businessStore.load();
    void this.loadAreas();
  }

  private async loadAreas(): Promise<void> {
    try {
      const response = await ApiClient.get<AreaPage>('/areas');
      if (response.code === 0 && response.data !== undefined) {
        this.areas = response.data.list ?? [];
      }
    } catch (_error) {
      // 区域列表加载失败时退化为按房间楼层分组展示。
    }
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  @Monitor('compactWidth')
  onCompactWidthChange(): void {
    this.tileSideMeasured = false;
  }

  private notify(message: string): void {
    if (this.snackBar === undefined) {
      this.snackBar = new HdsSnackBar(this.getUIContext());
    }
    this.snackBar.show({}, { content: message }, {
      operationType: SnackBarOperationType.TEXT_ONLY, content: '知道了'
    }, { duration: 5000 });
  }

  // ---------- 筛选 ----------

  private areaOptions(): OrgArea[] {
    const usedIds: Set<number> = new Set<number>();
    this.businessStore.beds.forEach((bed: Bed) => {
      if (bed.area_id !== undefined) {
        usedIds.add(bed.area_id);
      }
    });
    const matched: OrgArea[] = this.areas.filter((area: OrgArea) => usedIds.has(area.id));
    return matched.length > 0 ? matched : this.areas;
  }

  private areaLabelOf(areaId: number): string {
    const area: OrgArea | undefined = this.areas.find((item: OrgArea) => item.id === areaId);
    return area !== undefined ? area.name : `区域 ${areaId}`;
  }

  private floorOptions(): number[] {
    const floors: number[] = [];
    this.businessStore.rooms.forEach((room: Room) => {
      if (!floors.includes(room.floor)) {
        floors.push(room.floor);
      }
    });
    return floors.sort((left: number, right: number) => left - right);
  }

  private selectedArea(): OrgArea | undefined {
    if (this.areaFilterKey === 'all') {
      return undefined;
    }
    return this.areas.find((area: OrgArea) => area.id.toString() === this.areaFilterKey);
  }

  private filteredBeds(): Bed[] {
    const area: OrgArea | undefined = this.selectedArea();
    const floor: number | undefined = this.floorFilterKey === 'all' ? undefined : Number(this.floorFilterKey);
    return this.businessStore.beds.filter((bed: Bed) => {
      if (area !== undefined && bed.area_id !== area.id) {
        return false;
      }
      if (floor !== undefined) {
        const room: Room | undefined = this.businessStore.rooms.find((item: Room) => item.id === bed.room_id);
        if (room === undefined || room.floor !== floor) {
          return false;
        }
      }
      return true;
    });
  }

  private roomOf(bed: Bed): Room | undefined {
    return this.businessStore.rooms.find((room: Room) => room.id === bed.room_id);
  }

  private elderOf(bed: Bed): Elder | undefined {
    return bed.elder_id === undefined ? undefined :
      this.businessStore.elders.find((elder: Elder) => elder.id === bed.elder_id);
  }

  // ---------- 统计 ----------

  private statCards(beds: Bed[]): StatCardData[] {
    const occupied: number = beds.filter((bed: Bed) => bed.status === 'occupied').length;
    const vacant: number = beds.filter((bed: Bed) => bed.status !== 'occupied' && bed.status !== 'maintenance').length;
    const maintenance: number = beds.filter((bed: Bed) => bed.status === 'maintenance').length;
    const rate: number = beds.length === 0 ? 0 : Math.round(occupied * 100 / beds.length);
    const areaLabel: string = this.selectedArea()?.name ?? '全部区域';
    return [
      { label: '总床位数', value: `${beds.length}`, note: areaLabel },
      { label: '已入住', value: `${occupied}`, note: `入住率 ${rate}%` },
      { label: '空床位', value: `${vacant}`, note: '可立即入住' },
      { label: '维护中', value: `${maintenance}`, note: '暂停使用' }
    ];
  }

  // ---------- 床位分布 ----------

  private areaGroups(): OrgArea[] {
    const groups: OrgArea[] = this.areaOptions().filter((area: OrgArea) =>
      this.filteredBeds().some((bed: Bed) => bed.area_id === area.id));
    if (groups.length > 0) {
      return groups;
    }
    // 无区域归属时按虚拟分组（key = -1）聚合全部床位。
    const virtualArea: OrgArea = {
      id: -1, parent_id: undefined, type: 'floor', code: 'all', name: this.selectedArea()?.name ?? '全部床位',
      status: 'active'
    };
    return [virtualArea];
  }

  private bedsOfArea(area: OrgArea): Bed[] {
    return this.filteredBeds().filter((bed: Bed) => bed.area_id === area.id);
  }

  private tileOf(bed: Bed): BedTileData {
    const elder: Elder | undefined = this.elderOf(bed);
    return {
      key: `tile-${bed.id}`,
      bedNo: bed.bed_no,
      status: bed.status,
      occupant: bed.status === 'occupied' ? (elder?.name ?? '已入住') :
        bed.status === 'maintenance' ? '维护' : '空床'
    };
  }

  private tileBackground(status: string): ResourceColor {
    if (status === 'maintenance') {
      return $r('app.color.status_warning_bg');
    }
    return status === 'occupied' ? $r('sys.color.comp_background_tertiary') :
      $r('sys.color.comp_background_primary');
  }

  private tileBedNoColor(status: string): ResourceColor {
    return status === 'maintenance' ? $r('app.color.doctor_workspace_warning') :
      status === 'occupied' ? $r('sys.color.font_primary') : $r('sys.color.font_secondary');
  }

  private columnsTemplate(): string {
    const columns: number = this.compactWidth ? 4 : 10;
    const templates: string[] = [];
    for (let index = 0; index < columns; index++) {
      templates.push('1fr');
    }
    return templates.join(' ');
  }

  private gridColumnCount(): number {
    return this.compactWidth ? 4 : 10;
  }

  private gridGap(): number {
    return this.compactWidth ? 10 : 14;
  }

  // 瓦片边长按网格实测宽度均分，保证任意屏宽下都接近正方形。
  @Local tileSide: number = 106;
  private tileSideMeasured: boolean = false;

  private updateTileSide(gridWidth: number): void {
    if (this.tileSideMeasured) {
      return;
    }
    this.tileSideMeasured = true;
    const columns: number = this.gridColumnCount();
    const side: number = (gridWidth - (columns - 1) * this.gridGap()) / columns;
    const clamped: number = Math.min(160, Math.max(84, side));
    if (Math.abs(clamped - this.tileSide) > 0.5) {
      this.tileSide = clamped;
    }
  }

  private gridRowsHeight(count: number): number {
    const rows: number = Math.max(1, Math.ceil(count / this.gridColumnCount()));
    return rows * this.tileSide + Math.max(0, rows - 1) * this.gridGap();
  }

  @Builder
  private bedTiles(area: OrgArea) {
    Grid() {
      ForEach(this.bedsOfArea(area), (bed: Bed) => {
        GridItem() {
          Column({ space: 8 }) {
            Text(this.tileOf(bed).bedNo)
              .fontSize(this.compactWidth ? 15 : 17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tileBedNoColor(bed.status))
            Text(this.tileOf(bed).occupant)
              .fontSize(this.compactWidth ? 12 : 14)
              .fontColor(bed.status === 'maintenance' ? $r('app.color.doctor_workspace_warning') :
                $r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(this.tileSide)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.tileBackground(bed.status))
          .borderRadius(10)
          .border({
            width: bed.status === 'maintenance' ? 1 : 0.5,
            color: bed.status === 'maintenance' ? $r('app.color.status_warning') : $r('sys.color.comp_divider')
          })
        }
      }, (bed: Bed) => this.tileOf(bed).key)
    }
    .width('100%')
    .height(this.gridRowsHeight(this.bedsOfArea(area).length))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateTileSide(Number(newValue.width));
    })
    .columnsTemplate(this.columnsTemplate())
    .columnsGap(this.compactWidth ? 10 : 14)
    .rowsGap(this.compactWidth ? 10 : 14)
    .scrollBar(BarState.Off)
  }

  // ---------- 床位详情 ----------

  private detailRows(beds: Bed[]): BedDetailRow[] {
    const today: string = new Date().toISOString().slice(0, 10);
    return beds.map((bed: Bed): BedDetailRow => {
      const elder: Elder | undefined = this.elderOf(bed);
      const room: Room | undefined = this.roomOf(bed);
      const caregiver: Schedule | undefined = room === undefined ? undefined :
        this.businessStore.schedules.find((item: Schedule) =>
          item.work_date === today && (item.room_scope ?? '').includes(room.room_no));
      return {
        key: `row-${bed.id}`,
        bedNo: `${bed.bed_no}床`,
        elderName: elder?.name ?? '—',
        careLevel: elder === undefined ? '—' : elder.care_level <= 0 ? '特级护理' : `${elder.care_level}级护理`,
        admittedAt: elder?.created_at === undefined ? '—' : elder.created_at.slice(0, 10),
        caregiver: caregiver?.staff ?? '—',
        status: bed.status
      };
    });
  }

  private statusText(status: string): string {
    return status === 'occupied' ? '已入住' : status === 'maintenance' ? '维护中' : '空闲';
  }

  private statusColor(status: string): ResourceColor {
    return status === 'occupied' ? $r('app.color.doctor_workspace_success') :
      status === 'maintenance' ? $r('app.color.doctor_workspace_warning') : $r('sys.color.font_secondary');
  }

  private readonly tableColumns: [string, number][] = [
    ['床位号', 1.0], ['入住长者', 1.0], ['护理等级', 1.3], ['入住时间', 1.3], ['责任护工', 1.0],
    ['状态', 0.9], ['操作', 1.1]
  ];

  @Builder
  private tableCell(text: string, weight: number, fontColor: ResourceColor) {
    Text(text)
      .fontSize(13)
      .fontColor(fontColor)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(weight)
  }

  @Builder
  private tableHeader() {
    Row({ space: 12 }) {
      ForEach(this.tableColumns, (column: [string, number]) => {
        Text(column[0])
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(column[1])
      }, (column: [string, number]) => `head-${column[0]}`)
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private tableRow(row: BedDetailRow) {
    Row({ space: 12 }) {
      this.tableCell(row.bedNo, 1.0, $r('sys.color.font_primary'))
      this.tableCell(row.elderName, 1.0, $r('sys.color.font_primary'))
      // 护理等级：浅灰胶囊标签
      Row() {
        Text(row.careLevel)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(6)
          .maxLines(1)
      }
      .layoutWeight(1.3)
      .justifyContent(FlexAlign.Start)
      this.tableCell(row.admittedAt, 1.3, $r('sys.color.font_secondary'))
      this.tableCell(row.caregiver, 1.0, $r('sys.color.font_secondary'))
      this.tableCell(this.statusText(row.status), 0.9, this.statusColor(row.status))
      Row({ space: 14 }) {
        Text('详情')
          .fontSize(13)
          .fontColor($r('app.color.brand_blue'))
          .onClick(() => this.openDetail(row.key))
        if (row.status === 'occupied') {
          Text('调整')
            .fontSize(13)
            .fontColor($r('app.color.brand_blue'))
            .onClick(() => this.notify('医师端为只读预览，床位调整请联系管理员'))
        } else if (row.status !== 'maintenance') {
          Text('分配')
            .fontSize(13)
            .fontColor($r('app.color.brand_blue'))
            .onClick(() => this.notify('医师端为只读预览，入住分配请联系管理员'))
        }
      }
      .layoutWeight(1.1)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
  }

  private openDetail(rowKey: string): void {
    const bedId: number = Number(rowKey.replace('row-', ''));
    const bed: Bed | undefined = this.businessStore.beds.find((item: Bed) => item.id === bedId);
    if (bed === undefined) {
      return;
    }
    this.detailBed = bed;
    this.detailVisible = true;
  }

  @Builder
  private detailSheetContent() {
    Column({ space: 14 }) {
      if (this.detailBed !== undefined) {
        ForEach(this.detailItems(), (item: [string, string]) => {
          Row({ space: 16 }) {
            Text(item[0])
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .width(96)
            Text(item[1])
              .fontSize(14)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }, (item: [string, string]) => `detail-${item[0]}`)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 28 + this.naviIndicatorHeight })
    .alignItems(HorizontalAlign.Start)
  }

  private roomLabelOf(bed: Bed): string {
    const room: Room | undefined = this.roomOf(bed);
    return room === undefined ? '—' : `${room.building}${room.floor}F · ${room.room_no}`;
  }

  private detailCareLevel(): string {
    const elder: Elder | undefined = this.detailBed === undefined ? undefined : this.elderOf(this.detailBed);
    if (elder === undefined) {
      return '—';
    }
    return elder.care_level <= 0 ? '特级护理' : `${elder.care_level}级护理`;
  }

  private detailItems(): [string, string][] {
    if (this.detailBed === undefined) {
      return [];
    }
    return [
      ['床位号', `${this.detailBed.bed_no}床`],
      ['所属房间', this.roomLabelOf(this.detailBed)],
      ['入住长者', this.elderOf(this.detailBed)?.name ?? '—'],
      ['护理等级', this.detailCareLevel()],
      ['紧急联系电话', this.elderOf(this.detailBed)?.contact_phone ?? '—'],
      ['入住时间', this.detailAdmittedAt()]
    ];
  }

  private detailAdmittedAt(): string {
    const elder: Elder | undefined = this.detailBed === undefined ? undefined : this.elderOf(this.detailBed);
    return elder?.created_at === undefined ? '—' : elder.created_at.slice(0, 10);
  }

  // ---------- 页面 ----------

  @Builder
  private statCard(item: StatCardData) {
    Column({ space: 6 }) {
      Text(item.label)
        .fontSize(this.compactWidth ? 13 : 14)
        .fontColor($r('sys.color.font_secondary'))
      Text(item.value)
        .fontSize(this.compactWidth ? 26 : 34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(item.note)
        .fontSize(this.compactWidth ? 11 : 12)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 14, top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private cardHeader(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 14 })
  }

  @Builder
  private filterBar() {
    Row({ space: 14 }) {
      Text('区域')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Select(this.areaOptions().map((area: OrgArea): SelectOption => ({ value: area.name })))
        .selected(this.areaFilterKey === 'all' ? -1 :
          Math.max(0, this.areaOptions().findIndex((area: OrgArea) => area.id.toString() === this.areaFilterKey)))
        .value(this.selectedArea()?.name ?? '选择区域')
        .fontColor($r('sys.color.font_primary'))
        .font({ size: 13 })
        .width(this.compactWidth ? 132 : 150)
        .height(36)
        .onSelect((index: number) => {
          const areas: OrgArea[] = this.areaOptions();
          this.areaFilterKey = index >= 0 && index < areas.length ? areas[index].id.toString() : 'all';
        })

      Text('楼层')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Select(this.floorOptions().map((floor: number): SelectOption => ({ value: `${floor}层` })))
        .selected(this.floorFilterKey === 'all' ? -1 :
          Math.max(0, this.floorOptions().findIndex((floor: number) => floor.toString() === this.floorFilterKey)))
        .value(this.floorFilterKey === 'all' ? '全部楼层' : `${this.floorFilterKey}层`)
        .fontColor($r('sys.color.font_primary'))
        .font({ size: 13 })
        .width(this.compactWidth ? 132 : 150)
        .height(36)
        .onSelect((index: number) => {
          const floors: number[] = this.floorOptions();
          this.floorFilterKey = index >= 0 && index < floors.length ? floors[index].toString() : 'all';
        })

      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private detailOverlayBuilder() {
    if (this.detailVisible) {
      Column() {
        Column() {
          this.detailSheetContent()
        }
        .width(this.compactWidth ? 460 : 560)
        .constraintSize({ maxHeight: 620 })
        .borderRadius(24)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .shadow({ radius: 48, color: '#1A000000', offsetY: 12 })
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          // 拦截点击，避免点面板内容时冒泡到遮罩导致关闭。
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#33000000')
      .onClick(() => {
        this.detailVisible = false;
      })
    }
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 16 }) {
            this.filterBar()

            Row({ space: this.compactWidth ? 10 : 14 }) {
              ForEach(this.statCards(this.filteredBeds()), (item: StatCardData) => {
                this.statCard(item)
              }, (item: StatCardData) => `${item.label}-${item.value}`)
            }
            .width('100%')

            if (this.filteredBeds().length === 0) {
              Column({ space: 0 }) {
                this.cardHeader('床位分布')
                QuickEmptyHint({ text: '该筛选条件下暂无床位', loading: this.businessStore.loading })
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .clip(true)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            } else {
              Column({ space: 0 }) {
                this.cardHeader('床位分布')
                Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
                ForEach(this.areaGroups(), (area: OrgArea, index: number) => {
                  Column({ space: 14 }) {
                    Text(area.name)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    this.bedTiles(area)
                  }
                  .width('100%')
                  .padding({ left: 20, right: 20, top: index === 0 ? 16 : 22, bottom: 4 })
                  .alignItems(HorizontalAlign.Start)
                }, (area: OrgArea) => `group-${area.id}`)
                Blank().height(16)
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .clip(true)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })

              Column({ space: 0 }) {
                this.cardHeader('床位详情')
                this.tableHeader()
                ForEach(this.detailRows(this.filteredBeds()), (row: BedDetailRow) => {
                  this.tableRow(row)
                }, (row: BedDetailRow) => row.key)
                if (this.detailRows(this.filteredBeds()).length === 0) {
                  QuickEmptyHint({ text: '暂无床位记录', loading: false })
                }
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .clip(true)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 1280 })
          .padding({
            left: this.compactWidth ? 16 : 28,
            right: this.compactWidth ? 16 : 28,
            top: 88 + this.statusBarHeight,
            bottom: 24 + this.naviIndicatorHeight
          })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onBackPressed((): boolean => {
      this.onClose();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '床位管理' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .bindSheet(this.detailVisible!!, this.detailSheetContent(), {
      height: SheetSize.FIT_CONTENT,
      blurStyle: BlurStyle.Thick,
      showClose: true,
      title: { title: '床位详情' },
      preferType: SheetType.CENTER,
      enableOutsideInteractive: false
    })
  }
}
