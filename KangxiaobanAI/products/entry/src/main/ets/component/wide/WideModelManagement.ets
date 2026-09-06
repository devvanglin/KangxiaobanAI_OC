import ApiClient from '../../network/ApiClient';
import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

interface AIModelConfig {
  id?: number; role_scope: string; name: string; provider: string; base_url: string; model: string; system_prompt: string;
  context_window: number; temperature: number; enabled: boolean; allowed: boolean; is_default: boolean; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; api_key_configured?: boolean; rag_api_key_configured?: boolean;
  updated_at?: string;
}
interface AIConfigPage { list: AIModelConfig[]; }
interface AIConfigRequest { role_scope: string; name: string; provider: string; base_url: string; model: string; api_key: string; system_prompt: string; temperature: number; context_window: number; rag_enabled: boolean; rag_base_url: string; rag_dataset_id: string; enabled: boolean; allowed: boolean; is_default: boolean; }
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
interface ModelTestResult { model: string; success: boolean; latency_ms: number; error?: string; }
interface AIModelProbeRequest { base_url: string; api_key: string; models?: string[]; }
interface AdminPromptSuggestion {
  id: number; role_scope: string; title: string; prompt: string; enabled: boolean; updated_at?: string;
}
interface AdminPromptRequest { role_scope: string; title: string; prompt: string; enabled: boolean; }
interface PromptListEntry {
  key: string; kind: string; role: string; title: string; preview: string; enabled: boolean;
}
interface AIRagProbeRequest { base_url: string; api_key: string; }
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
  @Local connBaseUrl: string = '';
  @Local connApiKey: string = '';
  @Local connRagBaseUrl: string = '';
  @Local connRagDatasetId: string = '';
  @Local connRagApiKey: string = '';
  @Local editorSelectedModels: string[] = [];
  @Local editorTesting: boolean = false;
  @Local editorTestResults: ModelTestResult[] = [];
  @Local editorRagFetching: boolean = false;
  @Local editorRagHint: string = '';
  @Local showEditor: boolean = false;
  @Local editorFetched: ProviderModel[] = [];
  @Local editorFetching: boolean = false;
  @Local editorFetchHint: string = '';
  @Local promptScenario: string = 'caregiver';
  @Local promptSearch: string = '';
  @Local selectedPromptKey: string = 'system-caregiver';
  @Local promptSuggestions: AdminPromptSuggestion[] = [];
  @Local promptText: string = '';
  @Local promptModel: string = '';
  @Local promptTemp: string = '0.3';
  @Local promptContext: string = '16';
  @Local suggestionTitle: string = '';
  @Local suggestionContent: string = '';
  @Local suggestionEnabled: boolean = true;
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
    this.loadPromptSuggestions();
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
      this.connBaseUrl = view.base_url;
      this.connRagBaseUrl = view.rag_base_url;
      this.connRagDatasetId = view.rag_dataset_id;
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
  /** 全部模型的今日加权成功率。 */
  private successRateText(): string {
    if (!this.modelStatsLoaded) { return '--'; }
    let calls: number = 0;
    let weighted: number = 0;
    this.modelStats.forEach((item: ModelUsageStat): void => {
      calls += item.today_calls;
      weighted += item.today_calls * item.success_rate;
    });
    if (calls === 0) { return '--'; }
    return `${(weighted / calls).toFixed(1)}%`;
  }

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
    if (this.connBaseUrl.trim().length === 0) {
      this.editorFetched = [];
      this.editorSelectedModels = [];
      this.editorTestResults = [];
      this.editorFetchHint = '请先填写模型服务 Base URL';
      return;
    }
    this.editorFetching = true;
    this.editorFetchHint = '';
    this.editorSelectedModels = [];
    this.editorTestResults = [];
    try {
      const payload: AIModelProbeRequest = {
        base_url: this.connBaseUrl.trim(), api_key: this.connApiKey
      };
      const response = await ApiClient.post<ProviderModel[]>('/admin/ai/llm/models', payload);
      if (response.code !== 0 || response.data === undefined) {
        this.editorFetched = [];
        this.editorFetchHint = response.msg.length > 0 ? response.msg : '模型获取失败，请检查地址与密钥';
      } else {
        this.editorFetched = response.data;
        if (response.data.length === 0) { this.editorFetchHint = '模型服务未返回任何模型'; }
      }
    } catch (_error) {
      this.editorFetched = [];
      this.editorFetchHint = '模型获取失败，请检查网络';
    }
    this.editorFetching = false;
  }

  private toggleModelSelection(modelId: string): void {
    if (this.editorSelectedModels.indexOf(modelId) >= 0) {
      this.editorSelectedModels = this.editorSelectedModels.filter((item: string) => item !== modelId);
    } else {
      this.editorSelectedModels = this.editorSelectedModels.concat(modelId);
    }
  }

  private allModelsSelected(): boolean {
    return this.editorFetched.length > 0 && this.editorSelectedModels.length === this.editorFetched.length;
  }

  private toggleSelectAllModels(): void {
    if (this.allModelsSelected()) {
      this.editorSelectedModels = [];
    } else {
      this.editorSelectedModels = this.editorFetched.map((item: ProviderModel) => item.id);
    }
  }

  private testResultOf(modelId: string): ModelTestResult | undefined {
    return this.editorTestResults.find((item: ModelTestResult) => item.model === modelId);
  }

  private async testSelectedModels(): Promise<void> {
    if (this.editorSelectedModels.length === 0) {
      this.editorFetchHint = '请先选择要测试的模型';
      return;
    }
    if (this.editorTesting) { return; }
    this.editorTesting = true;
    this.editorFetchHint = '';
    try {
      const payload: AIModelProbeRequest = {
        base_url: this.connBaseUrl.trim(), api_key: this.connApiKey,
        models: this.editorSelectedModels
      };
      const response = await ApiClient.post<ModelTestResult[]>('/admin/ai/llm/test', payload);
      if (response.code !== 0 || response.data === undefined) {
        this.editorFetchHint = response.msg.length > 0 ? response.msg : '模型测试失败';
      } else {
        this.editorTestResults = response.data;
      }
    } catch (_error) {
      this.editorFetchHint = '模型测试失败，请检查网络';
    }
    this.editorTesting = false;
  }

  private async fetchEditorRag(): Promise<void> {
    if (this.connRagBaseUrl.trim().length === 0) {
      this.editorRagHint = '请先填写 Dify RAG URL';
      return;
    }
    this.editorRagFetching = true;
    this.editorRagHint = '';
    try {
      const payload: AIRagProbeRequest = {
        base_url: this.connRagBaseUrl.trim(), api_key: this.connRagApiKey
      };
      const response = await ApiClient.post<RAGDataset[]>('/admin/ai/rag/datasets', payload);
      if (response.code !== 0 || response.data === undefined) {
        this.ragDatasets = [];
        this.editorRagHint = response.msg.length > 0 ? response.msg : '知识库获取失败，请检查地址与密钥';
      } else {
        this.ragDatasets = response.data;
        if (response.data.length === 0) { this.editorRagHint = 'Dify 服务未返回任何知识库'; }
      }
    } catch (_error) {
      this.ragDatasets = [];
      this.editorRagHint = '知识库获取失败，请检查网络';
    }
    this.editorRagFetching = false;
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
      provider: 'http',
      base_url: this.connBaseUrl.trim(),
      api_key: this.connApiKey,
      rag_enabled: true,
      rag_base_url: this.connRagBaseUrl.trim(),
      rag_dataset_id: this.connRagDatasetId.trim(),
      rag_api_key: this.connRagApiKey,
      enabled: true
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
      provider: 'http',
      base_url: this.connBaseUrl.trim(),
      api_key: '',
      rag_enabled: true,
      rag_base_url: this.connRagBaseUrl.trim(),
      rag_dataset_id: datasetId,
      rag_api_key: '',
      enabled: true
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
    this.editorRagHint = '';
    this.editorRagFetching = false;
    this.editorSelectedModels = [];
    this.editorTestResults = [];
    this.editorTesting = false;
    this.showEditor = true;
  }

  private async loadPromptSuggestions(): Promise<void> {
    try {
      const response = await ApiClient.get<AdminPromptSuggestion[]>('/admin/ai/prompts');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.promptSuggestions = response.data;
    } catch (_error) {
      this.promptSuggestions = [];
    }
  }

  private firstLine(text: string): string {
    const trimmed: string = text.trim().replace(/\s+/g, ' ');
    return trimmed.length > 24 ? `${trimmed.slice(0, 24)}…` : trimmed;
  }

  private promptEntriesForRole(role: string): PromptListEntry[] {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    const entries: PromptListEntry[] = [{
      key: `system-${role}`, kind: 'system', role: role,
      title: `${this.roleShort(role)}助手角色提示`,
      preview: this.firstLine(config !== undefined ? config.system_prompt : '未配置系统提示词'),
      enabled: config !== undefined && config.enabled
    }];
    this.promptSuggestions.forEach((row: AdminPromptSuggestion): void => {
      if (row.role_scope === role) {
        entries.push({
          key: `sug-${row.id}`, kind: 'suggestion', role: role,
          title: row.title, preview: this.firstLine(row.prompt), enabled: row.enabled
        });
      }
    });
    const search: string = this.promptSearch.trim();
    if (search.length > 0) {
      return entries.filter((entry: PromptListEntry) =>
        entry.title.includes(search) || entry.preview.includes(search));
    }
    return entries;
  }

  private scenarioCount(role: string): number {
    return this.promptEntriesForRole(role).length;
  }

  private selectedPromptTitle(): string {
    if (this.selectedPromptKey.startsWith('system-')) {
      return `${this.roleShort(this.selectedPromptKey.slice(7))}助手角色提示`;
    }
    if (this.selectedPromptKey.startsWith('sug-')) {
      const id: number = Number(this.selectedPromptKey.slice(4));
      const row: AdminPromptSuggestion | undefined =
        this.promptSuggestions.find((item: AdminPromptSuggestion) => item.id === id);
      return row !== undefined ? row.title : '提示词';
    }
    return '新建提示词';
  }

  private selectPromptEntry(key: string): void {
    this.selectedPromptKey = key;
    this.promptError = '';
    if (key.startsWith('system-')) {
      const config: AIModelConfig | undefined = this.defaultConfigOfRole(key.slice(7));
      this.promptText = config !== undefined ? config.system_prompt : '';
      this.promptModel = config !== undefined ? config.model : '';
      this.promptTemp = config !== undefined ? String(config.temperature) : '0.3';
      this.promptContext = config !== undefined ? String(config.context_window) : '16';
    } else if (key.startsWith('sug-')) {
      const id: number = Number(this.selectedPromptKey.slice(4));
      const row: AdminPromptSuggestion | undefined =
        this.promptSuggestions.find((item: AdminPromptSuggestion) => item.id === id);
      this.suggestionTitle = row !== undefined ? row.title : '';
      this.suggestionContent = row !== undefined ? row.prompt : '';
      this.suggestionEnabled = row !== undefined ? row.enabled : true;
    }
  }

  private modelOptionIds(): string[] {
    const ids: string[] = this.sourceModels.map((item: ProviderModel) => item.id);
    if (this.promptModel.length > 0 && !ids.includes(this.promptModel)) {
      ids.unshift(this.promptModel);
    }
    if (ids.length === 0) {
      ids.push('未获取到模型');
    }
    return ids;
  }

  private modelOptionIndex(): number {
    const ids: string[] = this.modelOptionIds();
    const index: number = ids.indexOf(this.promptModel);
    return index >= 0 ? index : 0;
  }

  private async saveSelectedPrompt(): Promise<void> {
    if (this.selectedPromptKey.startsWith('system-')) {
      const role: string = this.selectedPromptKey.slice(7);
      const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
      const modelId: string = this.promptModel.trim();
      if (modelId.length === 0) { this.promptError = '请先绑定模型'; return; }
      const temperature: number = Number(this.promptTemp);
      const contextWindow: number = Math.round(Number(this.promptContext));
      const basePayload: AIConfigRequest = {
        role_scope: role,
        name: role === 'doctor' ? '医师默认模型' : '护工默认模型',
        provider: 'http', base_url: '', model: modelId, api_key: '',
        system_prompt: this.promptText.trim(),
        temperature: isNaN(temperature) ? 0.3 : temperature,
        context_window: isNaN(contextWindow) || contextWindow <= 0 ? 16 : contextWindow,
        rag_enabled: false, rag_base_url: '', rag_dataset_id: '',
        enabled: true, allowed: true, is_default: true
      };
      if (config === undefined || config.id === undefined) {
        const created = await ApiClient.post<AIModelConfig>('/admin/ai/configs', basePayload);
        if (created.code !== 0) { this.promptError = created.msg || '提示词保存失败'; return; }
      } else {
        const payload: AIConfigRequest = {
          role_scope: config.role_scope, name: config.name, provider: config.provider, base_url: config.base_url,
          model: modelId, api_key: '',
          system_prompt: this.promptText.trim(),
          temperature: basePayload.temperature, context_window: basePayload.context_window,
          rag_enabled: config.rag_enabled, rag_base_url: config.rag_base_url, rag_dataset_id: config.rag_dataset_id,
          enabled: config.enabled, allowed: config.allowed, is_default: config.is_default
        };
        const response = await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${config.id}`, payload);
        if (response.code !== 0) { this.promptError = response.msg || '提示词保存失败'; return; }
      }
      this.promptError = '';
      await this.load();
      this.loadModelStats();
      this.showToast('已保存');
      return;
    }
    const title: string = this.suggestionTitle.trim();
    const content: string = this.suggestionContent.trim();
    if (title.length === 0 || content.length === 0) { this.promptError = '标题与内容必填'; return; }
    if (this.selectedPromptKey.startsWith('new-')) {
      const payload: AdminPromptRequest = {
        role_scope: this.promptScenario, title: title, prompt: content, enabled: this.suggestionEnabled
      };
      const created = await ApiClient.post<AdminPromptSuggestion>('/admin/ai/prompts', payload);
      if (created.code !== 0 || created.data === undefined) {
        this.promptError = created.msg || '提示词创建失败';
        return;
      }
      await this.loadPromptSuggestions();
      this.selectPromptEntry(`sug-${created.data.id}`);
      this.showToast('已创建');
      return;
    }
    const id: number = Number(this.selectedPromptKey.slice(4));
    const payload: AdminPromptRequest = {
      role_scope: this.promptScenario, title: title, prompt: content, enabled: this.suggestionEnabled
    };
    const response = await ApiClient.put<AdminPromptSuggestion>(`/admin/ai/prompts/${id}`, payload);
    if (response.code !== 0) { this.promptError = response.msg || '提示词保存失败'; return; }
    await this.loadPromptSuggestions();
    this.showToast('已保存');
  }

  private async testBoundModel(): Promise<void> {
    const modelId: string = this.promptModel.trim();
    if (modelId.length === 0) { this.showToast('请先绑定模型'); return; }
    if (this.connBaseUrl.trim().length === 0) { this.showToast('请先保存网关地址'); return; }
    try {
      const payload: AIModelProbeRequest = {
        base_url: this.connBaseUrl.trim(), api_key: '', models: [modelId]
      };
      const response = await ApiClient.post<ModelTestResult[]>('/admin/ai/llm/test', payload);
      if (response.code !== 0 || response.data === undefined || response.data.length === 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '测试失败');
        return;
      }
      const result: ModelTestResult = response.data[0];
      if (result.success) {
        this.showToast(`测试通过 · ${result.latency_ms}ms`);
      } else {
        this.showToast(`测试失败 · ${result.error}`);
      }
    } catch (_error) {
      this.showToast('测试失败，请检查网络');
    }
  }

  private async createPromptEntry(): Promise<void> {
    const payload: AdminPromptRequest = {
      role_scope: this.promptScenario, title: '新提示词',
      prompt: '（请填写提示词内容）', enabled: false
    };
    const created = await ApiClient.post<AdminPromptSuggestion>('/admin/ai/prompts', payload);
    if (created.code !== 0 || created.data === undefined) {
      this.showToast(created.msg.length > 0 ? created.msg : '提示词创建失败');
      return;
    }
    await this.loadPromptSuggestions();
    this.selectPromptEntry(`sug-${created.data.id}`);
  }

  private async deleteSelectedSuggestion(): Promise<void> {
    if (!this.selectedPromptKey.startsWith('sug-')) { return; }
    const id: number = Number(this.selectedPromptKey.slice(4));
    const response = await ApiClient.delete<Object>(`/admin/ai/prompts/${id}`);
    if (response.code !== 0) { this.promptError = response.msg || '提示词删除失败'; return; }
    await this.loadPromptSuggestions();
    this.selectPromptEntry(`system-${this.promptScenario}`);
  }

  // ===== 平台版式元素 =====

  @Builder
  private statTag($$: StatTagParam) {
    Column({ space: 4 }) {
      Text($$.label).fontSize(14).fontColor($r('sys.color.font_secondary'))
      Text($$.value).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }.alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
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
        itemWidth: 118,
        itemFontSize: 16,
        onSelect: (index: number) => {
          this.activeSection = SECTION_IDS[index] ?? 'models';
        }
      })
      Blank()
      Button('编辑模型网关').height(38).fontSize(14).borderRadius(8)
        .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
        .onClick(() => this.openEditor())
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
      Text(label).fontSize(12).fontColor($r('sys.color.font_tertiary'))
      Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private cardLink(label: string, onTap: () => void) {
    Text(label).fontSize(13.5).fontColor($r('sys.color.font_secondary'))
      .onClick(() => onTap())
  }

  @Builder
  private modelCard(item: ProviderModel) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.id).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        ForEach(this.usedByRoles(item.id), (role: string) => {
          this.assignBadge(role)
        }, (role: string) => `mc-${item.id}-${role}`)
        this.cardLink('测试', () => {
          this.loadSourceModels();
          this.loadModelStats();
        })
      }.width('100%').alignItems(VerticalAlign.Center)
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
        Text('正在从统一连接获取模型列表…').fontSize(14).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
      } else if (this.sourceError.length > 0) {
        Column({ space: 8 }) {
          Text(this.sourceError).fontSize(14).fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center).width('100%')
          Text('重试').fontSize(14).fontColor($r('app.color.brand_blue'))
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
  private scenarioRow(role: string) {
    Row({ space: 8 }) {
      Text(this.roleLabel(role))
        .fontSize(14)
        .fontColor(this.promptScenario === role ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
      Blank()
      Text(this.scenarioCount(role).toString())
        .fontSize(11).fontColor(this.promptScenario === role ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor(this.promptScenario === role ? $r('sys.color.comp_background_primary') :
          $r('sys.color.comp_background_secondary'))
    }.width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor(this.promptScenario === role ? $r('sys.color.comp_background_secondary') : Color.Transparent)
    .onClick(() => {
      this.promptScenario = role;
      this.selectPromptEntry(`system-${role}`);
    })
  }

  @Builder
  private promptEntryRow(entry: PromptListEntry) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        Text(entry.title)
          .fontSize(13)
          .fontWeight(this.selectedPromptKey === entry.key ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(entry.enabled ? '启用' : '停用')
          .fontSize(11)
          .fontColor(entry.enabled ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor(entry.enabled ? '#F0FDF4' : $r('sys.color.comp_background_secondary'))
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(entry.preview).fontSize(12).fontColor($r('sys.color.font_tertiary'))
        .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(8)
    .border({ width: 0.5, color: this.selectedPromptKey === entry.key ?
      $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
    .backgroundColor(this.selectedPromptKey === entry.key ? '#F0F5FF' :
      $r('sys.color.comp_background_primary'))
    .onClick(() => this.selectPromptEntry(entry.key))
  }

  @Builder
  private promptEditorField(label: string) {
    Text(label).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
  }

  @Builder
  private promptsModule() {
    Row({ space: 12 }) {
      Column({ space: 10 }) {
        Search({ value: $$this.promptSearch, placeholder: '搜索提示词...' }).height(36)
        Text('AI 场景').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        this.scenarioRow('caregiver')
        this.scenarioRow('doctor')
        Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
        Row({ space: 8 }) {
          Text('全部提示词').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Blank()
          Text('＋ 新建').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.createPromptEntry())
        }.width('100%')
        Scroll() {
          Column({ space: 6 }) {
            ForEach(this.promptEntriesForRole(this.promptScenario), (entry: PromptListEntry) => {
              this.promptEntryRow(entry)
            }, (entry: PromptListEntry) => `pe-${entry.key}`)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.constraintSize({ maxHeight: 430 }).scrollBar(BarState.Off).width('100%')
      }.width(260)
      .padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text(this.selectedPromptTitle())
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          Blank()
          this.cardLink('测试', () => this.testBoundModel())
          Button('保存').height(36).fontSize(13).borderRadius(8)
            .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
            .onClick(() => this.saveSelectedPrompt())
        }.width('100%').alignItems(VerticalAlign.Center)

        Row({ space: 24 }) {
          Column({ space: 4 }) {
            this.promptEditorField('所属场景')
            Text(this.roleLabel(this.promptScenario)).fontSize(14).fontColor($r('sys.color.font_primary'))
          }.alignItems(HorizontalAlign.Start)
          if (this.selectedPromptKey.startsWith('system-')) {
            Column({ space: 4 }) {
              this.promptEditorField('绑定模型')
              Select(this.modelOptionIds().map((item: string): SelectOption => ({ value: item } as SelectOption)))
                .selected(this.modelOptionIndex())
                .value(this.promptModel.length > 0 ? this.promptModel : '选择模型')
                .font({ size: 14 })
                .onSelect((index: number) => {
                  const ids: string[] = this.modelOptionIds();
                  if (index >= 0 && index < ids.length) { this.promptModel = ids[index]; }
                })
            }.alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              this.promptEditorField('当前版本')
              Text(`最后更新 ${this.updatedDateText(this.defaultConfigOfRole(this.promptScenario)?.updated_at)}`)
                .fontSize(14).fontColor($r('sys.color.font_primary'))
            }.alignItems(HorizontalAlign.Start)
          } else {
            Column({ space: 4 }) {
              this.promptEditorField('所属场景')
              Text(this.roleLabel(this.promptScenario)).fontSize(14).fontColor($r('sys.color.font_primary'))
            }.alignItems(HorizontalAlign.Start)
          }
        }.width('100%').alignItems(VerticalAlign.Top)

        if (this.selectedPromptKey.startsWith('system-')) {
          this.promptEditorField('系统提示词')
          TextArea({ text: $$this.promptText, placeholder: '输入系统提示词...' })
            .height(300).fontSize(13)
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Text('对话参数').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            .width('100%')
          Row({ space: 24 }) {
            Column({ space: 4 }) {
              this.promptEditorField('温度（temperature）')
              TextInput({ text: $$this.promptTemp }).height(38).width(140)
            }.alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              this.promptEditorField('上下文长度（条）')
              TextInput({ text: $$this.promptContext }).height(38).width(140)
            }.alignItems(HorizontalAlign.Start)
          }.width('100%').alignItems(VerticalAlign.Top)
        } else {
          this.promptEditorField('标题')
          TextInput({ text: $$this.suggestionTitle, placeholder: '提示词标题...' }).height(40)
          Row({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.suggestionEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.suggestionEnabled = isOn)
            Text(this.suggestionEnabled ? '启用' : '停用').fontSize(13).fontColor($r('sys.color.font_primary'))
          }.alignItems(VerticalAlign.Center)
          this.promptEditorField('提示词内容')
          TextArea({ text: $$this.suggestionContent, placeholder: '输入提示词内容...' })
            .height(280).fontSize(13)
          if (this.selectedPromptKey.startsWith('sug-')) {
            Text('删除该提示词').fontSize(13).fontColor($r('app.color.doctor_workspace_danger'))
              .onClick(() => this.deleteSelectedSuggestion())
          }
        }
        if (this.promptError.length > 0) {
          Text(this.promptError).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
        }
      }.layoutWeight(1)
      .padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
    }.width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private ragCard(item: RAGDataset) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(item.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.connRagDatasetId === item.id) {
          Text('使用中').fontSize(11).fontColor($r('app.color.brand_blue'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(12).backgroundColor('#E8F0FE')
        } else {
          Text('未启用').fontSize(12).fontColor($r('sys.color.font_tertiary'))
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
        Text('正在从 Dify 获取知识库列表…').fontSize(14).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
      } else if (this.ragError.length > 0) {
        Column({ space: 8 }) {
          Text(this.ragError).fontSize(14).fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center).width('100%')
          Text('重试').fontSize(14).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.loadRagDatasets())
        }.width('100%').padding({ top: 20, bottom: 20 })
      } else if (this.ragDatasets.length === 0) {
        Text('未获取到知识库，请确认 Dify 服务中已创建知识库。')
          .fontSize(14).fontColor($r('sys.color.font_secondary'))
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
        .fontSize(14).fontColor($r('sys.color.font_secondary'))
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
          Text('模型服务（OpenAI 兼容）').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).width('100%')
          Row({ space: 8 }) {
            TextInput({ placeholder: '模型服务 Base URL', text: $$this.connBaseUrl })
              .height(40).layoutWeight(1)
            Button('获取模型测试').height(40).fontSize(13)
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
          if (this.editorFetched.length > 0) {
            Row({ space: 10 }) {
              Text(`已选 ${this.editorSelectedModels.length}/${this.editorFetched.length}`)
                .fontSize(12).fontColor($r('sys.color.font_secondary'))
              Blank()
              Text('全选').fontSize(13).fontColor($r('app.color.brand_blue'))
                .onClick(() => this.toggleSelectAllModels())
              Text(this.editorTesting ? '测试中…' : '测试所选').fontSize(13).fontColor($r('app.color.brand_blue'))
                .onClick(() => this.testSelectedModels())
            }.width('100%')
            Scroll() {
              Column({ space: 6 }) {
                ForEach(this.editorFetched, (item: ProviderModel) => {
                  Row({ space: 8 }) {
                    Text(this.editorSelectedModels.indexOf(item.id) >= 0 ? '✓' : '')
                      .fontSize(12).fontColor($r('app.color.brand_blue'))
                      .width(20).height(20).textAlign(TextAlign.Center)
                      .borderRadius(10)
                      .border({ width: 0.5, color: this.editorSelectedModels.indexOf(item.id) >= 0 ?
                        $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
                    Text(item.id).fontSize(13).fontColor($r('sys.color.font_primary'))
                      .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.testResultOf(item.id) !== undefined) {
                      Text(this.testResultOf(item.id)!.success ?
                        `✓ ${this.testResultOf(item.id)!.latency_ms}ms` :
                        `✗ ${this.testResultOf(item.id)!.error}`)
                        .fontSize(12).fontColor(this.testResultOf(item.id)!.success ?
                          $r('app.color.doctor_workspace_success') : $r('app.color.doctor_workspace_danger'))
                    }
                  }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
                    .borderRadius(8)
                    .border({ width: 0.5, color: this.editorSelectedModels.indexOf(item.id) >= 0 ?
                      $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
                    .backgroundColor(this.editorSelectedModels.indexOf(item.id) >= 0 ? '#F0F5FF' :
                      $r('sys.color.comp_background_primary'))
                    .onClick(() => this.toggleModelSelection(item.id))
                }, (item: ProviderModel) => `editor-model-${item.id}`)
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.constraintSize({ maxHeight: 150 }).scrollBar(BarState.Off).width('100%')
          }
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Text('Dify RAG 知识库').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).width('100%')
          TextInput({ placeholder: 'Dify RAG URL', text: $$this.connRagBaseUrl }).height(40)
          TextInput({ placeholder: 'RAG API Key（留空表示保留原密钥）', text: $$this.connRagApiKey })
            .height(40).type(InputType.Password)
          Button('获取知识库测试').width('100%').height(40).fontSize(13)
            .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
            .onClick(() => this.fetchEditorRag())
          if (this.editorRagFetching) {
            Text('正在获取知识库…').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          } else if (this.editorRagHint.length > 0) {
            Text(this.editorRagHint).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          if (this.ragDatasets.length > 0) {
            Scroll() {
              Column({ space: 6 }) {
                ForEach(this.ragDatasets, (item: RAGDataset) => {
                  Row({ space: 8 }) {
                    Text(item.name).fontSize(13).fontColor($r('sys.color.font_primary'))
                      .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${item.document_count} 篇`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
                  }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
                    .borderRadius(8)
                    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
                    .backgroundColor($r('sys.color.comp_background_primary'))
                }, (item: RAGDataset) => `editor-rag-${item.id}`)
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.constraintSize({ maxHeight: 150 }).scrollBar(BarState.Off).width('100%')
          }
          Text('网关对全部端默认开启；护工/医师各自在「提示词」里分配模型与提示词。')
            .fontSize(12).fontColor($r('sys.color.font_tertiary'))
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

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column() {
          Column({ space: 24 }) {
            Row({ space: 10 }) {
              this.statTag({ label: '总消耗 Token', value: this.usageValue(this.usage.total_tokens) })
              this.statTag({ label: '成功率', value: this.successRateText() })
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
    }.width('100%').height('100%')
  }
}
