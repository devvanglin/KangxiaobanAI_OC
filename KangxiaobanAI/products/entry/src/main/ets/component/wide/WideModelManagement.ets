import ApiClient from '../../network/ApiClient';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

interface AIModelConfig {
  id?: number; role_scope: string; name: string; provider: string; base_url: string; model: string; system_prompt: string;
  context_window: number; temperature: number; enabled: boolean; allowed: boolean; is_default: boolean; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; api_key_configured?: boolean; rag_api_key_configured?: boolean;
}
interface AIConfigPage { list: AIModelConfig[]; }
interface AIConfigRequest { role_scope: string; name: string; provider: string; base_url: string; model: string; api_key: string; system_prompt: string; rag_enabled: boolean; rag_base_url: string; rag_dataset_id: string; enabled: boolean; allowed: boolean; is_default: boolean; }
interface AIUsageSummary { total_tokens: number; today_calls: number; avg_daily_calls: number; rag_calls: number; }
interface RAGDataset { id: string; name: string; document_count: number; }
interface ProviderModel { id: string; }
interface StatCardParam { label: string; value: string; }

const DARK_BUTTON_BG: string = '#1D63ED';
const DEFAULT_SYSTEM_PROMPT: string = '你是康小伴智慧康养护理平台的照护助理，回答谨慎、贴题，仅作参考，不做临床诊断。';

