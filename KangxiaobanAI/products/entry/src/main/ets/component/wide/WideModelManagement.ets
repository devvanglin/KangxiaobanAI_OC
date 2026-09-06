import ApiClient from '../../network/ApiClient';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

interface AIModelConfig {
  id?: number; role_scope: string; name: string; provider: string; base_url: string; model: string; system_prompt: string;
  context_window: number; temperature: number; enabled: boolean; allowed: boolean; is_default: boolean; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; api_key_configured?: boolean; rag_api_key_configured?: boolean;
  updated_at?: string;
}
interface AIConfigPage { list: AIModelConfig[]; }
interface AIConfigRequest { role_scope: string; name: string; provider: string; base_url: string; model: string; api_key: string; system_prompt: string; rag_enabled: boolean; rag_base_url: string; rag_dataset_id: string; enabled: boolean; allowed: boolean; is_default: boolean; }
interface AIUsageSummary { total_tokens: number; today_calls: number; avg_daily_calls: number; rag_calls: number; }
interface ModelUsageStat { model: string; today_calls: number; avg_duration_ms: number; success_rate: number; }
interface RAGDataset { id: string; name: string; description: string; document_count: number; word_count: number; }
interface ProviderModel { id: string; }
interface AIConnectionView {
  provider: string; base_url: string; api_key_configured: boolean; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; rag_api_key_configured: boolean; enabled: boolean;
}
interface AIConnectionRequest {
  provider: string; base_url: string; api_key: string; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; rag_api_key: string; enabled: boolean;
}
interface StatTagParam { label: string; value: string; }

const DARK_BUTTON_BG: string = '#1D63ED';
const SECTION_IDS: string[] = ['models', 'prompts', 'mcp', 'skills', 'rag'];
const SECTION_LABELS: string[] = ['模型管理', '提示词库', 'MCP 管理', 'Skills 管理', 'RAG 知识库'];

