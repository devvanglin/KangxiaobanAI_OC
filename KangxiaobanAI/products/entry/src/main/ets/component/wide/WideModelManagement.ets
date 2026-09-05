import ApiClient from '../../network/ApiClient';

interface AIModelConfig {
  id?: number; role_scope: string; name: string; provider: string; base_url: string; model: string; system_prompt: string;
  context_window: number; temperature: number; enabled: boolean; allowed: boolean; is_default: boolean; rag_enabled: boolean;
  rag_base_url: string; rag_dataset_id: string; api_key_configured?: boolean; rag_api_key_configured?: boolean;
}
interface AIConfigPage { list: AIModelConfig[]; }
interface AIConfigRequest { role_scope: string; name: string; provider: string; base_url: string; model: string; api_key: string; system_prompt: string; rag_enabled: boolean; rag_base_url: string; rag_dataset_id: string; enabled: boolean; allowed: boolean; is_default: boolean; }
interface StatCardParam { label: string; value: string; subtitle: string; }

const DARK_BUTTON_BG: string = '#1F1F1F';

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
  @Local systemPrompt: string = '你是康小伴智慧康养护理平台的照护助理，回答谨慎、贴题，仅作参考，不做临床诊断。';
  @Local ragEnabled: boolean = false;
  @Local ragBaseUrl: string = '';
  @Local ragDatasetId: string = '';
  @Local editorEnabled: boolean = true;
  @Local showEditor: boolean = false;
  @Local saved: boolean = false;
  @Local error: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    try {
      const response = await ApiClient.get<AIConfigPage>('/admin/ai/configs');
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      this.configs = response.data.list ?? [];
    } catch (_error) { this.error = 'AI 配置加载失败'; }
  }

  private configsOfRole(role: string): AIModelConfig[] {
    return this.configs.filter((item: AIModelConfig) => item.role_scope === role);
  }

  private defaultConfigOfRole(role: string): AIModelConfig | undefined {
    return this.configs.find((item: AIModelConfig) => item.role_scope === role && item.is_default) ??
      this.configs.find((item: AIModelConfig) => item.role_scope === role);
  }

  private roleLabel(role: string): string {
    return role === 'doctor' ? '医师 AI' : '护工 AI';
  }

  private enabledCount(): number {
    return this.configs.filter((item: AIModelConfig) => item.enabled).length;
  }

  private ragEnabledCount(): number {
    return this.configs.filter((item: AIModelConfig) => item.rag_enabled).length;
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
  }

  private async toggleEnabled(item: AIModelConfig): Promise<void> {
    const payload: AIConfigRequest = {
      role_scope: item.role_scope, name: item.name, provider: item.provider, base_url: item.base_url,
      model: item.model, api_key: '', system_prompt: item.system_prompt, rag_enabled: item.rag_enabled,
      rag_base_url: item.rag_base_url, rag_dataset_id: item.rag_dataset_id,
      enabled: !item.enabled, allowed: item.allowed, is_default: item.is_default
    };
    const response = await ApiClient.put<AIModelConfig>(`/admin/ai/configs/${item.id}`, payload);
    if (response.code !== 0) { this.error = response.msg || 'AI 配置更新失败'; return; }
    this.error = '';
    await this.load();
  }

  private async remove(item: AIModelConfig): Promise<void> {
    const response = await ApiClient.delete<Object>(`/admin/ai/configs/${item.id}`);
    if (response.code !== 0) { this.error = response.msg || 'AI 配置删除失败'; return; }
    this.error = '';
    if (this.configId === item.id) { this.configId = 0; }
    await this.load();
  }

  private openEditor(item?: AIModelConfig): void {
    this.error = '';
    this.saved = false;
    if (item !== undefined) {
      this.selectedRole = item.role_scope;
      this.configId = item.id ?? 0;
      this.provider = item.provider;
      this.baseUrl = item.base_url;
      this.modelName = item.model;
      this.systemPrompt = item.system_prompt;
      this.ragEnabled = item.rag_enabled;
      this.ragBaseUrl = item.rag_base_url;
      this.ragDatasetId = item.rag_dataset_id;
      this.editorEnabled = item.enabled;
    } else {
      this.selectedRole = 'caregiver';
      this.configId = 0;
      this.provider = 'local';
      this.baseUrl = '';
      this.modelName = 'kxb-local';
      this.systemPrompt = '你是康小伴智慧康养护理平台的照护助理，回答谨慎、贴题，仅作参考，不做临床诊断。';
      this.ragEnabled = false;
      this.ragBaseUrl = '';
      this.ragDatasetId = '';
      this.editorEnabled = true;
    }
    this.apiKey = '';
    this.showEditor = true;
  }

  @Builder
  private statCard($$: StatCardParam) {
    Column({ space: 6 }) {
      Text($$.label).fontSize(12).fontColor($r('sys.color.font_secondary'))
      Text($$.value).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text($$.subtitle).fontSize(11).fontColor($r('sys.color.font_tertiary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.alignItems(HorizontalAlign.Start)
      .width('100%').padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  private roleStatusValue(role: string): string {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    if (config === undefined) { return '未配置'; }
    return config.enabled ? '已启用' : '已停用';
  }

  private roleStatusSubtitle(role: string): string {
    const config: AIModelConfig | undefined = this.defaultConfigOfRole(role);
    if (config === undefined) { return '保存配置后生效'; }
    return `${config.provider} · ${config.model}`;
  }

  @Builder
  private statCards() {
    if (this.compactWidth) {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Row() { this.statCard({ label: '接入模型', value: String(this.configs.length), subtitle: `${this.enabledCount()} 个已启用` }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
          Row() { this.statCard({ label: '护工端', value: this.roleStatusValue('caregiver'), subtitle: this.roleStatusSubtitle('caregiver') }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        }.width('100%')
        Row({ space: 12 }) {
          Row() { this.statCard({ label: '医师端', value: this.roleStatusValue('doctor'), subtitle: this.roleStatusSubtitle('doctor') }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
          Row() { this.statCard({ label: 'RAG 知识库', value: `${this.ragEnabledCount()} 项启用`, subtitle: '检索适配完成后生效' }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        }.width('100%')
      }.width('100%')
    } else {
      Row({ space: 12 }) {
        Row() { this.statCard({ label: '接入模型', value: String(this.configs.length), subtitle: `${this.enabledCount()} 个已启用` }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        Row() { this.statCard({ label: '护工端', value: this.roleStatusValue('caregiver'), subtitle: this.roleStatusSubtitle('caregiver') }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        Row() { this.statCard({ label: '医师端', value: this.roleStatusValue('doctor'), subtitle: this.roleStatusSubtitle('doctor') }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
        Row() { this.statCard({ label: 'RAG 知识库', value: `${this.ragEnabledCount()} 项启用`, subtitle: '检索适配完成后生效' }) }.layoutWeight(1).alignItems(VerticalAlign.Top)
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
    Text(label).fontSize(13).fontColor(danger ? $r('app.color.doctor_workspace_danger') : $r('sys.color.font_primary'))
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .onClick(() => onTap())
  }

  @Builder
  private modelListCard() {
    Column({ space: 0 }) {
      Text('模型列表').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .width('100%').padding({ bottom: 6 })
      if (this.configs.length === 0) {
        Text('暂无模型配置，点击右上角「新增模型」为护工或医师创建配置。')
          .fontSize(12).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 20, bottom: 20 })
      } else {
        ForEach(this.configs, (item: AIModelConfig, index: number) => {
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(this.roleLabel(item.role_scope))
                    .fontSize(10).fontColor(Color.White)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .backgroundColor(item.role_scope === 'doctor' ? $r('app.color.doctor_workspace_accent') : $r('app.color.brand_blue'))
                  Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                }.alignItems(VerticalAlign.Center)
                Text(`${item.provider} · ${item.model}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
                if (item.base_url.length > 0) {
                  Text(item.base_url).fontSize(11).fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              this.statusBadge(item.enabled)
              this.actionText('配置', false, () => this.openEditor(item))
              this.actionText(item.enabled ? '停用' : '启用', false, () => this.toggleEnabled(item))
              this.actionText('删除', true, () => this.remove(item))
            }.width('100%').alignItems(VerticalAlign.Center)
            .constraintSize({ maxWidth: '100%' })
          }.width('100%').padding({ top: 14, bottom: 14 })
          if (index < this.configs.length - 1) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          }
        }, (item: AIModelConfig) => `ai-config-${item.id}`)
      }
    }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private apiKeyCard() {
    Column({ space: 12 }) {
      Text('API Key 管理').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text(`共 ${this.configs.length} 个角色密钥位：密钥仅在服务端加密存储，客户端不可查看。`)
        .fontSize(12).fontColor($r('sys.color.font_secondary'))
      ForEach(this.configs, (item: AIModelConfig, index: number) => {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(`${this.roleLabel(item.role_scope)}密钥`).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
              Text(item.api_key_configured ? 'sk-****（服务端加密存储，输入新值即更换）' : '未配置密钥，AI 调用将失败')
                .fontSize(12).fontColor($r('sys.color.font_secondary'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text(item.api_key_configured ? '已配置' : '未配置')
              .fontSize(11).fontColor(item.api_key_configured ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
            this.actionText('更换密钥', false, () => this.openEditor(item))
          }.width('100%').alignItems(VerticalAlign.Center)
          .constraintSize({ maxWidth: '100%' })
        }.width('100%').padding({ top: 10, bottom: 10 })
        if (index < this.configs.length - 1) {
          Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
        }
      }, (item: AIModelConfig) => `ai-key-${item.id}`)
      if (this.configs.length === 0) {
        Text('暂无配置。新增模型并保存 API Key 后，这里会显示密钥状态。')
          .fontSize(12).fontColor($r('sys.color.font_tertiary'))
      }
    }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ragCard() {
    Column({ space: 12 }) {
      Text('RAG 知识库').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text('每个模型可独立接入 Dify 知识库检索；当前检索适配完成后才会参与回答。')
        .fontSize(12).fontColor($r('sys.color.font_secondary'))
      if (this.configs.length === 0) {
        Text('暂无模型配置。新增模型后在配置里开启 RAG。')
          .fontSize(12).fontColor($r('sys.color.font_tertiary'))
      } else {
        ForEach(this.configs, (item: AIModelConfig, index: number) => {
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(this.roleLabel(item.role_scope))
                    .fontSize(10).fontColor(Color.White)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .backgroundColor(item.role_scope === 'doctor' ? $r('app.color.doctor_workspace_accent') : $r('app.color.brand_blue'))
                  Text('知识库接入').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                }.alignItems(VerticalAlign.Center)
                if (item.rag_enabled) {
                  Text(item.rag_base_url.length > 0 ? item.rag_base_url : '未填写 Dify URL')
                    .fontSize(12).fontColor($r('sys.color.font_secondary'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`数据集 ${item.rag_dataset_id.length > 0 ? item.rag_dataset_id : '未填写'} · RAG 密钥${item.rag_api_key_configured ? '已配置' : '未配置'}`)
                    .fontSize(11).fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                } else {
                  Text('未接入知识库检索，回答仅依赖模型本身。')
                    .fontSize(12).fontColor($r('sys.color.font_tertiary'))
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              this.statusBadge(item.rag_enabled)
              this.actionText('配置', false, () => this.openEditor(item))
            }.width('100%').alignItems(VerticalAlign.Center)
            .constraintSize({ maxWidth: '100%' })
          }.width('100%').padding({ top: 10, bottom: 10 })
          if (index < this.configs.length - 1) {
            Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
          }
        }, (item: AIModelConfig) => `ai-rag-${item.id}`)
      }
    }.width('100%').padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(12).border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private editorDialog() {
    Column({ space: 12 }) {
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Button('护工 AI').layoutWeight(1).height(36)
              .backgroundColor(this.selectedRole === 'caregiver' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
              .fontColor(this.selectedRole === 'caregiver' ? Color.White : $r('sys.color.font_secondary'))
              .onClick(() => this.selectedRole = 'caregiver')
            Button('医师 AI').layoutWeight(1).height(36)
              .backgroundColor(this.selectedRole === 'doctor' ? $r('app.color.brand_blue') : $r('sys.color.comp_background_secondary'))
              .fontColor(this.selectedRole === 'doctor' ? Color.White : $r('sys.color.font_secondary'))
              .onClick(() => this.selectedRole = 'doctor')
          }.width('100%')
          Row({ space: 14 }) {
            Column({ space: 6 }) {
              Text('Provider').fontSize(12).fontColor($r('sys.color.font_secondary'))
              Text(this.provider).fontSize(14).padding(10).borderRadius(6)
                .border({ width: 0.5, color: $r('sys.color.comp_divider') })
                .onClick(() => this.provider = this.provider === 'local' ? 'http' : 'local')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 6 }) {
              Text('模型名称').fontSize(12).fontColor($r('sys.color.font_secondary'))
              TextInput({ text: $$this.modelName, placeholder: '例如 qwen-plus' }).height(40).fontSize(13)
            }.layoutWeight(2).alignItems(HorizontalAlign.Start)
          }.width('100%')
          TextInput({ placeholder: 'API Base URL', text: $$this.baseUrl }).height(40)
          TextInput({ placeholder: 'API Key（留空表示保留原密钥）', text: $$this.apiKey }).height(40).type(InputType.Password)
          TextArea({ placeholder: '系统提示词', text: $$this.systemPrompt }).height(100).fontSize(13)
          Row({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.ragEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.ragEnabled = isOn)
            Text('启用 Dify RAG').fontSize(13).fontColor($r('sys.color.font_primary'))
            Text('检索适配后生效').fontSize(11).fontColor($r('sys.color.font_tertiary'))
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
      }.scrollBar(BarState.Off).constraintSize({ maxHeight: 420 }).width('100%')
      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => { this.showEditor = false; this.error = ''; })
        Button(this.saved ? '已保存' : '保存配置').layoutWeight(1).height(40).fontSize(13)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.save())
      }.width('100%')
    }.width(this.compactWidth ? '92%' : 520).padding(24)
      .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('大模型管理').fontSize(this.compactWidth ? 24 : 28).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              Text('护工和医师使用独立模型、API 与系统提示词；密钥只在服务端保存。')
                .fontSize(11).fontColor($r('sys.color.font_secondary'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Button('新增模型').height(38).fontSize(13).borderRadius(8)
              .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
              .onClick(() => this.openEditor())
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.error.length > 0 && !this.showEditor) {
            Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
          }
          this.statCards()
          this.modelListCard()
          this.ragCard()
          this.apiKeyCard()
        }.width('100%').padding({ left: this.compactWidth ? 16 : 28, right: this.compactWidth ? 16 : 28,
          top: 56 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      if (this.showEditor) {
        Row() { this.editorDialog() }.width('100%').height('100%')
          .backgroundColor('#66000000').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
