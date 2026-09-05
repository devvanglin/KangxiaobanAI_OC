import { HdsListItemCard, HdsSnackBar, SnackBarOperationType, SuffixButton } from '@kit.UIDesignKit';
import ApiClient from '../../network/ApiClient';
import { CarePackageItem, CarePackageTemplate } from '../../network/Dto';

interface PackagePage { list: CarePackageTemplate[]; }
interface PackageSaveRequest { code: string; name: string; description: string; applicable_care_level?: number; monthly_price: number; status: string; currency: string; }
interface PackageItemRequest { title: string; frequency: string; enabled: boolean; }

const DARK_BUTTON_BG: string = '#1F1F1F';
const CARD_HEIGHT: number = 300;
const CARE_LEVEL_NAMES: string[] = ['不限', '一级护理', '二级护理', '三级护理', '四级护理', '特级护理'];
const CARE_LEVEL_FG: string[] = ['#5A6B85', '#C0392B', '#B7791F', '#2E8B57', '#5A6B85', '#FFFFFF'];
const CARE_LEVEL_BG: string[] = ['#EEF1F5', '#FDECEC', '#FDF3E0', '#E8F5EE', '#EEF1F5', '#1F1F1F'];

@ComponentV2
export struct WideCarePackageManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local templates: CarePackageTemplate[] = [];
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local searchQuery: string = '';
  @Local showEditor: boolean = false;
  @Local editingId: number = 0;
  @Local code: string = '';
  @Local name: string = '';
  @Local price: string = '';
  @Local description: string = '';
  @Local careLevelIndex: number = 0;
  @Local showItemCreate: boolean = false;
  @Local itemTemplateId: number = 0;
  @Local itemTitle: string = '';
  @Local itemFrequency: string = '';
  @Local showDetail: boolean = false;
  @Local detailTemplate: CarePackageTemplate | undefined = undefined;
  private snackBar?: HdsSnackBar;

  aboutToAppear(): void { this.load(); }

  private notify(message: string): void {
    if (this.snackBar === undefined) {
      this.snackBar = new HdsSnackBar(this.getUIContext());
    }
    this.snackBar.show({}, { content: message }, {
      operationType: SnackBarOperationType.TEXT_ONLY, content: '知道了'
    });
  }

  private async load(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const response = await ApiClient.get<PackagePage>('/care-package-templates?status=');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.templates = response.data.list ?? [];
    } catch (_error) { this.error = '护理套餐加载失败'; }
    this.loading = false;
  }

  private filteredTemplates(): CarePackageTemplate[] {
    const query: string = this.searchQuery.trim().toLowerCase();
    if (query.length === 0) { return this.templates; }
    return this.templates.filter((item: CarePackageTemplate) => {
      return item.name.toLowerCase().includes(query) || item.code.toLowerCase().includes(query);
    });
  }

  private templateRows(): CarePackageTemplate[][] {
    const size: number = this.compactWidth ? 2 : 3;
    const list: CarePackageTemplate[] = this.filteredTemplates();
    const rows: CarePackageTemplate[][] = [];
    for (let i = 0; i < list.length; i += size) {
      rows.push(list.slice(i, i + size));
    }
    return rows;
  }

  private formatPrice(value: number): string {
    const rounded: number = Math.round(value);
    const digits: string = String(Math.abs(rounded));
    let out: string = '';
    for (let i = 0; i < digits.length; i++) {
      out = out + digits.charAt(i);
      if ((digits.length - i - 1) % 3 === 0 && i < digits.length - 1) { out = out + ','; }
    }
    return (rounded < 0 ? '-¥' : '¥') + out;
  }

  private enabledItems(item: CarePackageTemplate): CarePackageItem[] {
    return (item.items ?? []).filter((serviceItem: CarePackageItem) => serviceItem.enabled);
  }

  private careLevelName(level: number): string {
    return level >= 1 && level <= 5 ? CARE_LEVEL_NAMES[level] : '不限';
  }

  private async save(): Promise<void> {
    if (this.code.trim() === '' || this.name.trim() === '') { this.error = '套餐编码和名称不能为空'; return; }
    const level: number = this.careLevelIndex;
    const request: PackageSaveRequest = {
      code: this.code.trim(), name: this.name.trim(), description: this.description.trim(),
      applicable_care_level: level >= 1 && level <= 5 ? level : undefined,
      monthly_price: Number(this.price) || 0, status: 'active', currency: 'CNY'
    };
    const response = this.editingId > 0 ? await ApiClient.put<CarePackageTemplate>(`/care-package-templates/${this.editingId}`, request) : await ApiClient.post<CarePackageTemplate>('/care-package-templates', request);
    if (response.code !== 0) { this.error = response.msg || '套餐保存失败'; return; }
    this.showEditor = false;
    this.error = '';
    await this.load();
    this.notify(this.editingId > 0 ? '套餐已保存' : '套餐已创建');
  }

  private openItemCreate(template: CarePackageTemplate): void { this.itemTemplateId = template.id; this.itemTitle = ''; this.itemFrequency = ''; this.showItemCreate = true; }

  private async addItem(): Promise<void> {
    if (this.itemTemplateId === 0 || this.itemTitle.trim() === '') { this.error = '护理项目名称不能为空'; return; }
    const request: PackageItemRequest = { title: this.itemTitle.trim(), frequency: this.itemFrequency.trim(), enabled: true };
    const response = await ApiClient.post<CarePackageItem>(`/care-package-templates/${this.itemTemplateId}/items`, request);
    if (response.code !== 0) { this.error = response.msg || '护理项目保存失败'; return; }
    this.showItemCreate = false; this.itemTitle = ''; this.itemFrequency = '';
    await this.load();
    this.notify('护理项目已添加');
  }

  private openEditor(item?: CarePackageTemplate): void {
    this.error = '';
    if (item !== undefined) {
      this.editingId = item.id;
      this.code = item.code;
      this.name = item.name;
      this.price = String(item.monthly_price);
      this.description = item.description ?? '';
      this.careLevelIndex = item.applicable_care_level ?? 0;
    } else {
      this.editingId = 0;
      this.code = '';
      this.name = '';
      this.price = '';
      this.description = '';
      this.careLevelIndex = 0;
    }
    this.showEditor = true;
  }

  private openDetail(item: CarePackageTemplate): void {
    this.detailTemplate = item;
    this.showDetail = true;
  }

  private detailItems(): CarePackageItem[] {
    const template: CarePackageTemplate | undefined = this.detailTemplate;
    if (template === undefined) { return []; }
    return this.enabledItems(template);
  }

  private async removeItem(serviceItem: CarePackageItem): Promise<void> {
    if (this.detailTemplate === undefined) { return; }
    const response = await ApiClient.delete<Object>(`/care-package-templates/${this.detailTemplate.id}/items/${serviceItem.id}`);
    if (response.code !== 0) { this.error = response.msg || '护理项目删除失败'; return; }
    await this.load();
    const refreshed: CarePackageTemplate | undefined = this.templates.find((template: CarePackageTemplate) => template.id === this.detailTemplate?.id);
    if (refreshed !== undefined) { this.detailTemplate = refreshed; }
    this.notify('护理项目已删除');
  }

  @Builder
  private levelBadge(item: CarePackageTemplate) {
    if (item.applicable_care_level !== undefined && item.applicable_care_level >= 1 && item.applicable_care_level <= 5) {
      Text(this.careLevelName(item.applicable_care_level))
        .fontSize(11).fontColor(CARE_LEVEL_FG[item.applicable_care_level])
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(8)
        .backgroundColor(CARE_LEVEL_BG[item.applicable_care_level])
    } else {
      Text(item.status === 'active' ? '启用中' : '已停用')
        .fontSize(11).fontColor(item.status === 'active' ? '#2E8B57' : '#8A94A6')
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(8)
        .backgroundColor(item.status === 'active' ? '#E8F5EE' : '#EEF1F5')
    }
  }

  @Builder
  private packageCard(item: CarePackageTemplate) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(item.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank().layoutWeight(1)
        this.levelBadge(item)
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 4 }) {
        Text(this.formatPrice(item.monthly_price)).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Text('/月').fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').alignItems(VerticalAlign.Bottom)
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Scroll() {
        Column({ space: 6 }) {
          Text('服务内容').fontSize(12).fontColor($r('sys.color.font_tertiary'))
          if (this.enabledItems(item).length === 0) {
            Text('尚未配置护理项目').fontSize(13).fontColor($r('sys.color.font_tertiary'))
          } else {
            ForEach(this.enabledItems(item), (serviceItem: CarePackageItem) => {
              Text(`• ${serviceItem.title}${serviceItem.frequency !== undefined && serviceItem.frequency.length > 0 ? `（${serviceItem.frequency}）` : ''}`)
                .fontSize(13).fontColor($r('sys.color.font_primary'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }, (serviceItem: CarePackageItem) => `card-item-${item.id}-${serviceItem.id}`)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
      .scrollBar(BarState.Auto)
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row() {
        Text(`共 ${this.enabledItems(item).length} 项服务`).fontSize(11).fontColor($r('sys.color.font_tertiary'))
        Blank().layoutWeight(1)
      }.width('100%')
      Row({ space: 10 }) {
        Button('编辑').layoutWeight(1).height(38).fontSize(13).borderRadius(8)
          .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.openEditor(item))
        Button('详情').layoutWeight(1).height(38).fontSize(13).borderRadius(8)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.openDetail(item))
      }.width('100%')
    }.width('100%').height(CARD_HEIGHT).padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .clip(true)
  }

  @Builder
  private detailDialog() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(this.detailTemplate?.name ?? '套餐详情').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.detailTemplate !== undefined) {
          this.levelBadge(this.detailTemplate)
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 4 }) {
        Text(this.formatPrice(this.detailTemplate?.monthly_price ?? 0)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Text('/月').fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.width('100%').alignItems(VerticalAlign.Bottom)
      if (this.detailTemplate?.description !== undefined && (this.detailTemplate?.description ?? '').length > 0) {
        Text(this.detailTemplate?.description).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      }
      Text(`服务内容 · 共 ${this.detailItems().length} 项`).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')).width('100%')
      List({ space: 8 }) {
        ForEach(this.detailItems(), (serviceItem: CarePackageItem) => {
          ListItem() {
            HdsListItemCard({
              textItem: {
                primaryText: { text: serviceItem.title },
                secondaryText: {
                  text: serviceItem.frequency !== undefined && serviceItem.frequency.length > 0
                    ? `执行频次：${serviceItem.frequency}`
                    : (serviceItem.instructions !== undefined && serviceItem.instructions.length > 0 ? serviceItem.instructions : '按套餐计划执行')
                }
              },
              suffixItem: new SuffixButton({
                text: '删除',
                textColor: $r('app.color.doctor_workspace_danger'),
                onClick: () => this.removeItem(serviceItem)
              })
            })
          }
        }, (serviceItem: CarePackageItem) => `detail-item-${serviceItem.id}`)
        if (this.detailItems().length === 0) {
          ListItem() {
            Text('尚未配置护理项目，点击下方「添加项目」开始。')
              .fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%').padding(14)
              .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(10)
          }
        }
      }.width('100%').height(260).scrollBar(BarState.Off)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40).fontSize(13).borderRadius(8)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showDetail = false)
        Button('添加项目').layoutWeight(1).height(40).fontSize(13).borderRadius(8)
          .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => {
            if (this.detailTemplate !== undefined) { this.openItemCreate(this.detailTemplate); }
          })
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 560).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      .constraintSize({ maxHeight: '86%' })
  }

  @Builder
  private editorDialog() {
    Column({ space: 12 }) {
      Text(this.editingId > 0 ? '编辑套餐' : '新增护理套餐').fontSize(20).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '套餐编码，例如 basic-care', text: $$this.code }).height(42)
      TextInput({ placeholder: '套餐名称', text: $$this.name }).height(42)
      Row({ space: 14 }) {
        Column({ space: 6 }) {
          Text('月度价格').fontSize(12).fontColor($r('sys.color.font_secondary'))
          TextInput({ placeholder: '例如 2800', text: $$this.price }).height(42).type(InputType.Number)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 6 }) {
          Text('适用照护等级').fontSize(12).fontColor($r('sys.color.font_secondary'))
          Select(CARE_LEVEL_NAMES.map((levelName: string) => {
            return { value: levelName } as SelectOption;
          }))
            .selected(this.careLevelIndex).value(CARE_LEVEL_NAMES[this.careLevelIndex])
            .fontColor($r('sys.color.font_primary')).font({ size: 13 })
            .onSelect((index: number) => this.careLevelIndex = index)
            .width('100%').height(42)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      TextArea({ placeholder: '套餐说明，例如 床位费 + 基础护理费', text: $$this.description }).height(80)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40).fontSize(13)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showEditor = false; this.error = ''; })
        Button('保存').layoutWeight(1).height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.save())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 480).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            Text('护理套餐').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary')).layoutWeight(1)
            Search({ value: this.searchQuery, placeholder: '搜索套餐名称' })
              .width(this.compactWidth ? '100%' : 260).height(38)
              .onChange((value: string) => this.searchQuery = value)
            Button('新增套餐').height(38).fontSize(13).borderRadius(8)
              .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
              .onClick(() => this.openEditor())
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.error.length > 0) {
            Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          if (this.loading) {
            LoadingProgress().width(34).height(34)
          }
          ForEach(this.templateRows(), (row: CarePackageTemplate[]) => {
            Row({ space: 12 }) {
              ForEach(row, (item: CarePackageTemplate) => {
                Row() { this.packageCard(item) }.layoutWeight(1).alignItems(VerticalAlign.Top)
              }, (item: CarePackageTemplate) => `pkg-${item.id}-${(item.items ?? []).length}`)
            }.width('100%')
          }, (row: CarePackageTemplate[]) => `pkg-row-${row.length > 0 ? row[0].id : 0}-${row.length}`)
          if (!this.loading && this.templates.length === 0) {
            Text(this.searchQuery.length > 0 ? '没有匹配的套餐' : '暂无套餐，点击右上角「新增套餐」创建')
              .fontSize(13).fontColor($r('sys.color.font_tertiary')).padding({ top: 48, bottom: 48 }).width('100%')
              .textAlign(TextAlign.Center)
          }
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
          top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      if (this.showEditor) {
        Row() { this.editorDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showDetail) {
        Row() { this.detailDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showItemCreate) {
        Row() {
          Column({ space: 12 }) {
            Text('添加护理项目').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            TextInput({ placeholder: '项目名称，例如 每日健康巡查', text: $$this.itemTitle }).height(42)
            TextInput({ placeholder: '执行频次，可选，例如 每日 2 次', text: $$this.itemFrequency }).height(42)
            Row({ space: 10 }) {
              Button('取消').layoutWeight(1).height(40).fontSize(13)
                .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
                .onClick(() => this.showItemCreate = false)
              Button('保存').layoutWeight(1).height(40).fontSize(13)
                .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
                .onClick(() => this.addItem())
            }.width('100%')
          }.width(this.compactWidth ? '90%' : 440).padding(24)
            .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
        }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
