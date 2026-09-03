import ApiClient from '../../network/ApiClient';
import { CarePackageItem, CarePackageTemplate, Elder } from '../../network/Dto';

interface PackagePage { list: CarePackageTemplate[]; }
interface PackageCreateRequest { code: string; name: string; description: string; monthly_price: number; status: string; currency: string; }
interface ElderPage { list: Elder[]; }
interface SubscriptionRequest { template_id: number; start_date: string; }
interface PackageItemRequest { title: string; frequency: string; enabled: boolean; }

@ComponentV2
export struct WideCarePackageManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local templates: CarePackageTemplate[] = [];
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local showCreate: boolean = false;
  @Local code: string = '';
  @Local name: string = '';
  @Local price: string = '';
  @Local description: string = '';
  @Local elders: Elder[] = [];
  @Local showAssign: boolean = false;
  @Local assignTemplateId: number = 0;
  @Local assignElderId: number = 0;
  @Local showItemCreate: boolean = false;
  @Local itemTemplateId: number = 0;
  @Local itemTitle: string = '';
  @Local itemFrequency: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(); this.loadElders(); }

  private async load(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const response = await ApiClient.get<PackagePage>('/care-package-templates?status=');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.templates = response.data.list ?? [];
    } catch (_error) { this.error = '护理套餐加载失败'; }
    this.loading = false;
  }

  private async loadElders(): Promise<void> {
    try { const response = await ApiClient.get<ElderPage>('/elders?page=1&size=100'); if (response.code === 0 && response.data !== undefined) this.elders = response.data.list ?? []; } catch (_error) { }
  }

  private async create(): Promise<void> {
    if (this.code.trim() === '' || this.name.trim() === '') { this.error = '套餐编码和名称不能为空'; return; }
    const request: PackageCreateRequest = { code: this.code.trim(), name: this.name.trim(), description: this.description.trim(), monthly_price: Number(this.price) || 0, status: 'active', currency: 'CNY' };
    const response = await ApiClient.post<CarePackageTemplate>('/care-package-templates', request);
    if (response.code !== 0) { this.error = response.msg || '套餐创建失败'; return; }
    this.showCreate = false; this.code = ''; this.name = ''; this.price = ''; this.description = ''; await this.load();
  }

  private itemSummary(items?: CarePackageItem[]): string { return items === undefined || items.length === 0 ? '尚未配置护理项目' : `${items.length} 项护理服务`; }

  private openAssign(template: CarePackageTemplate): void { this.assignTemplateId = template.id; this.assignElderId = this.elders[0]?.id ?? 0; this.showAssign = true; }

  private async assign(): Promise<void> {
    if (this.assignTemplateId === 0 || this.assignElderId === 0) { this.error = '请先选择长者'; return; }
    const request: SubscriptionRequest = { template_id: this.assignTemplateId, start_date: new Date().toISOString().slice(0, 10) };
    const response = await ApiClient.post<Object>(`/elders/${this.assignElderId}/care-package-subscriptions`, request);
    if (response.code !== 0) { this.error = response.msg || '套餐分配失败'; return; }
    this.showAssign = false; this.error = '套餐已分配，护理计划和任务已生成';
  }

  private openItemCreate(template: CarePackageTemplate): void { this.itemTemplateId = template.id; this.itemTitle = ''; this.itemFrequency = ''; this.showItemCreate = true; }

  private async addItem(): Promise<void> {
    if (this.itemTemplateId === 0 || this.itemTitle.trim() === '') { this.error = '护理项目名称不能为空'; return; }
    const request: PackageItemRequest = { title: this.itemTitle.trim(), frequency: this.itemFrequency.trim(), enabled: true };
    const response = await ApiClient.post<CarePackageItem>(`/care-package-templates/${this.itemTemplateId}/items`, request);
    if (response.code !== 0) { this.error = response.msg || '护理项目保存失败'; return; }
    this.showItemCreate = false; this.itemTitle = ''; this.itemFrequency = ''; await this.load();
  }

  @Builder
  private dialog() {
    if (this.showCreate) {
      Column({ space: 12 }) {
        Text('新增护理套餐').fontSize(20).fontWeight(FontWeight.Medium)
        TextInput({ placeholder: '套餐编码，例如 basic-care', text: $$this.code }).height(42)
        TextInput({ placeholder: '套餐名称', text: $$this.name }).height(42)
        TextInput({ placeholder: '月度价格，可选', text: $$this.price }).height(42).type(InputType.Number)
        TextArea({ placeholder: '套餐说明，可选', text: $$this.description }).height(90)
        Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showCreate = false); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.create()) }.width('100%')
      }.width(this.compactWidth ? '90%' : 460).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
    }
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Row() { Column({ space: 4 }) { Text('计划套餐').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold); Text('配置医师入住和长者护理使用的套餐模板').fontSize(11).fontColor($r('sys.color.font_secondary')) }.layoutWeight(1); Button('新增套餐').height(36).fontSize(12).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.showCreate = true) }.width('100%')
          if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
          if (this.loading) LoadingProgress().width(34).height(34)
          ForEach(this.templates, (item: CarePackageTemplate) => {
            Column({ space: 8 }) {
              Row() { Text(item.name).fontSize(16).fontWeight(FontWeight.Medium); Blank().layoutWeight(1); Text(item.status === 'active' ? '启用' : item.status).fontSize(12).fontColor(item.status === 'active' ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary')) }.width('100%')
              Text(`${item.code} · ¥${item.monthly_price.toFixed(2)} / 月 · ${this.itemSummary(item.items)}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
              if (item.description !== undefined && item.description.length > 0) Text(item.description).fontSize(12).fontColor($r('sys.color.font_secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Row({ space: 8 }) { Button('添加项目').height(32).fontSize(11).onClick(() => this.openItemCreate(item)); Button('分配给长者').height(32).fontSize(11).onClick(() => this.openAssign(item)) }
            }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
          }, (item: CarePackageTemplate) => `package-${item.id}`)
          if (!this.loading && this.templates.length === 0) Text('暂无套餐，请先新增').fontSize(13).fontColor($r('sys.color.font_tertiary')).padding({ top: 48, bottom: 48 })
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      }.width('100%').height('100%').scrollBar(BarState.Off)
      if (this.showCreate) Row() { this.dialog() }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      if (this.showAssign) Row() {
        Column({ space: 12 }) {
          Text('分配护理套餐').fontSize(20).fontWeight(FontWeight.Medium)
          Text('选择长者').fontSize(12).fontColor($r('sys.color.font_secondary'))
          ForEach(this.elders, (elder: Elder) => Button(elder.name).width('100%').height(36).fontSize(12).backgroundColor(this.assignElderId === elder.id ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.assignElderId === elder.id ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.assignElderId = elder.id), (elder: Elder) => `assign-elder-${elder.id}`)
          Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showAssign = false); Button('确认分配').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.assign()) }.width('100%')
        }.width(this.compactWidth ? '90%' : 420).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      if (this.showItemCreate) Row() {
        Column({ space: 12 }) {
          Text('添加护理项目').fontSize(20).fontWeight(FontWeight.Medium)
          TextInput({ placeholder: '项目名称，例如每日巡视', text: $$this.itemTitle }).height(42)
          TextInput({ placeholder: '频率，例如每日 2 次', text: $$this.itemFrequency }).height(42)
          Row({ space: 10 }) { Button('取消').layoutWeight(1).height(40).onClick(() => this.showItemCreate = false); Button('保存').layoutWeight(1).height(40).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.addItem()) }.width('100%')
        }.width(this.compactWidth ? '90%' : 420).padding(24).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      }.width('100%').height('100%').backgroundColor('#66000000').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%')
  }
}
