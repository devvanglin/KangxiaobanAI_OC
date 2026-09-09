import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import ApiClient, { HttpMethod } from '../../network/ApiClient';
import { ApiResp } from '../../network/Dto';
import { KBCreatePageParam, KBFileParam } from './WideKnowledgeCreatePage';
import { WideRagDocumentsPage, RagDocsPageParam } from './WideRagDocumentsPage';
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
interface RAGDataset { id: string; name: string; description: string; document_count: number; word_count: number; updated_at?: string; embedding_model?: string; indexing_technique?: string; }
interface RAGEmbeddingModel { model: string; label?: Record<string, string>; status?: string; }
interface UploadProcessRule { mode: string; }
interface KBPickedFile { name: string; size: number; bytes: ArrayBuffer; }
interface RetrieveSettings {
  search_method: string;
  reranking_enable: boolean;
  top_k: number;
  score_threshold_enabled: boolean;
}
interface RetrieveSegment { content?: string; }
interface RetrieveRecord { segment?: RetrieveSegment; score?: number; }
interface McpServerRecord { id: number; name: string; endpoint: string; enabled: boolean; status: string; tool_count: number; last_probe_at?: string; last_probe_message?: string; }
interface McpServerPage { list: McpServerRecord[]; }
interface SkillRecord { id: number; role_scope: string; code: string; name: string; description: string; version: string; tags: string; instructions: string; sort_order: number; enabled: boolean; is_builtin: boolean; }
interface SkillPage { list: SkillRecord[]; }
interface SkillSaveRequest { role_scope: string; code: string; name: string; description: string; version: string; tags: string; instructions: string; sort_order: number; enabled: boolean; }
interface McpSaveRequest { name: string; endpoint: string; api_key: string; enabled: boolean; }
interface McpProbeRequest { }
interface RetrieveRequest {
  query: string;
  retrieval_model: RetrieveSettings;
}
interface RagKBUpdateRequest { name?: string; description?: string; }
interface RagRetrieveResponse { records?: RetrieveRecord[]; }
interface ProviderModel { id: string; }
/** 只读的连接状态视图：模型服务/Dify 连接改由服务端 .env 配置，
 * 客户端只能看到「是否已配置」旗标，永远拿不到地址与密钥（与 MinIO 一致）。 */