@ComponentV2
export struct WideModelManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Local configs: AIModelConfig[] = [];
  @Local activeSection: string = 'models';
  @Local promptFilter: string = 'all';
  @Local connProvider: string = 'local';
  @Local connBaseUrl: string = '';
  @Local connApiKey: string = '';
  @Local connRagEnabled: boolean = false;
  @Local connRagBaseUrl: string = '';
  @Local connRagDatasetId: string = '';
  @Local connRagApiKey: string = '';
  @Local connEnabled: boolean = true;
  @Local savedConnBaseUrl: string = '';
  @Local savedConnProvider: string = 'local';
  @Local showEditor: boolean = false;
  @Local editorFetched: ProviderModel[] = [];
  @Local editorFetching: boolean = false;
  @Local editorFetchHint: string = '';
  @Local showPrompts: boolean = false;
  @Local promptRole: string = 'caregiver';
  @Local promptText: string = '';
  @Local promptModel: string = '';
  @Local promptError: string = '';
  @Local sourceModels: ProviderModel[] = [];
  @Local sourceLoading: boolean = false;
  @Local sourceError: string = '';
  @Local ragDatasets: RAGDataset[] = [];
  @Local ragLoading: boolean = false;
  @Local ragError: string = '';
  @Local modelStats: ModelUsageStat[] = [];
  @Local modelStatsLoaded: boolean = false;
  @Local saved: boolean = false;
  @Local error: string = '';
  @Local usage: AIUsageSummary = { total_tokens: 0, today_calls: 0, avg_daily_calls: 0, rag_calls: 0 };
  @Local usageLoaded: boolean = false;

  aboutToAppear(): void {
    this.load();
    this.loadUsage();
    this.loadModelStats();
    this.loadConnection();
    this.loadRagDatasets();
    this.loadSourceModels();
  }

  /** 页级提示统一走系统 Toast：白底、短暂显示后自动消失。 */
  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (_error) {
      // Toast 展示失败时静默，不打断页面。
    }
  }

  private async load(): Promise<void> {
    try {
      const response = await ApiClient.get<AIConfigPage>('/admin/ai/configs');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.configs = response.data.list ?? [];
    } catch (_error) { this.showToast('AI 配置加载失败'); }
  }

  private async loadUsage(): Promise<void> {
    try {
      const response = await ApiClient.get<AIUsageSummary>('/admin/ai/usage/summary');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.usage = response.data;
      this.usageLoaded = true;
    } catch (_error) { this.usageLoaded = false; }
  }

  private async loadModelStats(): Promise<void> {
    try {
      const response = await ApiClient.get<ModelUsageStat[]>('/admin/ai/usage/models');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.modelStats = response.data;
      this.modelStatsLoaded = true;
    } catch (_error) { this.modelStatsLoaded = false; }
  }

  private async loadConnection(): Promise<void> {
    try {
      const response = await ApiClient.get<AIConnectionView>('/admin/ai/connection');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      const view: AIConnectionView = response.data;
      this.connProvider = view.provider;
      this.connBaseUrl = view.base_url;
      this.connRagEnabled = view.rag_enabled;
      this.connRagBaseUrl = view.rag_base_url;
      this.connRagDatasetId = view.rag_dataset_id;
      this.connEnabled = view.enabled;
      this.savedConnBaseUrl = view.base_url;
      this.savedConnProvider = view.provider;
    } catch (_error) { this.showToast('AI 连接加载失败'); }
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
    this.sourceLoading = true;
    this.sourceError = '';
    try {
      const response = await ApiClient.get<ProviderModel[]>('/admin/ai/llm/models');
      if (response.code !== 0 || response.data === undefined) {
        this.sourceError = response.msg.length > 0 ? response.msg : '模型列表获取失败';
        this.sourceModels = [];
      } else {
        this.sourceModels = response.data;
        if (response.data.length === 0) { this.sourceError = '模型服务未返回任何模型'; }
      }
    } catch (error) {
      this.sourceError = error instanceof Error && error.message.length > 0 ? error.message : '模型列表获取失败';
      this.sourceModels = [];
    }
    this.sourceLoading = false;
  }

  private defaultConfigOfRole(role: string): AIModelConfig | undefined {
    return this.configs.find((item: AIModelConfig) => item.role_scope === role && item.is_default) ??
      this.configs.find((item: AIModelConfig) => item.role_scope === role);
  }

  /** 已把该模型分配给哪些端的 AI。 */
  private usedByRoles(modelId: string): string[] {
    const roles: string[] = [];
    this.configs.forEach((item: AIModelConfig): void => {
      if (item.model === modelId && item.enabled && !roles.includes(item.role_scope)) {
        roles.push(item.role_scope);
      }
    });
    return roles;
  }

  private statOf(modelId: string): ModelUsageStat | undefined {
    return this.modelStats.find((item: ModelUsageStat) => item.model === modelId);
  }

  private roleLabel(role: string): string {
    return role === 'doctor' ? '医师 AI' : '护工 AI';
  }

  private roleShort(role: string): string {
    return role === 'doctor' ? '医师' : '护工';
  }

  private promptTabs(): WideSlidingCapsuleItem[] {
    return [
      { title: '护工 AI', index: 0 },
      { title: '医师 AI', index: 1 }
    ];
  }

  private updatedDateText(value?: string): string {
    const normalized: string = (value ?? '').replace('T', ' ');
    return normalized.length >= 10 ? normalized.slice(5, 10) : '--';
  }

  /** 全部模型的今日加权平均响应时间。 */
  private avgResponseText(): string {
    if (!this.usageLoaded) { return '--'; }
    let calls: number = 0;
    let weighted: number = 0;
    this.modelStats.forEach((item: ModelUsageStat): void => {
      calls += item.today_calls;
      weighted += item.today_calls * item.avg_duration_ms;
    });
    if (calls === 0) { return '--'; }
    return `${(weighted / calls / 1000).toFixed(1)}s`;
  }

  private visiblePromptRoles(): string[] {
    if (this.promptFilter === 'caregiver') { return ['caregiver']; }
    if (this.promptFilter === 'doctor') { return ['doctor']; }
    return ['caregiver', 'doctor'];
  }

  private async fetchEditorModels(): Promise<void> {
    if (this.connProvider !== 'http' || this.connBaseUrl.trim().length === 0) {
      this.editorFetched = [];
      this.editorFetchHint = '请先选择 vLLM 兼容并填写 Base URL，保存后即可获取模型';
      return;
    }
    if (this.connBaseUrl.trim() !== this.savedConnBaseUrl.trim() || this.connProvider !== this.savedConnProvider) {
      this.editorFetched = [];
      this.editorFetchHint = '连接信息已修改，请先保存配置再获取模型';
      return;
    }
    await this.loadSourceModels();
    this.editorFetched = this.sourceModels;
    if (this.editorFetched.length === 0 && this.sourceError.length === 0) {
      this.editorFetchHint = '模型服务未返回任何模型';
    }
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

  private async saveConnection(): Promise<void> {
    const payload: AIConnectionRequest = {
      provider: this.connProvider,
      base_url: this.connBaseUrl.trim(),
      api_key: this.connApiKey,
      rag_enabled: this.connRagEnabled,
      rag_base_url: this.connRagBaseUrl.trim(),
      rag_dataset_id: this.connRagDatasetId.trim(),
      rag_api_key: this.connRagApiKey,
      enabled: this.connEnabled
    };
    const response = await ApiClient.put<AIConnectionView>('/admin/ai/connection', payload);
    if (response.code !== 0) { this.error = response.msg || 'AI 连接保存失败'; return; }
    this.error = '';
    this.saved = true;
    this.showEditor = false;
    this.connApiKey = '';
    this.connRagApiKey = '';
    await this.loadConnection();
    this.loadRagDatasets();
    this.loadSourceModels();
  }

  /** 把某个 Dify 知识库设为机构当前使用的知识库。 */
  private async setConnectionDataset(datasetId: string): Promise<void> {
    const payload: AIConnectionRequest = {
      provider: this.connProvider,
      base_url: this.connBaseUrl.trim(),
      api_key: '',
      rag_enabled: true,
      rag_base_url: this.connRagBaseUrl.trim(),
      rag_dataset_id: datasetId,
      rag_api_key: '',
      enabled: this.connEnabled
    };
    const response = await ApiClient.put<AIConnectionView>('/admin/ai/connection', payload);
    if (response.code !== 0) { this.showToast(response.msg.length > 0 ? response.msg : '知识库切换失败'); return; }
    this.error = '';
    await this.loadConnection();
  }

  private openEditor(): void {
    this.error = '';
    this.saved = false;
    this.editorFetched = [];
    this.editorFetchHint = '';
    this.showEditor = true;
  }

  private openPromptDialog(role: string): void {
    this.selectPromptRole(role);
    this.showPrompts = true;
  }

  private selectPromptRole(role: string): void {
    this.promptRole = role;
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    this.promptText = config !== undefined ? config.system_prompt : '';
    this.promptModel = config !== undefined ? config.model : '';
    this.promptError = '';
    this.saved = false;
  }

  /** 把一端的模型与提示词复制到另一端。 */
  private async copyPrompt(fromRole: string): Promise<void> {
    const source: AIModelConfig | undefined = this.defaultConfigOfRole(fromRole);
    if (source === undefined) {
      this.showToast('该端尚未配置提示词');
      return;
    }
    const targetRole: string = fromRole === 'doctor' ? 'caregiver' : 'doctor';
    const target: AIModelConfig | undefined = this.defaultConfigOfRole(targetRole);
    if (target === undefined || target.id === undefined) {
      const payload: AIConfigRequest = {
        role_scope: targetRole,
        name: targetRole === 'doctor' ? '医师默认模型' : '护工默认模型',
        provider: source.provider, base_url: '', model: source.model, api_key: '',
        system_prompt: source.system_prompt, rag_enabled: false, rag_base_url: '', rag_dataset_id: '',
        enabled: true, allowed: true, is_default: true
      };
      const created = await ApiClient.post<AIModelConfig>('/admin/ai/configs', payload);
      if (created.code !== 0) { this.showToast(created.msg.length > 0 ? created.msg : '提示词复制失败'); return; }
    } else {
      const payload: AIConfigRequest = {
        role_scope: target.role_scope, name: target.name, provider: target.provider, base_url: target.base_url,
        model: source.model, api_key: '', system_prompt: source.system_prompt, rag_enabled: target.rag_enabled,
        rag_base_url: target.rag_base_url, rag_dataset_id: target.rag_dataset_id,
        enabled: target.enabled, allowed: target.allowed, is_default: target.is_default
      };
      const response = await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${target.id}`, payload);
      if (response.code !== 0) { this.showToast(response.msg.length > 0 ? response.msg : '提示词复制失败'); return; }
    }
    this.error = '';
    await this.load();
  }

  private async savePrompt(): Promise<void> {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(this.promptRole);
    const modelId: string = this.promptModel.trim();
    if (config === undefined || config.id === undefined) {
      if (modelId.length === 0) {
        this.promptError = '请先选择模型';
        return;
      }
      const payload: AIConfigRequest = {
        role_scope: this.promptRole,
        name: this.promptRole === 'doctor' ? '医师默认模型' : '护工默认模型',
        provider: this.connProvider, base_url: '', model: modelId, api_key: '',
        system_prompt: this.promptText.trim(), rag_enabled: false, rag_base_url: '', rag_dataset_id: '',
        enabled: true, allowed: true, is_default: true
      };
      const created = await ApiClient.post<AIModelConfig>('/admin/ai/configs', payload);
      if (created.code !== 0) { this.promptError = created.msg || '提示词保存失败'; return; }
    } else {
      const payload: AIConfigRequest = {
        role_scope: config.role_scope, name: config.name, provider: config.provider, base_url: config.base_url,
        model: modelId.length > 0 ? modelId : config.model, api_key: '',
        system_prompt: this.promptText.trim(), rag_enabled: config.rag_enabled,
        rag_base_url: config.rag_base_url, rag_dataset_id: config.rag_dataset_id,
        enabled: config.enabled, allowed: config.allowed, is_default: config.is_default
      };
      const response = await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${config.id}`, payload);
      if (response.code !== 0) { this.promptError = response.msg || '提示词保存失败'; return; }
    }
    this.promptError = '';
    this.saved = true;
    this.showPrompts = false;
    await this.load();
    this.loadModelStats();
  }

  // ===== 平台版式元素 =====

  @Builder
  private statTag($$: StatTagParam) {
    Column({ space: 4 }) {
      Text($$.label).fontSize(13).fontColor($r('sys.color.font_secondary'))
      Text($$.value).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }.alignItems(HorizontalAlign.Center)
      .layoutWeight(1)
      .padding({ top: 16, bottom: 16 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(10)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  private sectionTabs(): WideSlidingCapsuleItem[] {
    return [
      { title: '模型管理', index: 0 },
      { title: '提示词库', index: 1 },
      { title: 'MCP 管理', index: 2 },
      { title: 'Skills 管理', index: 3 },
      { title: 'RAG 知识库', index: 4 }
    ];
  }

  @Builder
  private sectionNav() {
    Row({ space: 10 }) {
      WideSlidingCapsule({
        items: this.sectionTabs(),
        selectedIndex: SECTION_IDS.indexOf(this.activeSection) < 0 ? 0 : SECTION_IDS.indexOf(this.activeSection),
        itemWidth: 112,
        onSelect: (index: number) => {
          this.activeSection = SECTION_IDS[index] ?? 'models';
        }
      })
      Blank()
      if (this.activeSection === 'models') {
        Button('编辑模型网关').height(36).fontSize(12.5).borderRadius(8)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.openEditor())
      } else if (this.activeSection === 'prompts') {
        Button('提示词设置').height(36).fontSize(12.5).borderRadius(8)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.openPromptDialog('caregiver'))
      } else if (this.activeSection === 'rag') {
        Button('连接设置').height(36).fontSize(12.5).borderRadius(8)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.openEditor())
      }
    }.width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private assignBadge(role: string) {
    Text(this.roleShort(role))
      .fontSize(11).fontColor($r('app.color.doctor_workspace_success'))
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(12).backgroundColor('#F0FDF4')
  }

  @Builder
  private modelStatCell(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label).fontSize(11).fontColor($r('sys.color.font_tertiary'))
      Text(value).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private cardLink(label: string, onTap: () => void) {
    Text(label).fontSize(12.5).fontColor($r('sys.color.font_secondary'))
      .onClick(() => onTap())
  }

  @Builder
  private modelCard(item: ProviderModel) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.id).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.usedByRoles(item.id).length === 0) {
          Text('未分配').fontSize(11).fontColor($r('sys.color.font_tertiary'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(12).backgroundColor($r('sys.color.comp_background_secondary'))
        } else {
          ForEach(this.usedByRoles(item.id), (role: string) => {
            this.assignBadge(role)
          }, (role: string) => `mc-${item.id}-${role}`)
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(`统一连接 · ${this.connProvider === 'local' ? '本地' : 'vLLM'}`)
        .fontSize(12).fontColor($r('sys.color.font_secondary'))
        .width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 8 }) {
        this.modelStatCell('今日调用',
          this.modelStatsLoaded ? this.formatCount(this.statOf(item.id)?.today_calls ?? 0) : '--')
        this.modelStatCell('平均响应', this.modelStatsLoaded ?
          ((this.statOf(item.id)?.today_calls ?? 0) > 0 ?
            `${((this.statOf(item.id)?.avg_duration_ms ?? 0) / 1000).toFixed(1)}s` : '--') : '--')
        this.modelStatCell('成功率', this.modelStatsLoaded ?
          ((this.statOf(item.id)?.today_calls ?? 0) > 0 ?
            `${(this.statOf(item.id)?.success_rate ?? 0).toFixed(1)}%` : '--') : '--')
      }.width('100%')
      Row({ space: 14 }) {
        this.cardLink('配置', () => this.openPromptDialog('caregiver'))
        this.cardLink('测试', () => {
          this.loadSourceModels();
          this.loadModelStats();
        })
      }.width('100%')
    }.width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(10)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private modelsModule() {
    Column({ space: 12 }) {
      if (this.sourceLoading) {
        Text('正在从统一连接获取模型列表…').fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
      } else if (this.sourceError.length > 0) {
        Column({ space: 8 }) {
          Text(this.sourceError).fontSize(13).fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center).width('100%')
          Text('重试').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.loadSourceModels())
        }.width('100%').padding({ top: 20, bottom: 20 })
      } else {
        GridRow({ columns: 12, gutter: 14 }) {
          ForEach(this.sourceModels, (item: ProviderModel) => {
            GridCol({ span: this.compactWidth ? 6 : 3 }) {
              this.modelCard(item)
            }
          }, (item: ProviderModel) => `model-card-${item.id}`)
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private filterChip(label: string, value: string) {
    Text(label)
      .fontSize(12.5)
      .fontColor(this.promptFilter === value ? Color.White : $r('sys.color.font_secondary'))
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(this.promptFilter === value ? $r('sys.color.font_primary') :
        $r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: this.promptFilter === value ? $r('sys.color.font_primary') :
        $r('sys.color.comp_divider') })
      .onClick(() => this.promptFilter = value)
  }

  @Builder
  private promptRow(role: string, isLast: boolean) {
    Row({ space: 12 }) {
      Text(this.roleLabel(role) + ' 对话')
        .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.roleShort(role) + '端').fontSize(11).fontColor($r('sys.color.font_secondary'))
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(10).backgroundColor($r('sys.color.comp_background_secondary'))
        .constraintSize({ minWidth: 64 })
      Text(this.defaultConfigOfRole(role)?.model ?? '--')
        .fontSize(13).fontColor($r('sys.color.font_primary'))
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('--').fontSize(13).fontColor($r('sys.color.font_secondary'))
        .constraintSize({ minWidth: 56 })
      Text(this.updatedDateText(this.defaultConfigOfRole(role)?.updated_at))
        .fontSize(13).fontColor($r('sys.color.font_secondary'))
        .constraintSize({ minWidth: 64 })
      Text(this.defaultConfigOfRole(role) === undefined ? '未配置' :
        (this.defaultConfigOfRole(role)!.enabled ? '启用' : '停用'))
        .fontSize(11).fontColor(this.defaultConfigOfRole(role)?.enabled ?
          $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor(this.defaultConfigOfRole(role)?.enabled ? '#F0FDF4' :
          $r('sys.color.comp_background_secondary'))
        .constraintSize({ minWidth: 56 })
      Row({ space: 12 }) {
        this.cardLink('编辑', () => this.openPromptDialog(role))
        this.cardLink('复制', () => this.copyPrompt(role))
      }
    }.width('100%')
    .padding({ top: 12, bottom: 12, left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    if (!isLast) {
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
    }
  }

  @Builder
  private promptsModule() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        this.filterChip('全部', 'all')
        this.filterChip('护工端', 'caregiver')
        this.filterChip('医师端', 'doctor')
      }.width('100%')
      Column({ space: 0 }) {
        Row({ space: 12 }) {
          Text('名称').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
          Text('分类').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
            .constraintSize({ minWidth: 64 })
          Text('模型').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
          Text('版本').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
            .constraintSize({ minWidth: 56 })
          Text('更新时间').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
            .constraintSize({ minWidth: 64 })
          Text('状态').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
            .constraintSize({ minWidth: 56 })
          Text('操作').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_secondary'))
        }.width('100%')
        .padding({ top: 10, bottom: 10, left: 14, right: 14 })
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .alignItems(VerticalAlign.Center)
        ForEach(this.visiblePromptRoles(), (role: string, index: number) => {
          this.promptRow(role, index === this.visiblePromptRoles().length - 1)
        }, (role: string) => `prompt-row-${role}`)
      }.width('100%')
      .borderRadius(10)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .clip(true)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ragCard(item: RAGDataset) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.name).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.connRagDatasetId === item.id) {
          Text('使用中').fontSize(11).fontColor($r('app.color.brand_blue'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(12).backgroundColor('#E8F0FE')
        } else {
          Text('未启用').fontSize(11).fontColor($r('sys.color.font_tertiary'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(12).backgroundColor($r('sys.color.comp_background_secondary'))
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(item.description.trim().length > 0 ? item.description : 'Dify 知识库')
        .fontSize(12.5).fontColor($r('sys.color.font_secondary'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 8 }) {
        this.modelStatCell('文档数量', `${this.formatCount(item.document_count)} 篇`)
        this.modelStatCell('总字符数', item.word_count > 0 ? `${this.formatCount(Math.round(item.word_count / 10000))} 万` : '--')
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 14 }) {
        if (this.connRagDatasetId === item.id) {
          Text('检索已接入对话链路').fontSize(12.5).fontColor($r('sys.color.font_secondary'))
        } else {
          this.cardLink('设为机构知识库', () => this.setConnectionDataset(item.id))
        }
        Blank()
        this.cardLink('连接设置', () => this.openEditor())
      }.width('100%')
    }.width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(10)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ragModule() {
    Column({ space: 12 }) {
      if (this.ragLoading) {
        Text('正在从 Dify 获取知识库列表…').fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
      } else if (this.ragError.length > 0) {
        Column({ space: 8 }) {
          Text(this.ragError).fontSize(13).fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center).width('100%')
          Text('重试').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.loadRagDatasets())
        }.width('100%').padding({ top: 20, bottom: 20 })
      } else if (this.ragDatasets.length === 0) {
        Text('未获取到知识库，请确认 Dify 服务中已创建知识库。')
          .fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
      } else {
        GridRow({ columns: 12, gutter: 14 }) {
          ForEach(this.ragDatasets, (item: RAGDataset) => {
            GridCol({ span: this.compactWidth ? 12 : 6 }) {
              this.ragCard(item)
            }
          }, (item: RAGDataset) => `rag-card-${item.id}`)
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private wipModule(title: string) {
    Column({ space: 12 }) {
      Text('「' + title + '」在当前版本规划中，尚未接入服务端。')
        .fontSize(13).fontColor($r('sys.color.font_secondary'))
        .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(10).border({ width: 0.5, color: $r('sys.color.comp_divider') })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 编辑模型网关：机构统一的模型服务连接与 Dify RAG 连接。 */
  @Builder
  private editorDialog() {
    Column({ space: 12 }) {
      Text('编辑模型网关').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 14 }) {
            Column({ space: 6 }) {
              Text('Provider').fontSize(12).fontColor($r('sys.color.font_secondary'))
              Text(this.connProvider === 'local' ? '本地模型' : 'vLLM 兼容')
                .fontSize(14).padding(10).borderRadius(6)
                .border({ width: 0.5, color: $r('sys.color.comp_divider') })
                .onClick(() => this.connProvider = this.connProvider === 'local' ? 'http' : 'local')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 6 }) {
              Text('连接状态').fontSize(12).fontColor($r('sys.color.font_secondary'))
              Row({ space: 8 }) {
                Toggle({ type: ToggleType.Switch, isOn: this.connEnabled })
                  .selectedColor($r('app.color.brand_blue'))
                  .onChange((isOn: boolean) => this.connEnabled = isOn)
                Text(this.connEnabled ? '已启用' : '已停用').fontSize(13).fontColor($r('sys.color.font_primary'))
              }.alignItems(VerticalAlign.Center)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          if (this.connProvider === 'http') {
            Row({ space: 8 }) {
              TextInput({ placeholder: '模型服务 Base URL（vLLM 等 OpenAI 兼容）', text: $$this.connBaseUrl })
                .height(40).layoutWeight(1)
              Button('获取模型').height(40).fontSize(13)
                .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
                .onClick(() => this.fetchEditorModels())
            }.width('100%')
            TextInput({ placeholder: 'API Key（留空表示保留原密钥）', text: $$this.connApiKey })
              .height(40).type(InputType.Password)
            if (this.editorFetching) {
              Text('正在获取模型…').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
            } else if (this.editorFetchHint.length > 0) {
              Text(this.editorFetchHint).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
            }
          }
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Text('Dify RAG 知识库连接').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).width('100%')
          Row({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.connRagEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.connRagEnabled = isOn)
            Text('启用 Dify RAG').fontSize(13).fontColor($r('sys.color.font_primary'))
            Blank()
            Text('检索已接入对话链路').fontSize(11).fontColor($r('sys.color.font_tertiary'))
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.connRagEnabled) {
            TextInput({ placeholder: 'Dify RAG URL', text: $$this.connRagBaseUrl }).height(40)
            TextInput({ placeholder: '知识库 ID', text: $$this.connRagDatasetId }).height(40)
            TextInput({ placeholder: 'RAG API Key（留空表示保留原密钥）', text: $$this.connRagApiKey })
              .height(40).type(InputType.Password)
          }
          Text('统一连接对全部端生效；护工/医师各自在「提示词」里分配模型与提示词。')
            .fontSize(11).fontColor($r('sys.color.font_tertiary'))
        }.width('100%')
      }.scrollBar(BarState.Off).constraintSize({ maxHeight: 420 }).width('100%')
      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showEditor = false; this.error = ''; })
        Button(this.saved ? '已保存' : '保存连接').layoutWeight(1).height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.saveConnection())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 520).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  /** 提示词路由：各端 AI 在统一连接下分配各自的模型与系统提示词。 */
  @Builder
  private promptDialog() {
    Column({ space: 12 }) {
      Text('提示词').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      Text('为该端 AI 分配模型并设置系统提示词。')
        .fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
      WideSlidingCapsule({
        items: this.promptTabs(),
        selectedIndex: this.promptRole === 'doctor' ? 1 : 0,
        itemWidth: 72,
        onSelect: (index: number) => this.selectPromptRole(index === 1 ? 'doctor' : 'caregiver')
      })
      Text('路由模型').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      if (this.sourceModels.length === 0) {
        Text(this.sourceError.length > 0 ? this.sourceError :
          `当前模型：${this.promptModel.length > 0 ? this.promptModel : '未分配'}`)
          .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      } else {
        Scroll() {
          Column({ space: 6 }) {
            ForEach(this.sourceModels, (item: ProviderModel) => {
              Row({ space: 8 }) {
                Text(item.id).fontSize(12).fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.promptModel === item.id) {
                  Text('已选择').fontSize(11).fontColor($r('app.color.brand_blue'))
                }
              }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .borderRadius(8)
                .border({ width: 0.5, color: this.promptModel === item.id ?
                  $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
                .backgroundColor(this.promptModel === item.id ? '#F0F5FF' :
                  $r('sys.color.comp_background_primary'))
                .onClick(() => this.promptModel = item.id)
            }, (item: ProviderModel) => `prompt-model-${item.id}`)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.constraintSize({ maxHeight: 130 }).scrollBar(BarState.Off).width('100%')
      }
      TextArea({ placeholder: '系统提示词', text: $$this.promptText }).height(120).fontSize(13)
      if (this.promptError.length > 0) {
        Text(this.promptError).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showPrompts = false; })
        Button(this.saved ? '已保存' : '保存').layoutWeight(1).height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.savePrompt())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 480).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column() {
          Column({ space: 24 }) {
            Row({ space: 10 }) {
              this.statTag({ label: '已接入', value: this.sourceModels.length.toString() })
              this.statTag({ label: '启用中', value: this.configs.filter((item: AIModelConfig) => item.enabled).length.toString() })
              this.statTag({ label: '今日调用', value: this.usageValue(this.usage.today_calls) })
              this.statTag({ label: '平均响应', value: this.avgResponseText() })
            }.width('100%')
            this.sectionNav()
            if (this.activeSection === 'models') {
              this.modelsModule()
            } else if (this.activeSection === 'prompts') {
              this.promptsModule()
            } else if (this.activeSection === 'mcp') {
              this.wipModule('MCP 服务')
            } else if (this.activeSection === 'skills') {
              this.wipModule('Skills 管理')
            } else {
              this.ragModule()
            }
          }.width('100%')
          .constraintSize({ maxWidth: 1280 })
          .padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
            top: 88 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .alignItems(HorizontalAlign.Start)
        }.width('100%')
        .alignItems(HorizontalAlign.Center)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
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