@ComponentV2
export struct WideModelManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local configs: AIModelConfig[] = [];
  @Local selectedRole: string = 'caregiver';
  @Local configId: number = 0;
  @Local provider: string = 'local';
  @Local baseUrl: string = '';
  @Local modelName: string = 'kxb-local';
  @Local apiKey: string = '';
  @Local systemPrompt: string = DEFAULT_SYSTEM_PROMPT;
  @Local ragEnabled: boolean = false;
  @Local ragBaseUrl: string = '';
  @Local ragDatasetId: string = '';
  @Local editorEnabled: boolean = true;
  @Local showEditor: boolean = false;
  @Local editorFetched: ProviderModel[] = [];
  @Local editorFetching: boolean = false;
  @Local editorFetchHint: string = '';
  @Local showPrompts: boolean = false;
  @Local promptRole: string = 'caregiver';
  @Local promptText: string = '';
  @Local promptError: string = '';
  @Local sourceRole: string = 'caregiver';
  @Local sourceModels: ProviderModel[] = [];
  @Local sourceLoading: boolean = false;
  @Local sourceError: string = '';
  @Local ragDatasets: RAGDataset[] = [];
  @Local ragLoading: boolean = false;
  @Local ragError: string = '';
  @Local saved: boolean = false;
  @Local error: string = '';
  @Local usage: AIUsageSummary = { total_tokens: 0, today_calls: 0, avg_daily_calls: 0, rag_calls: 0 };
  @Local usageLoaded: boolean = false;

  aboutToAppear(): void {
    this.load();
    this.loadUsage();
    this.loadRagDatasets();
    this.loadSourceModels();
  }

  private async load(): Promise<void> {
    try {
      const response = await ApiClient.get<AIConfigPage>('/admin/ai/configs');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.configs = response.data.list ?? [];
    } catch (_error) { this.error = 'AI 配置加载失败'; }
  }

  private async loadUsage(): Promise<void> {
    try {
      const response = await ApiClient.get<AIUsageSummary>('/admin/ai/usage/summary');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.usage = response.data;
      this.usageLoaded = true;
    } catch (_error) { this.usageLoaded = false; }
  }

  private async loadRagDatasets(): Promise<void> {
    this.ragLoading = true;
    this.ragError = '';
    try {
      const response = await ApiClient.get<RAGDataset[]>('/admin/ai/rag/datasets');
      if (response.code !== 0 || response.data === undefined) {
        this.ragError = response.msg.length > 0 ? response.msg : '知识库列表获取失败';
        this.ragDatasets = [];
      } else {
        this.ragDatasets = response.data;
      }
    } catch (error) {
      this.ragError = error instanceof Error && error.message.length > 0 ? error.message : '知识库列表获取失败';
      this.ragDatasets = [];
    }
    this.ragLoading = false;
  }

  private async loadSourceModels(): Promise<void> {
    const role: string = this.sourceRole;
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    if (config === undefined || config.provider !== 'http' || config.base_url.trim().length === 0) {
      this.sourceModels = [];
      this.sourceError = config === undefined ? '该角色尚未创建模型配置' : '当前为本地模型，无需获取远程列表';
      return;
    }
    this.sourceLoading = true;
    this.sourceError = '';
    try {
      const response = await ApiClient.get<ProviderModel[]>(`/admin/ai/llm/models?role=${role}`);
      if (this.sourceRole !== role) { return; }
      if (response.code !== 0 || response.data === undefined) {
        this.sourceError = response.msg.length > 0 ? response.msg : '模型列表获取失败';
        this.sourceModels = [];
      } else {
        this.sourceModels = response.data;
        if (response.data.length === 0) { this.sourceError = '模型服务未返回任何模型'; }
      }
    } catch (error) {
      if (this.sourceRole !== role) { return; }
      this.sourceError = error instanceof Error && error.message.length > 0 ? error.message : '模型列表获取失败';
      this.sourceModels = [];
    }
    this.sourceLoading = false;
  }

  private defaultConfigOfRole(role: string): AIModelConfig | undefined {
    return this.configs.find((item: AIModelConfig) => item.role_scope === role && item.is_default) ??
      this.configs.find((item: AIModelConfig) => item.role_scope === role);
  }

  private bindingsOf(datasetId: string): string[] {
    return this.configs
      .filter((item: AIModelConfig) => item.rag_enabled && item.rag_dataset_id === datasetId)
      .map((item: AIModelConfig) => item.role_scope);
  }

  private roleLabel(role: string): string {
    return role === 'doctor' ? '医师 AI' : '护工 AI';
  }

  private sourceTabs(): WideSlidingCapsuleItem[] {
    return [
      { title: '护工', index: 0 },
      { title: '医师', index: 1 },
      { title: '提示词', index: 2 }
    ];
  }

  private onSourceTab(index: number): void {
    if (index === 2) {
      this.openPromptDialog();
      return;
    }
    const role: string = index === 1 ? 'doctor' : 'caregiver';
    if (role === this.sourceRole) { return; }
    this.sourceRole = role;
    this.loadSourceModels();
  }

  private appliedModelId(): string {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(this.sourceRole);
    return config !== undefined ? config.model : '';
  }

  private async applyModel(modelId: string): Promise<void> {
    const item: AIModelConfig | undefined = this.defaultConfigOfRole(this.sourceRole);
    if (item === undefined || item.id === undefined) {
      this.sourceError = '该角色尚未创建模型配置，请先在「编辑模型索引」中保存';
      return;
    }
    const payload: AIConfigRequest = {
      role_scope: item.role_scope, name: item.name, provider: item.provider, base_url: item.base_url,
      model: modelId, api_key: '', system_prompt: item.system_prompt, rag_enabled: item.rag_enabled,
      rag_base_url: item.rag_base_url, rag_dataset_id: item.rag_dataset_id,
      enabled: item.enabled, allowed: item.allowed, is_default: item.is_default
    };
    const response = await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${item.id}`, payload);
    if (response.code !== 0) { this.sourceError = response.msg || '模型应用失败'; return; }
    this.sourceError = '';
    await this.load();
  }

  private async fetchEditorModels(): Promise<void> {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(this.selectedRole);
    if (config === undefined || config.provider !== 'http' || config.base_url.trim().length === 0) {
      this.editorFetched = [];
      this.editorFetchHint = '请先保存该角色的 vLLM 连接后再获取模型';
      return;
    }
    if (this.baseUrl.trim() !== config.base_url.trim()) {
      this.editorFetched = [];
      this.editorFetchHint = 'Base URL 已修改，请先保存配置再获取模型';
      return;
    }
    this.editorFetching = true;
    this.editorFetchHint = '';
    try {
      const response = await ApiClient.get<ProviderModel[]>(`/admin/ai/llm/models?role=${this.selectedRole}`);
      if (response.code !== 0 || response.data === undefined) {
        this.editorFetched = [];
        this.editorFetchHint = response.msg.length > 0 ? response.msg : '模型获取失败';
      } else {
        this.editorFetched = response.data;
        if (response.data.length === 0) { this.editorFetchHint = '模型服务未返回任何模型'; }
      }
    } catch (_error) {
      this.editorFetched = [];
      this.editorFetchHint = '模型获取失败，请检查连接';
    }
    this.editorFetching = false;
  }

  /** 千分位格式化，用于 token 与调用次数展示。 */
  private formatCount(value: number): string {
    const rounded: number = Math.round(value);
    const sign: string = rounded < 0 ? '-' : '';
    const digits: string = Math.abs(rounded).toString();
    let grouped: string = '';
    for (let i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 === 0) { grouped += ','; }
      grouped += digits[i];
    }
    return sign + grouped;
  }

  private usageValue(value: number): string {
    return this.usageLoaded ? this.formatCount(value) : '--';
  }

  private avgCallsValue(): string {
    if (!this.usageLoaded) { return '--'; }
    return `${this.usage.avg_daily_calls.toFixed(1)} 次/日`;
  }

  private async requestPayload(): Promise<AIConfigRequest> {
    return {
      role_scope: this.selectedRole,
      name: this.selectedRole === 'doctor' ? '医师默认模型' : '护工默认模型',
      provider: this.provider, base_url: this.baseUrl.trim(), model: this.modelName.trim(),
      api_key: this.apiKey, system_prompt: this.systemPrompt.trim(),
      rag_enabled: this.ragEnabled, rag_base_url: this.ragBaseUrl.trim(), rag_dataset_id: this.ragDatasetId.trim(),
      enabled: this.editorEnabled, allowed: true, is_default: true
    };
  }

  private async save(): Promise<void> {
    const payload: AIConfigRequest = await this.requestPayload();
    const response = this.configId > 0 ? await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${this.configId}`, payload) : await ApiClient.post<AIModelConfig>('/admin/ai/configs', payload);
    if (response.code !== 0) { this.error = response.msg || 'AI 配置保存失败'; return; }
    this.error = '';
    this.saved = true;
    this.showEditor = false;
    this.apiKey = '';
    await this.load();
    this.loadRagDatasets();
    this.loadSourceModels();
  }

  private async removeSelected(): Promise<void> {
    if (this.configId <= 0) { return; }
    const response = await ApiClient.delete<Object>(`/admin/ai/configs/${this.configId}`);
    if (response.code !== 0) { this.error = response.msg || 'AI 配置删除失败'; return; }
    this.error = '';
    this.configId = 0;
    this.showEditor = false;
    await this.load();
    this.loadRagDatasets();
    this.loadSourceModels();
  }

  private selectEditorRole(role: string): void {
    this.selectedRole = role;
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    if (config !== undefined) {
      this.configId = config.id ?? 0;
      this.provider = config.provider;
      this.baseUrl = config.base_url;
      this.modelName = config.model;
      this.systemPrompt = config.system_prompt;
      this.ragEnabled = config.rag_enabled;
      this.ragBaseUrl = config.rag_base_url;
      this.ragDatasetId = config.rag_dataset_id;
      this.editorEnabled = config.enabled;
    } else {
      this.configId = 0;
      this.provider = 'local';
      this.baseUrl = '';
      this.modelName = 'kxb-local';
      this.systemPrompt = DEFAULT_SYSTEM_PROMPT;
      this.ragEnabled = false;
      this.ragBaseUrl = '';
      this.ragDatasetId = '';
      this.editorEnabled = true;
    }
    this.apiKey = '';
    this.editorFetched = [];
    this.editorFetchHint = '';
    this.saved = false;
  }

  private openEditor(): void {
    this.error = '';
    this.saved = false;
    this.selectEditorRole(this.sourceRole);
    this.showEditor = true;
  }

  private openPromptDialog(): void {
    this.promptRole = this.sourceRole;
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(this.promptRole);
    this.promptText = config !== undefined ? config.system_prompt : '';
    this.promptError = '';
    this.saved = false;
    this.showPrompts = true;
  }

  private selectPromptRole(role: string): void {
    this.promptRole = role;
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    this.promptText = config !== undefined ? config.system_prompt : '';
    this.promptError = '';
    this.saved = false;
  }

  private async savePrompt(): Promise<void> {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(this.promptRole);
    if (config === undefined || config.id === undefined) {
      this.promptError = '该角色尚未创建模型配置，请先在「编辑模型索引」中保存';
      return;
    }
    const payload: AIConfigRequest = {
      role_scope: config.role_scope, name: config.name, provider: config.provider, base_url: config.base_url,
      model: config.model, api_key: '', system_prompt: this.promptText.trim(), rag_enabled: config.rag_enabled,
      rag_base_url: config.rag_base_url, rag_dataset_id: config.rag_dataset_id,
      enabled: config.enabled, allowed: config.allowed, is_default: config.is_default
    };
    const response = await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${config.id}`, payload);
    if (response.code !== 0) { this.promptError = response.msg || '提示词保存失败'; return; }
    this.promptError = '';
    this.saved = true;
    this.showPrompts = false;
    await this.load();
  }

  @Builder
  private statCard($$: StatCardParam) {
    Column({ space: 6 }) {
      Text($$.label).fontSize(12).fontColor($r('sys.color.font_secondary'))
      Text($$.value).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.alignItems(HorizontalAlign.Start)
      .width('100%').padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private statCards() {
    if (this.compactWidth) {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Row() { this.statCard({ label: '总消耗 Token', value: this.usageValue(this.usage.total_tokens) }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
          Row() { this.statCard({ label: '今日调用次数', value: this.usageValue(this.usage.today_calls) }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        }.width('100%')
        Row({ space: 12 }) {
          Row() { this.statCard({ label: '平均请求次数', value: this.avgCallsValue() }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
          Row() { this.statCard({ label: 'RAG 知识库调用次数', value: this.usageValue(this.usage.rag_calls) }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        }.width('100%')
      }.width('100%')
    } else {
      Row({ space: 12 }) {
        Row() { this.statCard({ label: '总消耗 Token', value: this.usageValue(this.usage.total_tokens) }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        Row() { this.statCard({ label: '今日调用次数', value: this.usageValue(this.usage.today_calls) }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        Row() { this.statCard({ label: '平均请求次数', value: this.avgCallsValue() }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        Row() { this.statCard({ label: 'RAG 知识库调用次数', value: this.usageValue(this.usage.rag_calls) }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
      }.width('100%')
    }
  }

  @Builder
  private statusBadge(enabled: boolean) {
    Text(enabled ? '已启用' : '已停用')
      .fontSize(11).fontColor(enabled ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(10)
      .backgroundColor(enabled ? '#E8F5EE' : $r('sys.color.comp_background_secondary'))
  }

  @Builder
  private actionText(label: string, danger: boolean, onTap: () => void) {
    Text(label).fontSize(13).fontColor(danger ? $r('app.color.doctor_workspace_danger') : $r('app.color.brand_blue'))
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .onClick(() => onTap())
  }

  /** 左 3/4：从 Dify 获取的知识库清单。 */
  @Builder
  private ragLibraryCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('RAG 知识库').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Text('从 Dify 获取').fontSize(11).fontColor($r('sys.color.font_tertiary'))
        Blank()
        this.actionText('刷新', false, () => this.loadRagDatasets())
      }.width('100%').alignItems(VerticalAlign.Center)
      if (this.ragLoading) {
        Text('正在获取知识库列表…').fontSize(12).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 16, bottom: 16 })
      } else if (this.ragError.length > 0) {
        Text(this.ragError).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
          .width('100%').padding({ top: 12, bottom: 4 })
        this.actionText('重试', false, () => this.loadRagDatasets())
      } else if (this.ragDatasets.length === 0) {
        Text('未获取到知识库，请确认 Dify 服务中已创建知识库。')
          .fontSize(12).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 16, bottom: 16 })
      } else {
        ForEach(this.ragDatasets, (item: RAGDataset, index: number) => {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(item.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`ID ${item.id} · ${item.document_count} 个文档`)
                .fontSize(11).fontColor($r('sys.color.font_tertiary'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            ForEach(this.bindingsOf(item.id), (role: string) => {
              Text(role === 'doctor' ? '医师绑定' : '护工绑定')
                .fontSize(10).fontColor($r('app.color.brand_blue'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10).backgroundColor('#E8F0FE')
            }, (role: string) => `binding-${item.id}-${role}`)
          }.width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 10, bottom: 10 })
          if (index < this.ragDatasets.length - 1) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          }
        }, (item: RAGDataset) => `rag-ds-${item.id}`)
      }
    }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  /** 右 1/4：从 vLLM 获取的模型清单，带角色胶囊与提示词入口。 */
  @Builder
  private modelSourceCard() {
    Column({ space: 12 }) {
      Text('模型获取').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      WideSlidingCapsule({
        items: this.sourceTabs(),
        selectedIndex: this.sourceRole === 'doctor' ? 1 : 0,
        itemWidth: 60,
        onSelect: (index: number) => this.onSourceTab(index)
      })
      if (this.sourceLoading) {
        Text('正在获取模型列表…').fontSize(12).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 12, bottom: 12 })
      } else if (this.sourceError.length > 0) {
        Text(this.sourceError).fontSize(12).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 8, bottom: 4 })
        this.actionText('重试', false, () => this.loadSourceModels())
      } else {
        ForEach(this.sourceModels, (item: ProviderModel, index: number) => {
          Row({ space: 8 }) {
            Text(item.id).fontSize(13).fontColor($r('sys.color.font_primary'))
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.appliedModelId() === item.id) {
              Text('使用中').fontSize(10).fontColor($r('app.color.doctor_workspace_success'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(10).backgroundColor('#E8F5EE')
            }
          }.width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => this.applyModel(item.id))
          if (index < this.sourceModels.length - 1) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          }
        }, (item: ProviderModel) => `source-model-${item.id}`)
      }
      Text('点击模型应用到当前角色').fontSize(11).fontColor($r('sys.color.font_tertiary'))
        .width('100%')
    }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private editorDialog() {
    Column({ space: 12 }) {
      Text('编辑模型索引').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Button('护工 AI').layoutWeight(1).height(36)
              .backgroundColor(this.selectedRole === 'caregiver' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
              .fontColor(this.selectedRole === 'caregiver' ? Color.White : $r('sys.color.font_secondary'))
              .onClick(() => this.selectEditorRole('caregiver'))
            Button('医师 AI').layoutWeight(1).height(36)
              .backgroundColor(this.selectedRole === 'doctor' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
              .fontColor(this.selectedRole === 'doctor' ? Color.White : $r('sys.color.font_secondary'))
              .onClick(() => this.selectEditorRole('doctor'))
          }.width('100%')
          Row({ space: 14 }) {
            Column({ space: 6 }) {
              Text('Provider').fontSize(12).fontColor($r('sys.color.font_secondary'))
              Text(this.provider === 'local' ? '本地模型' : 'vLLM 兼容')
                .fontSize(14).padding(10).borderRadius(6)
                .border({ width: 0.5, color: $r('sys.color.comp_divider') })
                .onClick(() => this.provider = this.provider === 'local' ? 'http' : 'local')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 6 }) {
              Text('模型名称').fontSize(12).fontColor($r('sys.color.font_secondary'))
              TextInput({ text: $$this.modelName, placeholder: '例如 Qwen2.5-7B-Instruct' }).height(40).fontSize(13)
            }.layoutWeight(2).alignItems(HorizontalAlign.Start)
          }.width('100%')
          if (this.provider === 'http') {
            Row({ space: 8 }) {
              TextInput({ placeholder: 'vLLM API Base URL', text: $$this.baseUrl }).height(40).layoutWeight(1)
              Button('获取模型').height(40).fontSize(13)
                .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
                .onClick(() => this.fetchEditorModels())
            }.width('100%')
            if (this.editorFetching) {
              Text('正在获取模型…').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
            } else if (this.editorFetchHint.length > 0) {
              Text(this.editorFetchHint).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
            }
            if (this.editorFetched.length > 0) {
              Scroll() {
                Column({ space: 4 }) {
                  ForEach(this.editorFetched, (item: ProviderModel) => {
                    Text(item.id).fontSize(12).fontColor($r('sys.color.font_primary'))
                      .padding({ top: 6, bottom: 6, left: 10, right: 10 })
                      .borderRadius(6).backgroundColor($r('sys.color.comp_background_secondary'))
                      .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .onClick(() => { this.modelName = item.id; })
                  }, (item: ProviderModel) => `editor-model-${item.id}`)
                }.width('100%').alignItems(HorizontalAlign.Start)
              }.width('100%').constraintSize({ maxHeight: 110 }).scrollBar(BarState.Off)
            }
          } else {
            TextInput({ placeholder: 'API Base URL', text: $$this.baseUrl }).height(40)
          }
          TextInput({ placeholder: 'API Key（留空表示保留原密钥）', text: $$this.apiKey }).height(40).type(InputType.Password)
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Text('Dify RAG 知识库连接').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).width('100%')
          Row({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.ragEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.ragEnabled = isOn)
            Text('启用 Dify RAG').fontSize(13).fontColor($r('sys.color.font_primary'))
            Blank()
            Text('检索已接入对话链路').fontSize(11).fontColor($r('sys.color.font_tertiary'))
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.ragEnabled) {
            TextInput({ placeholder: 'Dify RAG URL', text: $$this.ragBaseUrl }).height(40)
            TextInput({ placeholder: '知识库 ID', text: $$this.ragDatasetId }).height(40)
          }
          Row({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.editorEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.editorEnabled = isOn)
            Text(this.editorEnabled ? '保存后启用该模型' : '保存后保持停用').fontSize(13).fontColor($r('sys.color.font_primary'))
          }.width('100%').alignItems(VerticalAlign.Center)
          Text(this.configId > 0 ? '已连接服务端配置，密钥留空则保留原值' : '保存后将创建该角色的新配置')
            .fontSize(11).fontColor($r('sys.color.font_tertiary'))
        }.width('100%')
      }.scrollBar(BarState.Off).constraintSize({ maxHeight: 460 }).width('100%')
      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 10 }) {
        if (this.configId > 0) {
          Text('删除配置').fontSize(13).fontColor($r('app.color.doctor_workspace_danger'))
            .padding({ left: 8, right: 8, top: 10, bottom: 10 })
            .onClick(() => this.removeSelected())
        }
        Blank()
        Button('取消').height(40).fontSize(13)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showEditor = false; this.error = ''; })
        Button(this.saved ? '已保存' : '保存配置').height(40).fontSize(13).layoutWeight(2)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.save())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 560).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  /** 提示词路由：不同角色的 AI 页面各自路由到该角色的模型与系统提示词。 */
  @Builder
  private promptDialog() {
    Column({ space: 12 }) {
      Text('提示词').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      Text('不同角色的 AI 页面各自路由到以下模型与系统提示词。')
        .fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
      Row({ space: 10 }) {
        Button('护工 AI').layoutWeight(1).height(36)
          .backgroundColor(this.promptRole === 'caregiver' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
          .fontColor(this.promptRole === 'caregiver' ? Color.White : $r('sys.color.font_secondary'))
          .onClick(() => this.selectPromptRole('caregiver'))
        Button('医师 AI').layoutWeight(1).height(36)
          .backgroundColor(this.promptRole === 'doctor' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
          .fontColor(this.promptRole === 'doctor' ? Color.White : $r('sys.color.font_secondary'))
          .onClick(() => this.selectPromptRole('doctor'))
      }.width('100%')
      Text(`路由模型：${this.defaultConfigOfRole(this.promptRole)?.model ?? '未配置'}`)
        .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      TextArea({ placeholder: '系统提示词', text: $$this.promptText }).height(140).fontSize(13)
      if (this.promptError.length > 0) {
        Text(this.promptError).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showPrompts = false; })
        Button(this.saved ? '已保存' : '保存提示词').layoutWeight(1).height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.savePrompt())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 480).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            Blank()
            Button('编辑模型索引').height(38).fontSize(13).borderRadius(8)
              .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
              .onClick(() => this.openEditor())
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.error.length > 0 && !this.showEditor) {
            Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          this.statCards()
          if (this.compactWidth) {
            Column({ space: 16 }) {
              this.ragLibraryCard()
              this.modelSourceCard()
            }.width('100%').alignItems(HorizontalAlign.Start)
          } else {
            Row({ space: 16 }) {
              Column() { this.ragLibraryCard() }.layoutWeight(3)
              Column() { this.modelSourceCard() }.layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Top)
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
      if (this.showPrompts) {
        Row() { this.promptDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