interface AIConnectionStatus {
  provider: string; enabled: boolean; base_url_configured: boolean; api_key_configured: boolean;
  rag_configured: boolean; rag_dataset_configured: boolean; rag_api_key_configured: boolean;
}
function emptyConnectionStatus(): AIConnectionStatus {
  return {
    provider: 'local', enabled: false, base_url_configured: false, api_key_configured: false,
    rag_configured: false, rag_dataset_configured: false, rag_api_key_configured: false
  } as AIConnectionStatus;
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
interface StatTagParam { label: string; value: string; }
/** 平台内置 Agent 工具清单条目（GET /admin/ai/tools）。 */
interface AgentToolInfo {
  name: string; description: string; permission: string;
  mode: string; kind: string; active: boolean;
}
/** 沙箱设置视图（GET/PUT /admin/ai/sandbox）；密钥只回「是否已配置」旗标。 */
interface SandboxView {
  enabled: boolean; domain: string; protocol: string; image: string;
  api_key_configured: boolean; source: string;
}
interface SandboxSaveRequest {
  enabled: boolean; domain: string; protocol: string; image: string; api_key: string;
}
interface SandboxProbeResult { reachable: boolean; status: number; latency_ms: number; enabled: boolean; }
interface SandboxProbeRequest { }
interface AssessmentAgentQuestion { id: string; topic: string; question: string; }
interface AssessmentAgentQuestionBank {
  id: number; title: string; version: number; no_answer_timeout: number;
  questions: AssessmentAgentQuestion[]; enabled: boolean;
}
interface AssessmentAgentQuestionBankPayload {
  title: string; no_answer_timeout: number; questions: AssessmentAgentQuestion[];
}

const DARK_BUTTON_BG: string = '#1D63ED';
const SECTION_IDS: string[] = ['models', 'prompts', 'tools', 'sandbox', 'skills', 'rag', 'assessment'];

@ComponentV2
export struct WideModelManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local configs: AIModelConfig[] = [];
  @Local activeSection: string = 'models';
  @Local promptFilter: string = 'all';
  @Local connStatus: AIConnectionStatus = emptyConnectionStatus();
  @Local showFilePick: boolean = false;
  @Local pickedFiles: KBPickedFile[] = [];
  @Local showRetrieve: boolean = false;
  @Local retrieveDatasetId: string = '';
  @Local retrieveQuery: string = '';
  @Local retrieveBusy: boolean = false;
  @Local retrieveRecords: RetrieveRecord[] = [];
  @Local retrieveHint: string = '';
  @Local showKBSettings: boolean = false;
  @Local kbSettingsId: string = '';
  @Local kbSettingsName: string = '';
  @Local kbSettingsDesc: string = '';
  @Local kbBusy: boolean = false;
  @Local kbConfirmDelete: boolean = false;
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
  @Local sourceModels: ProviderModel[] = [];
  @Local sourceLoading: boolean = false;
  @Local sourceError: string = '';
  @Local ragDatasets: RAGDataset[] = [];
  @Local ragLoading: boolean = false;
  @Local ragError: string = '';
  @Local modelStats: ModelUsageStat[] = [];
  @Local modelStatsLoaded: boolean = false;
  @Local usage: AIUsageSummary = { total_tokens: 0, today_calls: 0, avg_daily_calls: 0, rag_calls: 0 };
  @Local usageLoaded: boolean = false;
  @Local mcpServers: McpServerRecord[] = [];
  @Local selectedMcpId: number = 0;
  @Local mcpName: string = '';
  @Local mcpEndpoint: string = '';
  @Local mcpApiKey: string = '';
  @Local mcpEnabled: boolean = true;
  @Local mcpBusy: boolean = false;
  @Local agentTools: AgentToolInfo[] = [];
  @Local toolsLoading: boolean = false;
  @Local toolsError: string = '';
  @Local sbEnabled: boolean = false;
  @Local sbDomain: string = '';
  @Local sbProtocol: string = 'http';
  @Local sbImage: string = 'python:3.12-slim';
  @Local sbApiKey: string = '';
  @Local sbKeyConfigured: boolean = false;
  @Local sbSource: string = 'env';
  @Local sbBusy: boolean = false;
  @Local sbProbing: boolean = false;
  @Local sbProbeHint: string = '';
  @Local skills: SkillRecord[] = [];
  @Local selectedSkillId: number = 0;
  @Local skillName: string = '';
  @Local skillCode: string = '';
  @Local skillRole: string = 'all';
  @Local skillDescription: string = '';
  @Local skillInstructions: string = '';
  @Local skillEnabled: boolean = true;
  @Local skillBusy: boolean = false;
  @Local assessmentBank: AssessmentAgentQuestionBank | null = null;
  @Local assessmentBankJson: string = '';
  @Local assessmentBankLoading: boolean = false;
  @Local assessmentBankSaving: boolean = false;
  @Local assessmentBankError: string = '';

  aboutToAppear(): void {
    this.load();
    this.loadUsage();
    this.loadModelStats();
    this.loadPromptSuggestions();
    this.loadConnection();
    this.loadRagDatasets();
    this.loadSourceModels();
    this.loadMcpServers();
    this.loadAgentTools();
    this.loadSandbox();
    this.loadSkills();
    this.loadAssessmentQuestionBank();
  }

  /** 平台内置 Agent 工具清单（工具模块上半区）。 */
  private async loadAgentTools(): Promise<void> {
    this.toolsLoading = true;
    this.toolsError = '';
    try {
      const response = await ApiClient.get<AgentToolInfo[]>('/admin/ai/tools');
      if (response.code !== 0 || response.data === undefined) {
        this.toolsError = response.msg.length > 0 ? response.msg : '工具清单获取失败';
        this.agentTools = [];
      } else {
        this.agentTools = response.data;
      }
    } catch (_error) {
      this.toolsError = '工具清单获取失败，请检查网络';
      this.agentTools = [];
    }
    this.toolsLoading = false;
  }

  private async loadSandbox(): Promise<void> {
    try {
      const response = await ApiClient.get<SandboxView>('/admin/ai/sandbox');
      if (response.code !== 0 || response.data === undefined) { return; }
      this.sbEnabled = response.data.enabled;
      this.sbDomain = response.data.domain;
      this.sbProtocol = response.data.protocol.length > 0 ? response.data.protocol : 'http';
      this.sbImage = response.data.image.length > 0 ? response.data.image : 'python:3.12-slim';
      this.sbKeyConfigured = response.data.api_key_configured;
      this.sbSource = response.data.source;
      this.sbApiKey = '';
    } catch (_error) { this.showToast('沙箱设置加载失败'); }
  }

  private async saveSandbox(): Promise<void> {
    if (this.sbBusy) { return; }
    if (this.sbDomain.trim().length === 0) { this.showToast('控制面地址必填'); return; }
    this.sbBusy = true;
    try {
      const payload: SandboxSaveRequest = {
        enabled: this.sbEnabled, domain: this.sbDomain.trim(), protocol: this.sbProtocol,
        image: this.sbImage.trim(), api_key: this.sbApiKey
      };
      const response = await ApiClient.put<SandboxView>('/admin/ai/sandbox', payload);
      if (response.code !== 0 || response.data === undefined) {
        this.showToast(response.msg.length > 0 ? response.msg : '沙箱设置保存失败');
        return;
      }
      this.sbKeyConfigured = response.data.api_key_configured;
      this.sbSource = response.data.source;
      this.sbApiKey = '';
      this.showToast('沙箱设置已保存');
      this.loadAgentTools();
    } catch (_error) {
      this.showToast('沙箱设置保存失败，请检查网络');
    }
    this.sbBusy = false;
  }

  private async probeSandbox(): Promise<void> {
    if (this.sbProbing) { return; }
    this.sbProbing = true;
    this.sbProbeHint = '正在探测…';
    try {
      const probeRequest: SandboxProbeRequest = {};
      const response = await ApiClient.post<SandboxProbeResult>('/admin/ai/sandbox/probe', probeRequest);
      if (response.code !== 0 || response.data === undefined) {
        this.sbProbeHint = response.msg.length > 0 ? response.msg : '探测失败';
      } else {
        this.sbProbeHint = `控制面可达 · HTTP ${response.data.status} · ${response.data.latency_ms}ms` +
          (response.data.enabled ? '' : '（当前未启用）');
      }
    } catch (_error) {
      this.sbProbeHint = '探测失败，请检查网络';
    }
    this.sbProbing = false;
  }

  private async loadAssessmentQuestionBank(): Promise<void> {
    this.assessmentBankLoading = true;
    this.assessmentBankError = '';
    try {
      const response = await ApiClient.get<AssessmentAgentQuestionBank>('/admin/ai/assessment-question-bank');
      if (response.code !== 0 || response.data === undefined) {
        this.assessmentBankError = response.msg || '评估题库加载失败';
        return;
      }
      this.assessmentBank = response.data;
      const editable: AssessmentAgentQuestionBankPayload = {
        title: response.data.title,
        no_answer_timeout: response.data.no_answer_timeout,
        questions: response.data.questions ?? []
      };
      this.assessmentBankJson = JSON.stringify(editable, null, 2);
    } catch (_error) {
      this.assessmentBankError = '无法连接服务器，评估题库加载失败';
    } finally {
      this.assessmentBankLoading = false;
    }
  }

  private async saveAssessmentQuestionBank(): Promise<void> {
    if (this.assessmentBankSaving) { return; }
    let payload: AssessmentAgentQuestionBankPayload;
    try {
      payload = JSON.parse(this.assessmentBankJson) as AssessmentAgentQuestionBankPayload;
    } catch (_error) {
      this.assessmentBankError = 'JSON 格式错误，请检查逗号、引号和括号';
      return;
    }
    if (payload.title === undefined || payload.no_answer_timeout === undefined ||
      payload.questions === undefined || payload.questions.length === 0) {
      this.assessmentBankError = '题库必须包含 title、no_answer_timeout 和非空 questions';
      return;
    }
    this.assessmentBankSaving = true;
    this.assessmentBankError = '';
    try {
      const response = await ApiClient.put<AssessmentAgentQuestionBank>('/admin/ai/assessment-question-bank', payload);
      if (response.code !== 0 || response.data === undefined) {
        this.assessmentBankError = response.msg || '评估题库保存失败';
        return;
      }
      this.assessmentBank = response.data;
      this.showToast(`评估题库已保存为 V${response.data.version}`);
      await this.loadAssessmentQuestionBank();
    } catch (_error) {
      this.assessmentBankError = '评估题库保存失败，请检查网络';
    } finally {
      this.assessmentBankSaving = false;
    }
  }

  private async loadMcpServers(): Promise<void> {
    try {
      const response = await ApiClient.get<McpServerPage>('/admin/ai/mcp/servers');
      if (response.code === 0 && response.data !== undefined) {
        this.mcpServers = response.data.list ?? [];
        if (!this.mcpServers.some((server: McpServerRecord): boolean => server.id === this.selectedMcpId)) {
          this.selectedMcpId = this.mcpServers.length > 0 ? this.mcpServers[0].id : 0;
          this.fillMcpEditor();
        }
      }
    } catch (_error) { this.showToast('MCP 服务列表加载失败'); }
  }

  private selectMcpServer(id: number): void {
    this.selectedMcpId = id;
    this.fillMcpEditor();
  }

  private selectedMcp(): McpServerRecord | undefined {
    return this.mcpServers.find((server: McpServerRecord): boolean => server.id === this.selectedMcpId);
  }

  private fillMcpEditor(): void {
    const server: McpServerRecord | undefined = this.selectedMcp();
    this.mcpName = server?.name ?? '';
    this.mcpEndpoint = server?.endpoint ?? '';
    this.mcpApiKey = '';
    this.mcpEnabled = server?.enabled ?? true;
  }

  private createMcpServer(): void {
    this.selectedMcpId = 0;
    this.mcpName = '';
    this.mcpEndpoint = '';
    this.mcpApiKey = '';
    this.mcpEnabled = true;
  }

  private async saveMcpServer(): Promise<void> {
    if (this.mcpName.trim().length === 0 || this.mcpEndpoint.trim().length === 0) {
      this.showToast('名称与端点必填');
      return;
    }
    this.mcpBusy = true;
    const request: McpSaveRequest = {
      name: this.mcpName.trim(), endpoint: this.mcpEndpoint.trim(),
      api_key: this.mcpApiKey.trim(), enabled: this.mcpEnabled
    };
    try {
      const response = this.selectedMcpId > 0
        ? await ApiClient.put<McpServerRecord>(`/admin/ai/mcp/servers/${this.selectedMcpId}`, request)
        : await ApiClient.post<McpServerRecord>('/admin/ai/mcp/servers', request);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : 'MCP 服务保存失败');
      } else {
        this.showToast('MCP 服务已保存');
        await this.loadMcpServers();
      }
    } catch (_error) {
      this.showToast('MCP 服务保存失败，请检查网络');
    }
    this.mcpBusy = false;
  }

  private async deleteMcpServer(): Promise<void> {
    if (this.selectedMcpId === 0) {
      return;
    }
    this.mcpBusy = true;
    try {
      const response = await ApiClient.delete<McpServerRecord>(`/admin/ai/mcp/servers/${this.selectedMcpId}`);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '删除失败');
      } else {
        this.showToast('已删除');
        this.createMcpServer();
        await this.loadMcpServers();
      }
    } catch (_error) {
      this.showToast('删除失败，请检查网络');
    }
    this.mcpBusy = false;
  }

  private async probeMcpServer(): Promise<void> {
    if (this.selectedMcpId === 0) {
      this.showToast('请先保存服务后再探测');
      return;
    }
    this.mcpBusy = true;
    try {
      const probeRequest: McpProbeRequest = {};
      const response = await ApiClient.post<McpServerRecord>(`/admin/ai/mcp/servers/${this.selectedMcpId}/probe`, probeRequest);
      if (response.code === 0 && response.data !== undefined) {
        this.showToast(response.data.last_probe_message ?? '探测完成');
        await this.loadMcpServers();
      } else {
        this.showToast(response.msg.length > 0 ? response.msg : '探测失败');
      }
    } catch (_error) {
      this.showToast('探测失败，请检查网络');
    }
    this.mcpBusy = false;
  }

  private async loadSkills(): Promise<void> {
    try {
      const response = await ApiClient.get<SkillPage>('/admin/ai/skills');
      if (response.code === 0 && response.data !== undefined) {
        this.skills = response.data.list ?? [];
        if (!this.skills.some((skill: SkillRecord): boolean => skill.id === this.selectedSkillId)) {
          this.selectedSkillId = this.skills.length > 0 ? this.skills[0].id : 0;
          this.fillSkillEditor();
        }
      }
    } catch (_error) { this.showToast('技能列表加载失败'); }
  }

  private selectSkill(id: number): void {
    this.selectedSkillId = id;
    this.fillSkillEditor();
  }

  private selectedSkill(): SkillRecord | undefined {
    return this.skills.find((skill: SkillRecord): boolean => skill.id === this.selectedSkillId);
  }

  private fillSkillEditor(): void {
    const skill: SkillRecord | undefined = this.selectedSkill();
    this.skillName = skill?.name ?? '';
    this.skillCode = skill?.code ?? '';
    this.skillRole = skill?.role_scope ?? 'all';
    this.skillDescription = skill?.description ?? '';
    this.skillInstructions = skill?.instructions ?? '';
    this.skillEnabled = skill?.enabled ?? true;
  }

  private createSkill(): void {
    this.selectedSkillId = 0;
    this.skillName = '';
    this.skillCode = '';
    this.skillRole = 'all';
    this.skillDescription = '';
    this.skillInstructions = '';
    this.skillEnabled = true;
  }

  private async saveSkill(): Promise<void> {
    if (this.skillName.trim().length === 0 || this.skillInstructions.trim().length === 0) {
      this.showToast('技能名称与指引内容必填');
      return;
    }
    this.skillBusy = true;
    const code = this.skillCode.trim().length > 0 ? this.skillCode.trim() :
      (`custom_${Date.now()}`);
    const request: SkillSaveRequest = {
      role_scope: this.skillRole, code: code, name: this.skillName.trim(),
      description: this.skillDescription.trim(), version: '1.0.0', tags: '',
      instructions: this.skillInstructions.trim(), sort_order: 50, enabled: this.skillEnabled
    };
    try {
      const response = this.selectedSkillId > 0
        ? await ApiClient.put<SkillRecord>(`/admin/ai/skills/${this.selectedSkillId}`, request)
        : await ApiClient.post<SkillRecord>('/admin/ai/skills', request);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '技能保存失败');
      } else {
        this.showToast('技能已保存');
        await this.loadSkills();
      }
    } catch (_error) {
      this.showToast('技能保存失败，请检查网络');
    }
    this.skillBusy = false;
  }

  private async deleteSkill(): Promise<void> {
    if (this.selectedSkillId === 0) {
      return;
    }
    this.skillBusy = true;
    try {
      const response = await ApiClient.delete<SkillRecord>(`/admin/ai/skills/${this.selectedSkillId}`);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '删除失败');
      } else {
        this.showToast('已删除');
        this.createSkill();
        await this.loadSkills();
      }
    } catch (_error) {
      this.showToast('删除失败，请检查网络');
    }
    this.skillBusy = false;
  }

  private roleTagLabel(role: string): string {
    if (role === 'caregiver') { return '护工端'; }
    if (role === 'doctor') { return '医师端'; }
    return '通用';
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

  /** 连接由服务端 .env 配置，这里只拉取只读状态旗标用于空态与状态展示。 */
  private async loadConnection(): Promise<void> {
    try {
      const response = await ApiClient.get<AIConnectionStatus>('/admin/ai/connection');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.connStatus = response.data;
    } catch (_error) { this.showToast('AI 连接状态加载失败'); }
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

  private static readonly KB_EXTENSIONS: string[] =
    ['vtt', 'html', 'properties', 'markdown', 'md', 'xls', 'htm', 'mdx', 'pdf', 'csv', 'docx', 'txt', 'odt', 'xlsx'];
  private static readonly KB_MAX_FILES: number = 5;
  private static readonly KB_MAX_BYTES: number = 15 * 1024 * 1024;

  private async ragProxy<T>(method: HttpMethod, sub: string, query: string,
    payload?: Object): Promise<ApiResp<T>> {
    const path: string = '/admin/ai/rag/proxy/' + sub + (query.length > 0 ? '?' + query : '');
    return ApiClient.send<T>(method, path, payload);
  }

  private openRagDocs(datasetId: string, name: string): void {
    this.pathStack.pushPath({
      name: 'RagDocumentsPage',
      param: new RagDocsPageParam(datasetId, name, this.statusBarHeight, this.naviIndicatorHeight),
      onPop: () => {
        this.loadRagDatasets();
      }
    });
  }

  private openRetrieve(datasetId: string): void {
    this.retrieveDatasetId = datasetId;
    this.retrieveQuery = '';
    this.retrieveRecords = [];
    this.retrieveHint = '';
    this.showRetrieve = true;
  }

  private async runRetrieve(): Promise<void> {
    const query: string = this.retrieveQuery.trim();
    if (query.length === 0) { this.retrieveHint = '请输入测试问题'; return; }
    if (this.retrieveBusy) { return; }
    this.retrieveBusy = true;
    this.retrieveHint = '';
    try {
      const payload: RetrieveRequest = {
        query: query,
        retrieval_model: {
          search_method: 'semantic_search', reranking_enable: false,
          top_k: 3, score_threshold_enabled: false
        }
      };
      const response = await this.ragProxy<RagRetrieveResponse>('POST',
        `datasets/${this.retrieveDatasetId}/retrieve`, '', payload);
      if (response.code !== 0 || response.data === undefined) {
        this.retrieveHint = response.msg.length > 0 ? response.msg : '检索失败';
      } else {
        this.retrieveRecords = response.data.records ?? [];
        if (this.retrieveRecords.length === 0) { this.retrieveHint = '没有命中的分段'; }
      }
    } catch (_error) {
      this.retrieveHint = '检索失败，请检查网络';
    }
    this.retrieveBusy = false;
  }

  private openKBSettings(datasetId: string, name: string, description: string): void {
    this.kbSettingsId = datasetId;
    this.kbSettingsName = name;
    this.kbSettingsDesc = description;
    this.kbConfirmDelete = false;
    this.showKBSettings = true;
  }

  private async saveKBSettings(): Promise<void> {
    if (this.kbBusy) { return; }
    if (this.kbSettingsName.trim().length === 0) { this.showToast('名称必填'); return; }
    this.kbBusy = true;
    try {
      const payload: RagKBUpdateRequest = {
        name: this.kbSettingsName.trim(), description: this.kbSettingsDesc.trim()
      };
      const response = await this.ragProxy<Object>('PATCH', `datasets/${this.kbSettingsId}`, '', payload);
      if (response.code !== 0) {
        this.showToast(response.msg || '知识库更新失败');
      } else {
        this.showToast('知识库已更新');
        this.showKBSettings = false;
        await this.loadRagDatasets();
      }
    } catch (_error) {
      this.showToast('知识库更新失败，请检查网络');
    }
    this.kbBusy = false;
  }

  private async deleteKB(): Promise<void> {
    if (!this.kbConfirmDelete) {
      this.kbConfirmDelete = true;
      this.showToast('再次点击「删除知识库」确认，删除后不可恢复');
      return;
    }
    if (this.kbBusy) { return; }
    this.kbBusy = true;
    try {
      const response = await this.ragProxy<Object>('DELETE', `datasets/${this.kbSettingsId}`, '');
      if (response.code !== 0) {
        this.showToast(response.msg || '知识库删除失败');
        this.kbBusy = false;
        return;
      }
      this.showToast('知识库已删除');
      this.showKBSettings = false;
      this.kbBusy = false;
      await this.loadRagDatasets();
    } catch (_error) {
      this.showToast('知识库删除失败，请检查网络');
      this.kbBusy = false;
    }
  }

  private openFilePickDialog(): void {
    this.pickedFiles = [];
    this.showFilePick = true;
  }

  private async pickKBFile(): Promise<void> {
    if (this.pickedFiles.length >= WideModelManagement.KB_MAX_FILES) {
      this.showToast('每批最多 5 个文件');
      return;
    }
    try {
      const docPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      const picked: string[] = await docPicker.select(options);
      if (picked.length === 0) { return; }
      const uri: string = picked[0];
      const name: string = uri.substring(uri.lastIndexOf('/') + 1);
      const lowerName: string = name.toLowerCase();
      const extOk: boolean = WideModelManagement.KB_EXTENSIONS.some((ext: string) => lowerName.endsWith('.' + ext));
      if (!extOk) {
        this.showToast('不支持的文件类型，已支持 PDF / DOCX / TXT / MD / CSV / XLSX 等');
        return;
      }
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(file.fd).size;
      if (size > WideModelManagement.KB_MAX_BYTES) {
        fs.closeSync(file);
        this.showToast('文件超过 15MB 上限');
        return;
      }
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      if (this.pickedFiles.some((item: KBPickedFile) => item.name === name)) {
        this.showToast('该文件已添加');
        return;
      }
      const pickedFile: KBPickedFile = { name: name, size: size, bytes: buf };
      this.pickedFiles = this.pickedFiles.concat(pickedFile);
    } catch (_error) {
      this.showToast('文件选择失败');
    }
  }

  private removePickedFile(name: string): void {
    this.pickedFiles = this.pickedFiles.filter((item: KBPickedFile) => item.name !== name);
  }

  private formatSize(size: number): string {
    return size >= 1024 * 1024 ? `${(size / 1024 / 1024).toFixed(1)} MB` : `${Math.max(1, Math.round(size / 1024))} KB`;
  }

  private goCreateKnowledge(): void {
    if (this.pickedFiles.length === 0) {
      this.showToast('请先选择文件');
      return;
    }
    this.showFilePick = false;
    const files: KBFileParam[] = this.pickedFiles.map((item: KBPickedFile): KBFileParam =>
      new KBFileParam(item.name, item.bytes));
    this.pathStack.pushPath({
      name: 'KnowledgeCreatePage',
      param: new KBCreatePageParam(files, this.statusBarHeight, this.naviIndicatorHeight),
      onPop: () => {
        this.loadRagDatasets();
      }
    });
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
      if (modelId.length === 0) { this.showToast('请先绑定模型'); return; }
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
        if (created.code !== 0) { this.showToast(created.msg || '提示词保存失败'); return; }
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
        if (response.code !== 0) { this.showToast(response.msg || '提示词保存失败'); return; }
      }
      await this.load();
      this.loadModelStats();
      this.showToast('已保存');
      return;
    }
    const title: string = this.suggestionTitle.trim();
    const content: string = this.suggestionContent.trim();
    if (title.length === 0 || content.length === 0) { this.showToast('标题与内容必填'); return; }
    if (this.selectedPromptKey.startsWith('new-')) {
      const payload: AdminPromptRequest = {
        role_scope: this.promptScenario, title: title, prompt: content, enabled: this.suggestionEnabled
      };
      const created = await ApiClient.post<AdminPromptSuggestion>('/admin/ai/prompts', payload);
      if (created.code !== 0 || created.data === undefined) {
        this.showToast(created.msg || '提示词创建失败');
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
    if (response.code !== 0) { this.showToast(response.msg || '提示词保存失败'); return; }
    await this.loadPromptSuggestions();
    this.showToast('已保存');
  }

  private async testBoundModel(): Promise<void> {
    const modelId: string = this.promptModel.trim();
    if (modelId.length === 0) { this.showToast('请先绑定模型'); return; }
    if (!this.connStatus.base_url_configured) {
      this.showToast('模型服务未配置：请在服务端 .env 设置 KXB_AI_BASE_URL');
      return;
    }
    try {
      // 地址与密钥由服务端环境变量持有，这里传空即回落到 .env 配置。
      const payload: AIModelProbeRequest = {
        base_url: '', api_key: '', models: [modelId]
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
    if (response.code !== 0) { this.showToast(response.msg || '提示词删除失败'); return; }
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
      { title: '工具', index: 2 },
      { title: '沙箱', index: 3 },
      { title: 'Skills 管理', index: 4 },
      { title: 'RAG 知识库', index: 5 },
      { title: '评估题库', index: 6 }
    ];
  }

  @Builder
  private sectionNav() {
    Row({ space: 10 }) {
      WideSlidingCapsule({
        items: this.sectionTabs(),
        selectedIndex: SECTION_IDS.indexOf(this.activeSection) < 0 ? 0 : SECTION_IDS.indexOf(this.activeSection),
        itemWidth: this.compactWidth ? 96 : 110,
        itemFontSize: 15,
        onSelect: (index: number) => {
          const next: string = SECTION_IDS[index] ?? 'models';
          const changed: boolean = next !== this.activeSection;
          this.activeSection = next;
          if (changed && next === 'rag') {
            this.loadRagDatasets();
          }
          if (changed && next === 'tools') {
            this.loadAgentTools();
            this.loadMcpServers();
          }
          if (changed && next === 'sandbox') {
            this.loadSandbox();
          }
        }
      })
      Blank()
      if (this.activeSection === 'rag') {
        Button('上传文件').height(38).fontSize(14).borderRadius(8)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .margin({ left: 12 })
          .onClick(() => this.openFilePickDialog())
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

  /** 只读连接状态角标：来自服务端 .env 的配置旗标。 */
  @Builder
  private connStatusChip(label: string, ok: boolean) {
    Row({ space: 6 }) {
      Row().width(8).height(8).borderRadius(4)
        .backgroundColor(ok ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
      Text(`${label} · ${ok ? '已连接' : '未配置'}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
    }.alignItems(VerticalAlign.Center)
  }

  @Builder
  private envUnconfiguredCard(title: string, hint: string, onRetry: () => void) {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(34).fontColor([$r('app.color.doctor_workspace_warning')])
      Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Text(hint).fontSize(13).fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center).width('100%')
      Text('重试').fontSize(14).fontColor($r('app.color.brand_blue'))
        .onClick(() => onRetry())
    }.width('100%').padding({ top: 32, bottom: 32 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private modelsModule() {
    Column({ space: 12 }) {
      this.connStatusChip('模型服务',
        this.connStatus.base_url_configured && this.connStatus.api_key_configured)
      if (!this.connStatus.base_url_configured) {
        this.envUnconfiguredCard('模型服务未配置',
          '模型服务连接已改由服务端统一配置。请在后端服务器 .env 中设置 KXB_AI_BASE_URL / KXB_AI_API_KEY，重启服务后重试。',
          (): void => {
            this.loadConnection();
            this.loadSourceModels();
          })
      } else if (this.sourceLoading) {
        Text('正在从模型服务获取模型列表…').fontSize(14).fontColor($r('sys.color.font_secondary'))
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
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.selectedPromptKey.startsWith('system-')) {
            Column({ space: 4 }) {
              this.promptEditorField('绑定模型')
              Select(this.modelOptionIds().map((item: string): SelectOption => ({ value: item } as SelectOption)))
                .selected(this.modelOptionIndex())
                .value(this.promptModel.length > 0 ? this.promptModel : '选择模型')
                .font({ size: 14 }).width('100%')
                .onSelect((index: number) => {
                  const ids: string[] = this.modelOptionIds();
                  if (index >= 0 && index < ids.length) { this.promptModel = ids[index]; }
                })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              this.promptEditorField('当前版本')
              Text(`最后更新 ${this.updatedDateText(this.defaultConfigOfRole(this.promptScenario)?.updated_at)}`)
                .fontSize(14).fontColor($r('sys.color.font_primary'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
        }.width('100%').alignItems(VerticalAlign.Top)

        if (this.selectedPromptKey.startsWith('system-')) {
          this.promptEditorField('系统提示词')
          TextArea({ text: $$this.promptText, placeholder: '输入系统提示词...' })
            .height(300).fontSize(13).width('100%')
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          Text('对话参数').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            .width('100%')
          Row({ space: 24 }) {
            Column({ space: 4 }) {
              this.promptEditorField('温度（temperature）')
              TextInput({ text: $$this.promptTemp }).height(38).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              this.promptEditorField('上下文长度（条）')
              TextInput({ text: $$this.promptContext }).height(38).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').alignItems(VerticalAlign.Top)
        } else {
          this.promptEditorField('标题')
          TextInput({ text: $$this.suggestionTitle, placeholder: '提示词标题...' }).height(40).width('100%')
          Row({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.suggestionEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.suggestionEnabled = isOn)
            Text(this.suggestionEnabled ? '启用' : '停用').fontSize(13).fontColor($r('sys.color.font_primary'))
          }.alignItems(VerticalAlign.Center)
          this.promptEditorField('提示词内容')
          TextArea({ text: $$this.suggestionContent, placeholder: '输入提示词内容...' })
            .height(280).fontSize(13).width('100%')
          if (this.selectedPromptKey.startsWith('sug-')) {
            Text('删除该提示词').fontSize(13).fontColor($r('app.color.doctor_workspace_danger'))
              .onClick(() => this.deleteSelectedSuggestion())
          }
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
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(item.description.trim().length > 0 ? item.description : 'Dify 知识库')
        .fontSize(12.5).fontColor($r('sys.color.font_secondary'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 8 }) {
        this.modelStatCell('文档数量', `${this.formatCount(item.document_count)} 篇`)
        this.modelStatCell('总字符数', item.word_count > 0 ? `${this.formatCount(Math.round(item.word_count / 10000))} 万` : '--')
        this.modelStatCell('最后更新', this.updatedDateText(item.updated_at))
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 10 }) {
        Text('嵌入模型').fontSize(12).fontColor($r('sys.color.font_secondary')).constraintSize({ minWidth: 68 })
        Text(item.embedding_model ?? '--')
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
      Row({ space: 10 }) {
        Text('索引方式').fontSize(12).fontColor($r('sys.color.font_secondary')).constraintSize({ minWidth: 68 })
        Text(item.indexing_technique === 'high_quality' ? '高质量' :
          item.indexing_technique === 'economy' ? '经济' :
          ((item.indexing_technique ?? '').length > 0 ? item.indexing_technique! : '--'))
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 14 }) {
        this.cardLink('管理文档', () => this.openRagDocs(item.id, item.name))
        this.cardLink('测试检索', () => this.openRetrieve(item.id))
        this.cardLink('设置', () => this.openKBSettings(item.id, item.name, item.description ?? ''))
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
      this.connStatusChip('Dify 知识库', this.connStatus.rag_configured)
      if (!this.connStatus.rag_configured) {
        this.envUnconfiguredCard('Dify 知识库未配置',
          'Dify RAG 连接已改由服务端统一配置。请在后端服务器 .env 中设置 KXB_DIFY_BASE_URL / KXB_DIFY_DATASET_ID / KXB_DIFY_API_KEY，重启服务后重试。',
          (): void => {
            this.loadConnection();
            this.loadRagDatasets();
          })
      } else if (this.ragLoading) {
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

  @Builder
  private mcpRow(server: McpServerRecord) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        Text(server.name).fontSize(13)
          .fontWeight(this.selectedMcpId === server.id ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('sys.color.font_primary')).layoutWeight(1).maxLines(1)
        Text(server.enabled ? (server.status === 'ok' ? '在线' : server.status === 'error' ? '异常' : '未探测') : '停用')
          .fontSize(11).fontColor(server.enabled && server.status === 'ok' ?
          $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          .backgroundColor(server.enabled && server.status === 'ok' ? '#F0FDF4' : $r('sys.color.comp_background_secondary'))
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(server.endpoint).fontSize(12).fontColor($r('sys.color.font_tertiary'))
        .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 9, bottom: 9 }).borderRadius(8)
    .border({ width: 0.5, color: this.selectedMcpId === server.id ?
      $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
    .backgroundColor(this.selectedMcpId === server.id ? '#F0F5FF' : $r('sys.color.comp_background_primary'))
    .onClick(() => this.selectMcpServer(server.id))
  }

  /** 工具模块 = 平台内置 Agent 工具清单 + MCP 服务注册管理。 */
  @Builder
  private toolsModule() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('平台内置工具').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('按调用者权限在运行时二次过滤').fontSize(11).fontColor($r('sys.color.font_tertiary'))
          Blank()
          Text('刷新').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.loadAgentTools())
        }.width('100%')
        if (this.toolsLoading) {
          Text('正在获取工具清单…').fontSize(13).fontColor($r('sys.color.font_secondary'))
            .width('100%').padding({ top: 16, bottom: 16 }).textAlign(TextAlign.Center)
        } else if (this.toolsError.length > 0) {
          Column({ space: 8 }) {
            Text(this.toolsError).fontSize(13).fontColor($r('sys.color.font_secondary'))
            Text('重试').fontSize(13).fontColor($r('app.color.brand_blue'))
              .onClick(() => this.loadAgentTools())
          }.width('100%').padding({ top: 12, bottom: 12 }).alignItems(HorizontalAlign.Center)
        } else {
          GridRow({ columns: 12, gutter: 12 }) {
            ForEach(this.agentTools, (tool: AgentToolInfo) => {
              GridCol({ span: this.compactWidth ? 12 : 6 }) {
                this.agentToolCard(tool)
              }
            }, (tool: AgentToolInfo) => `agent-tool-${tool.name}`)
          }.width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start)

      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Column({ space: 10 }) {
        Text('MCP 服务').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        this.mcpSection()
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private agentToolCard(tool: AgentToolInfo) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Row().width(8).height(8).borderRadius(4)
          .backgroundColor(tool.active ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
        Text(tool.name).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(tool.kind === 'knowledge' ? '知识库' : tool.kind === 'sandbox' ? '沙箱' : '数据')
          .fontSize(11).fontColor($r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          .backgroundColor($r('sys.color.comp_background_secondary'))
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(tool.description).fontSize(12).fontColor($r('sys.color.font_secondary'))
        .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 8 }) {
        Text(tool.mode === 'all' ? '通用模式' : '仅工作模式')
          .fontSize(11).fontColor($r('app.color.brand_blue'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          .backgroundColor('#F0F5FF')
        if (tool.permission.length > 0) {
          Text(`权限 ${tool.permission}`).fontSize(11).fontColor($r('sys.color.font_tertiary'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
            .backgroundColor($r('sys.color.comp_background_secondary'))
        }
        Blank()
        Text(tool.active ? '可用' : '未启用').fontSize(11)
          .fontColor(tool.active ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
    .accessibilityText(`工具${tool.name}，${tool.active ? '可用' : '未启用'}`)
  }

  /** 沙箱模块：运行状态 + 连接设置（密钥加密落库、留空保留）。 */
  @Builder
  private sandboxModule() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Text('运行状态').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Blank()
          Text(this.sbSource === 'db' ? '管理端配置' : '服务器 .env 默认')
            .fontSize(11).fontColor($r('sys.color.font_tertiary'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
            .backgroundColor($r('sys.color.comp_background_secondary'))
        }.width('100%')
        Row({ space: 8 }) {
          Row().width(8).height(8).borderRadius(4)
            .backgroundColor(this.sbEnabled && this.sbKeyConfigured ?
              $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
          Text(this.sbEnabled && this.sbKeyConfigured ? '已启用：工作模式 AI 可使用沙箱工具' :
            this.sbEnabled ? '已启用但密钥未配置，工具不可用' : '未启用：工作模式 AI 不带沙箱工具')
            .fontSize(13).fontColor($r('sys.color.font_primary'))
        }.width('100%')
        Text('沙箱工具（读写文件 / 执行 Shell）只在一次性隔离容器内运行：无宿主机目录挂载、默认禁止联网。')
          .fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
      }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text('连接设置').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          Blank()
          this.cardLink(this.sbProbing ? '探测中…' : '测试连通', () => this.probeSandbox())
          Button('保存').height(36).fontSize(13).borderRadius(8)
            .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
            .enabled(!this.sbBusy)
            .onClick(() => this.saveSandbox())
        }.width('100%').alignItems(VerticalAlign.Center)
        if (this.sbProbeHint.length > 0) {
          Text(this.sbProbeHint).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        }
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('启用沙箱').fontSize(12).fontColor($r('sys.color.font_secondary'))
            Row({ space: 8 }) {
              Toggle({ type: ToggleType.Switch, isOn: this.sbEnabled })
                .selectedColor($r('app.color.brand_blue'))
                .onChange((isOn: boolean) => { this.sbEnabled = isOn; })
              Text(this.sbEnabled ? '已启用' : '已停用').fontSize(13).fontColor($r('sys.color.font_primary'))
            }.alignItems(VerticalAlign.Center)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            Text('运行协议').fontSize(12).fontColor($r('sys.color.font_secondary'))
            Select([{ value: 'http' } as SelectOption, { value: 'https' } as SelectOption])
              .selected(this.sbProtocol === 'https' ? 1 : 0)
              .value(this.sbProtocol)
              .font({ size: 14 }).width('100%')
              .onSelect((index: number) => { this.sbProtocol = index === 1 ? 'https' : 'http'; })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
        Text('控制面地址').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        TextInput({ placeholder: '例如 10.10.1.12:18081', text: $$this.sbDomain })
          .height(40)
        Text('容器镜像').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        TextInput({ placeholder: 'python:3.12-slim', text: $$this.sbImage })
          .height(40)
        TextInput({ placeholder: this.sbKeyConfigured ? 'API Key（留空表示保留原密钥）' : 'API Key（尚未配置，必填）',
          text: $$this.sbApiKey })
          .height(40).type(InputType.Password)
        Text('保存后工作模式 AI 立即按新配置装配沙箱工具；密钥加密保存、不会回显。')
          .fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
      }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private mcpSection() {
    Row({ space: 12 }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('MCP 服务').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Blank()
          Text('＋ 新建').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.createMcpServer())
        }.width('100%')
        Scroll() {
          Column({ space: 6 }) {
            if (this.mcpServers.length === 0) {
              Text('暂无注册的 MCP 服务').fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
            }
            ForEach(this.mcpServers, (server: McpServerRecord) => {
              this.mcpRow(server)
            }, (server: McpServerRecord) => `mcp-${server.id}`)
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
          Text(this.selectedMcpId > 0 ? '编辑服务' : '注册服务')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          Blank()
          this.cardLink('探测', () => this.probeMcpServer())
          this.cardLink('删除', () => this.deleteMcpServer())
          Button('保存').height(36).fontSize(13).borderRadius(8)
            .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
            .onClick(() => this.saveMcpServer())
        }.width('100%').alignItems(VerticalAlign.Center)
        this.promptEditorField('名称')
        TextInput({ text: $$this.mcpName, placeholder: '例如：机构工具服务' }).height(40).width('100%')
        this.promptEditorField('端点（streamable HTTP）')
        TextInput({ text: $$this.mcpEndpoint, placeholder: 'https://host/mcp' }).height(40).width('100%')
        this.promptEditorField(this.selectedMcpId > 0 ? 'API Key（留空保持不变）' : 'API Key（可选）')
        TextInput({ text: $$this.mcpApiKey, placeholder: '密钥仅保存在服务器' }).type(InputType.Password).height(40).width('100%')
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Switch, isOn: this.mcpEnabled })
            .selectedColor($r('app.color.brand_blue'))
            .onChange((isOn: boolean) => this.mcpEnabled = isOn)
          Text(this.mcpEnabled ? '启用（工具注入对话/工作助手）' : '停用')
            .fontSize(13).fontColor($r('sys.color.font_primary'))
        }.width('100%')
        if (this.selectedMcp() !== undefined && (this.selectedMcp()?.last_probe_message ?? '').length > 0) {
          Text(`最近探测：${this.selectedMcp()?.last_probe_message ?? ''}`)
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        }
        Text('说明：MCP 工具经 streamable HTTP 桥接，模型可像内置工具一样调用；单服务超时 5 秒，不影响对话可用性。')
          .fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
      }.layoutWeight(1)
      .padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private skillRow(skill: SkillRecord) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        Text(skill.name).fontSize(13)
          .fontWeight(this.selectedSkillId === skill.id ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('sys.color.font_primary')).layoutWeight(1).maxLines(1)
        Text(this.roleTagLabel(skill.role_scope)).fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        Text(skill.enabled ? '启用' : '停用').fontSize(11)
          .fontColor(skill.enabled ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(skill.description.length > 0 ? skill.description : skill.code).fontSize(12)
        .fontColor($r('sys.color.font_tertiary')).width('100%').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 9, bottom: 9 }).borderRadius(8)
    .border({ width: 0.5, color: this.selectedSkillId === skill.id ?
      $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
    .backgroundColor(this.selectedSkillId === skill.id ? '#F0F5FF' : $r('sys.color.comp_background_primary'))
    .onClick(() => this.selectSkill(skill.id))
  }

  @Builder
  private skillsModule() {
    Row({ space: 12 }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('技能').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Blank()
          Text('＋ 新建').fontSize(13).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.createSkill())
        }.width('100%')
        Scroll() {
          Column({ space: 6 }) {
            if (this.skills.length === 0) {
              Text('暂无技能').fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
            }
            ForEach(this.skills, (skill: SkillRecord) => {
              this.skillRow(skill)
            }, (skill: SkillRecord) => `skill-${skill.id}`)
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
          Text(this.selectedSkillId > 0 ? '编辑技能' : '新建技能')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
          Blank()
          this.cardLink('删除', () => this.deleteSkill())
          Button('保存').height(36).fontSize(13).borderRadius(8)
            .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
            .onClick(() => this.saveSkill())
        }.width('100%').alignItems(VerticalAlign.Center)
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            this.promptEditorField('技能名称')
            TextInput({ text: $$this.skillName, placeholder: '例如：跌倒应急处置' }).height(40).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            this.promptEditorField('编码（内置技能不可改）')
            TextInput({ text: $$this.skillCode, placeholder: 'fall-response' }).enabled(!this.selectedSkill()?.is_builtin).height(40).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            this.promptEditorField('适用端')
            Select([{ value: '通用' } as SelectOption, { value: '护工端' } as SelectOption, { value: '医师端' } as SelectOption])
              .selected(this.skillRole === 'all' ? 0 : this.skillRole === 'caregiver' ? 1 : 2)
              .value(this.roleTagLabel(this.skillRole))
              .font({ size: 14 }).width('100%')
              .onSelect((index: number) => {
                this.skillRole = index === 1 ? 'caregiver' : index === 2 ? 'doctor' : 'all';
              })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
        this.promptEditorField('描述')
        TextInput({ text: $$this.skillDescription, placeholder: '一句话描述该技能的用途' }).height(40).width('100%')
        this.promptEditorField('技能指引（注入对应端助手的提示词片段）')
        TextArea({ text: $$this.skillInstructions, placeholder: '写给模型的执行要点...' })
          .height(220).fontSize(13).width('100%')
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Switch, isOn: this.skillEnabled })
            .selectedColor($r('app.color.brand_blue'))
            .onChange((isOn: boolean) => this.skillEnabled = isOn)
          Text(this.skillEnabled ? '启用' : '停用').fontSize(13).fontColor($r('sys.color.font_primary'))
        }.width('100%')
      }.layoutWeight(1)
      .padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private assessmentQuestionBankModule() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('语音评估题库').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(this.assessmentBank === null ? '用于入住后的评估 Agent' :
            `当前版本 V${this.assessmentBank!.version} · ${this.assessmentBank!.questions.length} 题`)
            .fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('重新加载').height(38).borderRadius(10)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .enabled(!this.assessmentBankLoading && !this.assessmentBankSaving)
          .onClick(() => this.loadAssessmentQuestionBank())
        Button(this.assessmentBankSaving ? '保存中…' : '保存新版本').height(38).borderRadius(10)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .enabled(!this.assessmentBankLoading && !this.assessmentBankSaving)
          .onClick(() => this.saveAssessmentQuestionBank())
      }.width('100%').alignItems(VerticalAlign.Center)

      Text('保持当前 JSON 结构：title、no_answer_timeout、questions；每题包含唯一 id、topic 和 question。保存后新评估使用新版本，进行中的评估不受影响。')
        .fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')

      if (this.assessmentBankLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(22).height(22)
          Text('正在加载评估题库…').fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.width('100%').padding(16)
      } else {
        TextArea({ placeholder: '评估题库 JSON', text: this.assessmentBankJson })
          .width('100%').height(520).fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .padding(16)
          .onChange((value: string): void => { this.assessmentBankJson = value; })
      }
      if (this.assessmentBankError.length > 0) {
        Text(this.assessmentBankError).fontSize(13).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  /** 测试检索：对绑定知识库发起 retrieve 并展示命中分段。 */
  @Builder
  private retrieveDialog() {
    Column({ space: 12 }) {
      Text('测试检索').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      TextInput({ placeholder: '输入测试问题...', text: $$this.retrieveQuery })
        .height(40).fontSize(13)
      Button(this.retrieveBusy ? '检索中…' : '检索').width('100%').height(40).fontSize(13)
        .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
        .onClick(() => this.runRetrieve())
      if (this.retrieveHint.length > 0) {
        Text(this.retrieveHint).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      }
      if (this.retrieveRecords.length > 0) {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.retrieveRecords, (record: RetrieveRecord, index: number) => {
              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text(`#${index + 1}`).fontSize(11).fontColor($r('sys.color.font_tertiary'))
                  Blank()
                  if (record.score !== undefined) {
                    Text(`相关度 ${record.score.toFixed(3)}`).fontSize(11)
                      .fontColor($r('app.color.brand_blue'))
                  }
                }.width('100%')
                Text(record.segment?.content ?? '')
                  .fontSize(12).fontColor($r('sys.color.font_primary'))
                  .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)
                .padding(10).borderRadius(8)
                .backgroundColor($r('sys.color.comp_background_secondary'))
            }, (record: RetrieveRecord, index: number) => `ret-${index}`)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.constraintSize({ maxHeight: 320 }).scrollBar(BarState.Off).width('100%')
      }
      Button('关闭').width('100%').height(40)
        .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick(() => { this.showRetrieve = false; })
    }.width(this.compactWidth ? '92%' : 520).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  /** 知识库设置：改名/描述与删除知识库。 */
  @Builder
  private kbSettingsDialog() {
    Column({ space: 12 }) {
      Text('知识库设置').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%')
      this.promptEditorField('知识库名称')
      TextInput({ text: $$this.kbSettingsName }).height(40).fontSize(13)
      this.promptEditorField('描述')
      TextArea({ text: $$this.kbSettingsDesc, placeholder: '知识库描述...' }).height(90).fontSize(13)
      Row({ space: 10 }) {
        Button(this.kbConfirmDelete ? '确认删除' : '删除知识库').height(40)
          .fontColor(this.kbConfirmDelete ? Color.White : $r('app.color.doctor_workspace_danger'))
          .backgroundColor(this.kbConfirmDelete ? $r('app.color.doctor_workspace_danger') :
            $r('sys.color.comp_background_secondary'))
          .enabled(!this.kbBusy)
          .onClick(() => this.deleteKB())
        Blank()
        Button('取消').height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showKBSettings = false; })
        Button('保存').height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .enabled(!this.kbBusy)
          .onClick(() => this.saveKBSettings())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 460).padding(24)
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
            } else if (this.activeSection === 'tools') {
              this.toolsModule()
            } else if (this.activeSection === 'sandbox') {
              this.sandboxModule()
            } else if (this.activeSection === 'skills') {
              this.skillsModule()
            } else if (this.activeSection === 'assessment') {
              this.assessmentQuestionBankModule()
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
      if (this.showRetrieve) {
        Row() { this.retrieveDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showKBSettings) {
        Row() { this.kbSettingsDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
      if (this.showFilePick) {
        Row() {
          Column({ space: 12 }) {
            Text('创建即用型知识库 · 选择文件').fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary')).width('100%')
            Text('已支持 PDF、DOCX、TXT、MD、CSV、XLSX、HTML 等，每批最多 5 个文件，每个不超过 15MB。')
              .fontSize(12).fontColor($r('sys.color.font_tertiary')).width('100%')
            Button('＋ 选择文件').width('100%').height(40).fontSize(13)
              .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
              .enabled(this.pickedFiles.length < 5)
              .onClick(() => this.pickKBFile())
            ForEach(this.pickedFiles, (item: KBPickedFile) => {
              Row({ space: 10 }) {
                Text(item.name).fontSize(13).fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.formatSize(item.size)).fontSize(12).fontColor($r('sys.color.font_tertiary'))
                Text('移除').fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
                  .onClick(() => this.removePickedFile(item.name))
              }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .borderRadius(8).border({ width: 0.5, color: $r('sys.color.comp_divider') })
                .backgroundColor($r('sys.color.comp_background_primary'))
            }, (item: KBPickedFile) => `picked-${item.name}`)
            Row({ space: 10 }) {
              Button('取消').layoutWeight(1).height(40)
                .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
                .onClick(() => { this.showFilePick = false; })
              Button('下一步').layoutWeight(1).height(40).fontSize(13)
                .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
                .enabled(this.pickedFiles.length > 0)
                .onClick(() => this.goCreateKnowledge())
            }.width('100%')
          }.width(this.compactWidth ? '92%' : 480).padding(24)
            .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
        }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
