import ApiClient from '../../network/ApiClient';

interface AIModelConfig {
  id?: number; role_scope: string; name: string; provider: string; base_url: string; model: string; system_prompt: string;
  context_window: number; temperature: number; enabled: boolean; allowed: boolean; is_default: boolean; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; api_key_configured?: boolean; rag_api_key_configured?: boolean;
}
interface AIConfigPage { list: AIModelConfig[]; }
interface AIConfigRequest { role_scope: string; name: string; provider: string; base_url: string; model: string; api_key: string; system_prompt: string; rag_enabled: boolean; rag_base_url: string; rag_dataset_id: string; enabled: boolean; allowed: boolean; is_default: boolean; }

@ComponentV2
export struct WideModelManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local configs: AIModelConfig[] = [];
  @Local selectedRole: string = 'caregiver';
  @Local configId: number = 0;
  @Local provider: string = 'local';
  @Local baseUrl: string = '';
  @Local modelName: string = 'kxb-local';
  @Local apiKey: string = '';
  @Local systemPrompt: string = '你是康小伴智慧康养护理平台的照护助理，回答谨慎、贴题，仅作参考，不做临床诊断。';
  @Local ragEnabled: boolean = false;
  @Local ragBaseUrl: string = '';
  @Local ragDatasetId: string = '';
  @Local saved: boolean = false;
  @Local error: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    try {
      const response = await ApiClient.get<AIConfigPage>('/admin/ai/configs');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.configs = response.data.list ?? []; this.selectRole(this.selectedRole);
    } catch (_error) { this.error = 'AI 配置加载失败'; }
  }

  private selectRole(role: string): void {
    this.selectedRole = role;
    const row: AIModelConfig | undefined = this.configs.find((item: AIModelConfig) => item.role_scope === role && item.is_default) ?? this.configs.find((item: AIModelConfig) => item.role_scope === role);
    this.configId = row?.id ?? 0; this.provider = row?.provider ?? 'local'; this.baseUrl = row?.base_url ?? ''; this.modelName = row?.model ?? 'kxb-local'; this.systemPrompt = row?.system_prompt ?? this.systemPrompt; this.ragEnabled = row?.rag_enabled ?? false; this.ragBaseUrl = row?.rag_base_url ?? ''; this.ragDatasetId = row?.rag_dataset_id ?? ''; this.apiKey = '';
  }

  private async save(): Promise<void> {
    const payload: AIConfigRequest = { role_scope: this.selectedRole, name: this.selectedRole === 'doctor' ? '医师默认模型' : '护工默认模型', provider: this.provider, base_url: this.baseUrl.trim(), model: this.modelName.trim(), api_key: this.apiKey, system_prompt: this.systemPrompt.trim(), rag_enabled: this.ragEnabled, rag_base_url: this.ragBaseUrl.trim(), rag_dataset_id: this.ragDatasetId.trim(), enabled: true, allowed: true, is_default: true };
    const response = this.configId > 0 ? await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${this.configId}`, payload) : await ApiClient.post<AIModelConfig>('/admin/ai/configs', payload);
    if (response.code !== 0) { this.error = response.msg || 'AI 配置保存失败'; return; }
    this.saved = true; this.apiKey = ''; await this.load();
  }

  @Builder
  private configSection() {
    Column({ space: 14 }) {
      Text('康小伴 AI 配置').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text('护工和医师使用独立模型、API 与系统提示词；密钥只在服务端保存。').fontSize(11).fontColor($r('sys.color.font_secondary'))
      Row({ space: 10 }) { Button('护工 AI').layoutWeight(1).height(38).backgroundColor(this.selectedRole === 'caregiver' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.selectedRole === 'caregiver' ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.selectRole('caregiver')); Button('医师 AI').layoutWeight(1).height(38).backgroundColor(this.selectedRole === 'doctor' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary')).fontColor(this.selectedRole === 'doctor' ? Color.White : $r('sys.color.font_secondary')).onClick(() => this.selectRole('doctor')) }.width('100%')
      Row({ space: 14 }) { Column({ space: 6 }) { Text('Provider').fontSize(12).fontColor($r('sys.color.font_secondary')); Text(this.provider).fontSize(14).padding(12).borderRadius(6).border({ width: 0.5, color: $r('sys.color.comp_divider') }).onClick(() => this.provider = this.provider === 'local' ? 'http' : 'local') }.layoutWeight(1).alignItems(HorizontalAlign.Start); Column({ space: 6 }) { Text('模型名称').fontSize(12).fontColor($r('sys.color.font_secondary')); TextInput({ text: $$this.modelName, placeholder: '例如 qwen-plus' }).height(42).fontSize(13) }.layoutWeight(1).alignItems(HorizontalAlign.Start) }.width('100%')
      TextInput({ placeholder: 'API Base URL', text: $$this.baseUrl }).height(42)
      TextInput({ placeholder: 'API Key（留空表示保留原密钥）', text: $$this.apiKey }).height(42).type(InputType.Password)
      TextArea({ placeholder: '系统提示词', text: $$this.systemPrompt }).height(120).fontSize(13)
      Row({ space: 8 }) { Button(this.ragEnabled ? 'RAG 已启用' : 'RAG 未启用').height(34).fontSize(12).onClick(() => this.ragEnabled = !this.ragEnabled); Text('Dify RAG 先保留配置，检索适配后启用').fontSize(11).fontColor($r('sys.color.font_tertiary')) }.width('100%').alignItems(VerticalAlign.Center)
      if (this.ragEnabled) { TextInput({ placeholder: 'Dify RAG URL', text: $$this.ragBaseUrl }).height(42); TextInput({ placeholder: '知识库 ID', text: $$this.ragDatasetId }).height(42) }
      Row() { Button(this.saved ? '已保存' : '保存配置').height(38).fontSize(13).fontColor(Color.White).backgroundColor($r('app.color.brand_blue')).onClick(() => this.save()); Blank().layoutWeight(1); Text(this.configId > 0 ? '已连接服务端配置' : '尚未创建此角色配置').fontSize(10).fontColor($r('sys.color.font_tertiary')) }.width('100%')
    }.width('100%').padding(18).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(14).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  build() {
    Scroll(this.scroller) { Column({ space: 20 }) {
      this.configSection()
      if (this.error.length > 0) Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
      Column({ space: 12 }) {
        Text('当前已配置模型').fontSize(18).fontWeight(FontWeight.Medium)
        if (this.configs.length === 0) {
          Text('暂无模型配置，请先选择护工 AI 或医师 AI 保存配置。').fontSize(12).fontColor($r('sys.color.font_secondary')).padding(16).width('100%').backgroundColor($r('sys.color.comp_background_primary')).borderRadius(12)
        } else {
          ForEach(this.configs, (item: AIModelConfig) => Column({ space: 8 }) {
            Row({ space: 10 }) {
              Column() { SymbolGlyph($r('sys.symbol.AI_model')).fontSize(20).fontColor([$r('app.color.brand_blue')]) }.width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(10)
              Column({ space: 3 }) { Text(item.role_scope === 'doctor' ? '医师 AI' : '护工 AI').fontSize(14).fontWeight(FontWeight.Medium); Text(item.name).fontSize(11).fontColor($r('sys.color.font_secondary')) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(item.api_key_configured ? '密钥已配置' : '未配置密钥').fontSize(11).fontColor(item.api_key_configured ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
            }.width('100%')
            Text(`${item.provider} / ${item.model}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.width('100%').padding(14).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') }), (item: AIModelConfig) => `ai-config-${item.id}`)
        }
      }.width('100%').padding(16).backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(14)
    }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28, top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight }) }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
