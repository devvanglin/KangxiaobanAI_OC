import { ApiClient } from '../../network/ApiClient';

const DARK_BUTTON_BG: string = '#1D63ED';
const MED_CATEGORIES: string[] = ['西药', '中药', '保健品'];
const MED_USAGES: string[] = ['口服', '注射', '外用', '雾化'];

interface MedicationItem {
  id: number;
  name: string;
  category: string;
  specification: string;
  manufacturer: string;
  usage_method: string;
  stock: number;
  unit: string;
  status: string;
  note: string;
  updated_at?: string;
}

interface MedicationPage { list: MedicationItem[]; total: number; }

interface MedicationPayload {
  name: string;
  category: string;
  specification: string;
  manufacturer: string;
  usage_method: string;
  stock: number;
  unit: string;
  status: string;
  note: string;
}

/** 管理端「药物」一级模块：机构药物目录维护（搜索/新增/编辑/删除）。 */
@ComponentV2
export struct WideMedicationManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();

  @Local medications: MedicationItem[] = [];
  @Local medsLoading: boolean = false;
  @Local medsSearch: string = '';
  @Local showMedEditor: boolean = false;
  @Local medBusy: boolean = false;
  @Local medEditingId: number = 0;
  @Local medName: string = '';
  @Local medCategory: string = '西药';
  @Local medSpec: string = '';
  @Local medManufacturer: string = '';
  @Local medUsage: string = '口服';
  @Local medStock: string = '0';
  @Local medUnit: string = '盒';
  @Local medStatus: boolean = true;
  @Local medNote: string = '';
  @Local confirmingMedId: number = 0;

  aboutToAppear(): void {
    this.loadMedications();
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (_error) {
      // Toast 展示失败时静默，不打断页面。
    }
  }

  private async loadMedications(): Promise<void> {
    this.medsLoading = true;
    try {
      const response = await ApiClient.get<MedicationPage>('/admin/medications?page=1&size=200');
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '药物列表获取失败');
        this.medications = [];
      } else {
        this.medications = response.data.list ?? [];
      }
    } catch (error) {
      this.showToast(error instanceof Error && error.message.length > 0 ? error.message : '药物列表获取失败');
      this.medications = [];
    }
    this.medsLoading = false;
  }

  private visibleMeds(): MedicationItem[] {
    const query: string = this.medsSearch.trim().toLowerCase();
    if (query.length === 0) { return this.medications; }
    return this.medications.filter((item: MedicationItem): boolean =>
      item.name.toLowerCase().includes(query) || item.manufacturer.toLowerCase().includes(query));
  }

  /** 一行三张卡片；紧凑宽度放不下三列，降为两列。 */
  private medCardColumns(): number {
    return this.compactWidth ? 2 : 3;
  }

  private medCardRows(): MedicationItem[][] {
    const columns: number = this.medCardColumns();
    const items: MedicationItem[] = this.visibleMeds();
    const rows: MedicationItem[][] = [];
    for (let i = 0; i < items.length; i += columns) {
      rows.push(items.slice(i, i + columns));
    }
    return rows;
  }

  /** 末行补位，保证已放置的卡片仍占 1/N 宽度。 */
  private medRowFillers(rowLength: number): number[] {
    const fillers: number[] = [];
    for (let i = rowLength; i < this.medCardColumns(); i++) {
      fillers.push(i);
    }
    return fillers;
  }

  private openMedEditor(item?: MedicationItem): void {
    this.medEditingId = item !== undefined ? item.id : 0;
    this.medName = item?.name ?? '';
    this.medCategory = item !== undefined && item.category.length > 0 ? item.category : '西药';
    this.medSpec = item?.specification ?? '';
    this.medManufacturer = item?.manufacturer ?? '';
    this.medUsage = item !== undefined && item.usage_method.length > 0 ? item.usage_method : '口服';
    this.medStock = item !== undefined ? String(item.stock) : '0';
    this.medUnit = item !== undefined && item.unit.length > 0 ? item.unit : '盒';
    this.medStatus = item === undefined || item.status !== 'discontinued';
    this.medNote = item?.note ?? '';
    this.confirmingMedId = 0;
    this.showMedEditor = true;
  }

  private async saveMedication(): Promise<void> {
    if (this.medBusy) { return; }
    const name: string = this.medName.trim();
    if (name.length === 0) {
      this.showToast('药物名称必填');
      return;
    }
    const stock: number = Number(this.medStock);
    const payload: MedicationPayload = {
      name: name,
      category: this.medCategory,
      specification: this.medSpec.trim(),
      manufacturer: this.medManufacturer.trim(),
      usage_method: this.medUsage,
      stock: Number.isFinite(stock) && stock > 0 ? Math.round(stock) : 0,
      unit: this.medUnit.trim().length > 0 ? this.medUnit.trim() : '盒',
      status: this.medStatus ? 'in_use' : 'discontinued',
      note: this.medNote.trim()
    };
    this.medBusy = true;
    try {
      const response = this.medEditingId > 0
        ? await ApiClient.put<MedicationItem>(`/admin/medications/${this.medEditingId}`, payload)
        : await ApiClient.post<MedicationItem>('/admin/medications', payload);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '药物保存失败');
      } else {
        this.showToast(this.medEditingId > 0 ? '药物已更新' : '药物已新增');
        this.showMedEditor = false;
        await this.loadMedications();
      }
    } catch (_error) {
      this.showToast('药物保存失败，请检查网络');
    }
    this.medBusy = false;
  }

  private async deleteMedication(id: number): Promise<void> {
    if (this.confirmingMedId !== id) {
      this.confirmingMedId = id;
      return;
    }
    if (this.medBusy) { return; }
    this.medBusy = true;
    try {
      const response = await ApiClient.delete<Object>(`/admin/medications/${id}`);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '药物删除失败');
      } else {
        this.showToast('药物已删除');
        this.confirmingMedId = 0;
        await this.loadMedications();
      }
    } catch (_error) {
      this.showToast('药物删除失败，请检查网络');
    }
    this.medBusy = false;
  }

  @Builder
  private fieldLabel(label: string) {
    Text(label).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
  }

  @Builder
  private statCell(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label).fontSize(12).fontColor($r('sys.color.font_tertiary'))
      Text(value).fontSize(13.5).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private cardLink(label: string, onTap: () => void) {
    Text(label).fontSize(13.5).fontColor($r('sys.color.font_secondary'))
      .onClick(() => onTap())
  }

  @Builder
  private medicationCard(item: MedicationItem) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.status === 'in_use' ? '在用' : '停用')
          .fontSize(11).fontColor(item.status === 'in_use' ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          .backgroundColor(item.status === 'in_use' ? '#F0FDF4' : $r('sys.color.comp_background_secondary'))
      }.width('100%').alignItems(VerticalAlign.Center)
      if (item.note.trim().length > 0) {
        Text(item.note).fontSize(12.5).fontColor($r('sys.color.font_secondary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      } else {
        // 占位保持所有卡片等高，网格行内不出现参差。
        Text(' ').fontSize(12.5).width('100%')
      }
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 8 }) {
        this.statCell('规格', item.specification.length > 0 ? item.specification : '--')
        this.statCell('类别', item.category.length > 0 ? item.category : '--')
      }.width('100%')
      Row({ space: 8 }) {
        this.statCell('用法', item.usage_method.length > 0 ? item.usage_method : '--')
        this.statCell('库存', `${item.stock} ${item.unit}`)
      }.width('100%')
      Row({ space: 10 }) {
        Text('厂家').fontSize(12).fontColor($r('sys.color.font_secondary')).constraintSize({ minWidth: 68 })
        Text(item.manufacturer.length > 0 ? item.manufacturer : '--')
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 14 }) {
        this.cardLink('编辑', () => this.openMedEditor(item))
        if (this.confirmingMedId === item.id) {
          Text('确认删除').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_danger'))
            .onClick(() => this.deleteMedication(item.id))
        } else {
          Text('删除').fontSize(13).fontColor($r('app.color.doctor_workspace_danger'))
            .onClick(() => this.deleteMedication(item.id))
        }
      }.width('100%')
    }.width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(10)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private medEditorDialog() {
    Column({ space: 12 }) {
      this.fieldLabel('药物名称')
      TextInput({ placeholder: '例如: 阿司匹林肠溶片', text: $$this.medName }).height(40).fontSize(13)
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          this.fieldLabel('类别')
          Select(MED_CATEGORIES.map((item: string): SelectOption => ({ value: item } as SelectOption)))
            .selected(Math.max(0, MED_CATEGORIES.indexOf(this.medCategory)))
            .value(this.medCategory)
            .font({ size: 14 }).height(40).width('100%')
            .onSelect((index: number) => {
              if (index >= 0 && index < MED_CATEGORIES.length) { this.medCategory = MED_CATEGORIES[index]; }
            })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 4 }) {
          this.fieldLabel('用法')
          Select(MED_USAGES.map((item: string): SelectOption => ({ value: item } as SelectOption)))
            .selected(Math.max(0, MED_USAGES.indexOf(this.medUsage)))
            .value(this.medUsage)
            .font({ size: 14 }).height(40).width('100%')
            .onSelect((index: number) => {
              if (index >= 0 && index < MED_USAGES.length) { this.medUsage = MED_USAGES[index]; }
            })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Top)
      this.fieldLabel('规格')
      TextInput({ placeholder: '例如: 100mg×30片', text: $$this.medSpec }).height(40).fontSize(13)
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          this.fieldLabel('库存数量')
          TextInput({ text: $$this.medStock }).height(40).fontSize(13).type(InputType.Number)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 4 }) {
          this.fieldLabel('单位')
          TextInput({ text: $$this.medUnit }).height(40).fontSize(13)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Top)
      this.fieldLabel('生产厂家')
      TextInput({ placeholder: '生产厂家', text: $$this.medManufacturer }).height(40).fontSize(13)
      this.fieldLabel('备注')
      TextArea({ text: $$this.medNote, placeholder: '用药提示、储存要求等' }).height(72).fontSize(13)
      Row({ space: 8 }) {
        Toggle({ type: ToggleType.Switch, isOn: this.medStatus })
          .selectedColor($r('app.color.brand_blue'))
          .onChange((isOn: boolean) => this.medStatus = isOn)
        Text(this.medStatus ? '在用' : '停用').fontSize(13).fontColor($r('sys.color.font_primary'))
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showMedEditor = false; })
        Button(this.medBusy ? '保存中…' : '保存').layoutWeight(1).height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .enabled(!this.medBusy)
          .onClick(() => this.saveMedication())
      }.width('100%')
    }.width('100%').padding(24)
      .backgroundColor($r('sys.color.comp_background_primary'))
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          Row({ space: 10 }) {
            Search({ value: this.medsSearch, placeholder: '搜索药物名称或厂家' })
              .height(38).width(260)
              .onChange((value: string) => this.medsSearch = value)
            Blank()
            Button('＋ 新增药物').height(38).fontSize(14).borderRadius(8)
              .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
              .onClick(() => this.openMedEditor())
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.medsLoading) {
            Text('正在获取药物目录…').fontSize(14).fontColor($r('sys.color.font_secondary'))
              .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
          } else if (this.visibleMeds().length === 0) {
            Text('暂无药物，点击「新增药物」建立机构药物目录。')
              .fontSize(14).fontColor($r('sys.color.font_secondary'))
              .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
          } else {
            ForEach(this.medCardRows(), (row: MedicationItem[], rowIndex: number) => {
              Row({ space: 12 }) {
                ForEach(row, (item: MedicationItem) => {
                  Column() {
                    this.medicationCard(item)
                  }
                  .layoutWeight(1)
                }, (item: MedicationItem) => `med-${item.id}`)
                ForEach(this.medRowFillers(row.length), (filler: number) => {
                  Column().layoutWeight(1)
                }, (filler: number) => `med-fill-${rowIndex}-${filler}`)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (row: MedicationItem[], rowIndex: number) => `med-row-${rowIndex}-${row.length}`)
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%', maxWidth: 1280 })
        .padding({
          left: this.compactWidth ? 16 : 28,
          right: this.compactWidth ? 16 : 28,
          top: 88 + this.statusBarHeight,
          bottom: 24 + this.naviIndicatorHeight
        })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    // 半模态编辑窗：与床位管理页同款写法。宽窗口居中弹出（SheetType.CENTER），
    // 窄窗口自动退化为底部半模态；高度贴合表单内容，关闭按钮由 sheet 提供。
    .bindSheet(this.showMedEditor!!, this.medEditorDialog(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      title: { title: this.medEditingId > 0 ? '编辑药物' : '新增药物' },
      preferType: SheetType.CENTER,
      enableOutsideInteractive: false,
      backgroundColor: $r('sys.color.comp_background_primary')
    })
  }
}
