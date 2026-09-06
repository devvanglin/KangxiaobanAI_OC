import ApiClient from '../../network/ApiClient';
import { hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';

export class KBFileParam {
  name: string;
  bytes: ArrayBuffer;

  constructor(name: string, bytes: ArrayBuffer) {
    this.name = name;
    this.bytes = bytes;
  }
}

export class KBCreatePageParam {
  files: KBFileParam[];
  statusBarHeight: number;
  naviIndicatorHeight: number;

  constructor(files: KBFileParam[], statusBarHeight: number, naviIndicatorHeight: number) {
    this.files = files;
    this.statusBarHeight = statusBarHeight;
    this.naviIndicatorHeight = naviIndicatorHeight;
  }
}

interface RAGModelOption {
  model: string;
  label?: Record<string, string>;
  status?: string;
}

interface ProcessSegmentation {
  separator: string;
  max_tokens: number;
  chunk_overlap?: number;
}

interface ParentSegmentation {
  separator: string;
  max_tokens: number;
}

interface ProcessRuleSegmentation {
  parent_mode?: string;
  parent?: ParentSegmentation;
  segmentation: ProcessSegmentation;
}

interface ProcessRules {
  preprocess_rules: string[];
  segmentation: object;
}

interface ProcessRulePayload {
  mode: string;
  rules: ProcessRules;
}

interface UploadDataConfig {
  indexing_technique: string;
  doc_form: string;
  doc_language: string;
  embedding_model: string;
  process_rule: ProcessRulePayload;
}

interface RerankModelRef {
  reranking_model_name: string;
  reranking_model_provider: string;
}

interface RerankModeConfig {
  reranking_model: RerankModelRef;
}

interface RetrievalWeights {
  weight_type: string;
  semantic_embedding_weight: number;
  keyword_weight: number;
}

interface RetrievalModelConfig {
  search_method: string;
  reranking_enable: boolean;
  reranking_mode?: RerankModeConfig;
  weights?: RetrievalWeights;
  top_k: number;
  score_threshold_enabled: boolean;
  score_threshold: number;
}

interface CreateDatasetRequest {
  name: string;
  indexing_technique: string;
  embedding_model: string;
  retrieval_model: RetrievalModelConfig;
}

interface DatasetCreateResult {
  id?: string;
  name?: string;
  batch?: string;
}

interface IndexingStatusItem {
  indexing_status: string;
  completed_segments: number;
  total_segments: number;
}

interface IndexingStatusResponse {
  data?: IndexingStatusItem[];
}

const DARK_BUTTON_BG: string = '#1D63ED';

@ComponentV2
export struct WideKnowledgeCreatePage {
  @Param files: KBFileParam[] = [];
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local step: string = 'config';
  @Local kbName: string = '';
  @Local segmentMode: string = 'general';
  @Local parentMode: string = 'paragraph';
  @Local segSeparator: string = '\\n';
  @Local segMax: string = '1024';
  @Local segOverlap: string = '50';
  @Local childSeparator: string = '\\n';
  @Local childMax: string = '512';
  @Local removeSpaces: boolean = true;
  @Local removeUrls: boolean = false;
  @Local qaMode: boolean = false;
  @Local indexingTechnique: string = 'high_quality';
  @Local embeddingModels: RAGModelOption[] = [];
  @Local embeddingModel: string = '';
  @Local searchMethod: string = 'semantic_search';
  @Local rerankEnabled: boolean = true;
  @Local rerankModels: RAGModelOption[] = [];
  @Local rerankModel: string = '';
  @Local hybridRerankChoice: string = 'model';
  @Local hybridSemanticWeight: number = 0.7;
  @Local topK: string = '3';
  @Local scoreEnabled: boolean = false;
  @Local scoreThreshold: string = '0.5';
  @Local creating: boolean = false;
  @Local createError: string = '';
  @Local progressPercent: number = 0;
  @Local progressStatus: string = '等待处理';
  @Local createdName: string = '';
  private createdDatasetId: string = '';
  private createdBatch: string = '';
  private progressTimer: number = -1;
  private scroller: Scroller = new Scroller();

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

  aboutToAppear(): void {
    if (this.files.length > 0) {
      const first: string = this.files[0].name;
      this.kbName = first.includes('.') ? first.slice(0, first.lastIndexOf('.')) : first;
    }
    this.loadModels('text-embedding', true);
    this.loadModels('rerank', false);
  }

  aboutToDisappear(): void {
    if (this.progressTimer !== -1) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
  }

  private async loadModels(modelType: string, isEmbedding: boolean): Promise<void> {
    try {
      const path: string = modelType === 'rerank' ? '/admin/ai/rag/rerank-models' : '/admin/ai/rag/embedding-models';
      const response = await ApiClient.get<RAGModelOption[]>(path);
      if (response.code !== 0 || response.data === undefined) throw new Error(response.msg);
      if (isEmbedding) {
        this.embeddingModels = response.data;
        if (this.embeddingModels.length > 0) {
          this.embeddingModel = this.embeddingModels[0].model;
        }
      } else {
        this.rerankModels = response.data;
        if (this.rerankModels.length > 0) {
          this.rerankModel = this.rerankModels[0].model;
        }
      }
    } catch (_error) {
      // 模型列表获取失败时保留空列表，保存时会给出具体错误。
    }
  }

  private modelLabel(models: RAGModelOption[], modelId: string): string {
    const row: RAGModelOption | undefined = models.find((item: RAGModelOption) => item.model === modelId);
    if (row !== undefined && row.label !== undefined && row.label['zh_Hans'] !== undefined) {
      return row.label['zh_Hans'];
    }
    return modelId.length > 0 ? modelId : '选择模型';
  }

  private modelIndex(models: RAGModelOption[], modelId: string): number {
    const index: number = models.findIndex((item: RAGModelOption) => item.model === modelId);
    return index >= 0 ? index : 0;
  }

  private buildRetrievalModel(): RetrievalModelConfig {
    const topK: number = Math.max(1, Math.round(Number(this.topK) || 3));
    const threshold: number = Number(this.scoreThreshold) || 0.5;
    const config: RetrievalModelConfig = {
      search_method: this.searchMethod,
      reranking_enable: this.searchMethod !== 'semantic_search' && this.rerankEnabled,
      top_k: topK,
      score_threshold_enabled: this.scoreEnabled,
      score_threshold: this.scoreEnabled ? threshold : 0.5
    };
    if (this.searchMethod === 'hybrid_search' && this.rerankEnabled) {
      if (this.hybridRerankChoice === 'model' && this.rerankModel.length > 0) {
        config.reranking_mode = {
          reranking_model: { reranking_model_name: this.rerankModel, reranking_model_provider: 'langgenius/qwen/qwen3_reranker' }
        };
      } else {
        config.weights = {
          weight_type: 'custom',
          semantic_embedding_weight: this.hybridSemanticWeight,
          keyword_weight: Math.round((1 - this.hybridSemanticWeight) * 10) / 10
        };
      }
    }
    return config;
  }

  private buildProcessRule(): ProcessRulePayload {
    const preprocess: string[] = [];
    if (this.removeSpaces) { preprocess.push('remove_extra_spaces'); }
    if (this.removeUrls) { preprocess.push('remove_urls_emails'); }
    if (this.segmentMode === 'general') {
      const segmentation: ProcessSegmentation = {
        separator: this.segSeparator === '' ? '\\n' : this.segSeparator,
        max_tokens: Math.max(100, Math.round(Number(this.segMax) || 1024)),
        chunk_overlap: Math.max(0, Math.round(Number(this.segOverlap) || 50))
      };
      return { mode: 'custom', rules: { preprocess_rules: preprocess, segmentation: segmentation } };
    }
    const childSegmentation: ProcessSegmentation = {
      separator: this.childSeparator === '' ? '\\n' : this.childSeparator,
      max_tokens: Math.max(100, Math.round(Number(this.childMax) || 512))
    };
    if (this.parentMode === 'full_doc') {
      const fullDoc: ProcessRuleSegmentation = {
        parent_mode: 'full-doc',
        segmentation: childSegmentation
      };
      return { mode: 'custom', rules: { preprocess_rules: preprocess, segmentation: fullDoc } };
    }
    const parent: ParentSegmentation = {
      separator: this.segSeparator === '' ? '\\n\\n' : this.segSeparator,
      max_tokens: Math.max(100, Math.round(Number(this.segMax) || 1024))
    };
    const parentChild: ProcessRuleSegmentation = {
      parent_mode: 'paragraph',
      parent: parent,
      segmentation: childSegmentation
    };
    return { mode: 'custom', rules: { preprocess_rules: preprocess, segmentation: parentChild } };
  }

  private buildUploadData(): UploadDataConfig {
    return {
      indexing_technique: this.indexingTechnique,
      doc_form: this.segmentMode === 'parent_child' ? 'parent_child_index' : (this.qaMode ? 'qa_model' : 'text_model'),
      doc_language: 'Chinese Simplified',
      embedding_model: this.embeddingModel,
      process_rule: this.buildProcessRule()
    };
  }

  private async saveAndProcess(): Promise<void> {
    if (this.creating) { return; }
    if (this.kbName.trim().length === 0) { this.createError = '请填写知识库名称'; return; }
    if (this.files.length === 0) { this.createError = '未选择文件'; return; }
    if (this.embeddingModel.length === 0 && this.indexingTechnique === 'high_quality') {
      this.createError = '请选择 Embedding 模型';
      return;
    }
    this.creating = true;
    this.createError = '';
    try {
      const createPayload: CreateDatasetRequest = {
        name: this.kbName.trim(),
        indexing_technique: this.indexingTechnique,
        embedding_model: this.embeddingModel,
        retrieval_model: this.buildRetrievalModel()
      };
      const createResp = await ApiClient.post<DatasetCreateResult>('/admin/ai/rag/datasets/create', createPayload);
      if (createResp.code !== 0 || createResp.data === undefined) {
        this.createError = createResp.msg.length > 0 ? createResp.msg : '知识库创建失败';
        this.creating = false;
        return;
      }
      this.createdDatasetId = createResp.data.id ?? '';
      this.createdName = createResp.data.name ?? this.kbName.trim();
      const uploadData: string = JSON.stringify(this.buildUploadData());
      for (const file of this.files) {
        const upResp = await ApiClient.uploadBinary<Object>(
          `/admin/ai/rag/datasets/${this.createdDatasetId}/documents`,
          file.bytes, 'application/octet-stream', {}, file.name, uploadData);
        if (upResp.code !== 0) {
          this.createError = upResp.msg.length > 0 ? upResp.msg : '文档上传失败';
          this.creating = false;
          return;
        }
        const created = upResp.data as DatasetCreateResult;
        if (created !== undefined && created.batch !== undefined && created.batch.length > 0) {
          this.createdBatch = created.batch;
        }
      }
      this.step = 'created';
      this.startProgressPolling();
    } catch (_error) {
      this.createError = '创建失败，请检查网络';
    }
    this.creating = false;
  }

  private startProgressPolling(): void {
    if (this.progressTimer !== -1) { return; }
    this.refreshProgress();
    this.progressTimer = setInterval(() => { this.refreshProgress(); }, 3000);
  }

  private async refreshProgress(): Promise<void> {
    if (this.createdDatasetId.length === 0 || this.createdBatch.length === 0) { return; }
    try {
      const response = await ApiClient.get<IndexingStatusResponse>(
        `/admin/ai/rag/datasets/${this.createdDatasetId}/documents/${this.createdBatch}/indexing-status`);
      if (response.code !== 0 || response.data === undefined ||
        response.data.data === undefined || response.data.data.length === 0) {
        return;
      }
      let completed: number = 0;
      let total: number = 0;
      let failed: boolean = false;
      response.data.data.forEach((item: IndexingStatusItem): void => {
        completed += item.completed_segments;
        total += item.total_segments;
        if (item.indexing_status === 'error') { failed = true; }
      });
      this.progressStatus = failed ? '处理失败' :
        (total > 0 && completed >= total ? '处理完成' : '嵌入处理中...');
      this.progressPercent = total > 0 ? Math.round(completed / total * 100) : 0;
      if (failed || (total > 0 && completed >= total)) {
        if (this.progressTimer !== -1) {
          clearInterval(this.progressTimer);
          this.progressTimer = -1;
        }
      }
    } catch (_error) {
      // 单次轮询失败忽略，等下一轮。
    }
  }

  @Builder
  private stepBar() {
    Row({ space: 12 }) {
      Text('① 选择数据源').fontSize(13).fontColor(
        this.step === 'config' ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
      Text('——').fontSize(13).fontColor($r('sys.color.font_tertiary'))
      Text('② 文本分段与清洗').fontSize(13)
        .fontWeight(this.step === 'config' ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.step === 'config' ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
      Text('——').fontSize(13).fontColor($r('sys.color.font_tertiary'))
      Text('③ 处理并完成').fontSize(13)
        .fontWeight(this.step === 'created' ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.step === 'created' ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder
  private modeCard(title: string, desc: string, badge: string, selected: boolean, onSelect: () => void) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        if (badge.length > 0) {
          Text(badge).fontSize(11).fontColor($r('app.color.brand_blue'))
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .borderRadius(4).backgroundColor('#E8F0FE')
        }
      }.width('100%')
      Text(desc).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
    }.width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(10)
    .border({ width: selected ? 1.5 : 0.5, color: selected ? $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
    .backgroundColor(selected ? '#F0F5FF' : $r('sys.color.comp_background_primary'))
    .onClick(() => onSelect())
  }

  @Builder
  private fieldLabel(label: string) {
    Text(label).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
  }

  @Builder
  private configContent() {
    Column({ space: 14 }) {
      this.fieldLabel('知识库名称')
      TextInput({ text: $$this.kbName, placeholder: '默认取第一个文件名' }).height(40)

      Text('分段设置').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .width('100%')
      this.modeCard('通用', '通用文本分块模式，检索和召回的块是相同的', '', this.segmentMode === 'general',
        () => { this.segmentMode = 'general'; })
      this.modeCard('父子分段', '使用父子模式时，子块用于检索，父块用作上下文', '', this.segmentMode === 'parent_child',
        () => { this.segmentMode = 'parent_child'; })
      if (this.segmentMode === 'general') {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            this.fieldLabel('分段标识符')
            TextInput({ text: $$this.segSeparator }).height(38).width(120)
          }.alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            this.fieldLabel('分段最大长度')
            TextInput({ text: $$this.segMax }).height(38).width(120)
          }.alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            this.fieldLabel('分段重叠长度')
            TextInput({ text: $$this.segOverlap }).height(38).width(120)
          }.alignItems(HorizontalAlign.Start)
        }.width('100%')
      } else {
        this.modeCard('段落', '根据分隔符和最大块长度将文本拆分为段落，父块用作检索上下文',
          this.parentMode === 'paragraph' ? '已选' : '', this.parentMode === 'paragraph',
          () => { this.parentMode = 'paragraph'; })
        this.modeCard('全文', '整个文档作为父块并直接检索', this.parentMode === 'full_doc' ? '已选' : '',
          this.parentMode === 'full_doc', () => { this.parentMode = 'full_doc'; })
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            this.fieldLabel('子块分段标识符')
            TextInput({ text: $$this.childSeparator }).height(38).width(120)
          }.alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            this.fieldLabel('子块分段最大长度')
            TextInput({ text: $$this.childMax }).height(38).width(120)
          }.alignItems(HorizontalAlign.Start)
        }.width('100%')
      }
      Row({ space: 20 }) {
        Row({ space: 6 }) {
          Checkbox({ name: 'removeSpaces' }).select(this.removeSpaces)
            .selectedColor($r('app.color.brand_blue'))
            .onChange((value: boolean) => this.removeSpaces = value)
          Text('替换连续的空格、换行和制表符').fontSize(13).fontColor($r('sys.color.font_primary'))
        }.alignItems(VerticalAlign.Center)
        Row({ space: 6 }) {
          Checkbox({ name: 'removeUrls' }).select(this.removeUrls)
            .selectedColor($r('app.color.brand_blue'))
            .onChange((value: boolean) => this.removeUrls = value)
          Text('删除所有 URL 和电子邮件地址').fontSize(13).fontColor($r('sys.color.font_primary'))
        }.alignItems(VerticalAlign.Center)
      }.width('100%')
      Row({ space: 6 }) {
        Checkbox({ name: 'qaMode' }).select(this.qaMode)
          .selectedColor($r('app.color.brand_blue'))
          .onChange((value: boolean) => this.qaMode = value)
        Text('使用 Q&A 分段（语言：简体中文）').fontSize(13).fontColor($r('sys.color.font_primary'))
      }.width('100%')

      Text('索引方式').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .width('100%')
      Row({ space: 12 }) {
        Column() {
          this.modeCard('高质量', '调用嵌入模型处理文档以实现更精确的检索', '推荐', this.indexingTechnique === 'high_quality',
            () => { this.indexingTechnique = 'high_quality'; })
        }.layoutWeight(1)
        Column() {
          this.modeCard('经济', '每个数据块使用关键词检索，不消耗 tokens', this.indexingTechnique === 'economy' ? '已选' : '',
            this.indexingTechnique === 'economy', () => { this.indexingTechnique = 'economy'; })
        }.layoutWeight(1)
      }.width('100%')
      Text('使用高质量模式进行嵌入后，无法切换回经济模式。')
        .fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')

      this.fieldLabel('Embedding 模型')
      Select(this.embeddingModels.map((item: RAGModelOption): SelectOption =>
        ({ value: this.modelLabel(this.embeddingModels, item.model) } as SelectOption)))
        .selected(this.modelIndex(this.embeddingModels, this.embeddingModel))
        .value(this.modelLabel(this.embeddingModels, this.embeddingModel))
        .font({ size: 14 })
        .onSelect((index: number) => {
          if (index >= 0 && index < this.embeddingModels.length) {
            this.embeddingModel = this.embeddingModels[index].model;
          }
        })

      Text('检索设置').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .width('100%')
      this.modeCard('向量检索', '通过生成查询嵌入并查询与其向量表示最相似的文本分段', '', this.searchMethod === 'semantic_search',
        () => { this.searchMethod = 'semantic_search'; })
      this.modeCard('全文检索', '索引文档中的所有词汇，允许查询任意词汇', '', this.searchMethod === 'full_text_search',
        () => { this.searchMethod = 'full_text_search'; })
      this.modeCard('混合检索', '同时执行全文检索和向量检索，并应用重排序步骤', '推荐', this.searchMethod === 'hybrid_search',
        () => { this.searchMethod = 'hybrid_search'; })
      if (this.searchMethod !== 'semantic_search') {
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Switch, isOn: this.rerankEnabled })
            .selectedColor($r('app.color.brand_blue'))
            .onChange((isOn: boolean) => this.rerankEnabled = isOn)
          Text('Rerank 模型').fontSize(13).fontColor($r('sys.color.font_primary'))
        }.width('100%')
        if (this.rerankEnabled) {
          if (this.searchMethod === 'hybrid_search') {
            Row({ space: 12 }) {
              this.modeCard('权重设置', '调整语义与关键词的分配权重', this.hybridRerankChoice === 'weights' ? '已选' : '',
                this.hybridRerankChoice === 'weights', () => { this.hybridRerankChoice = 'weights'; })
              this.modeCard('Rerank 模型', '按重排模型重新排序候选结果', this.hybridRerankChoice === 'model' ? '已选' : '',
                this.hybridRerankChoice === 'model', () => { this.hybridRerankChoice = 'model'; })
            }.width('100%')
            if (this.hybridRerankChoice === 'weights') {
              Row({ space: 12 }) {
                Text('语义').fontSize(12).fontColor($r('sys.color.font_secondary'))
                Slider({ value: this.hybridSemanticWeight, min: 0, max: 1, step: 0.1 })
                  .layoutWeight(1)
                  .selectedColor($r('app.color.brand_blue'))
                  .onChange((value: number) => this.hybridSemanticWeight = Math.round(value * 10) / 10)
                Text(`关键词 ${Math.round((1 - this.hybridSemanticWeight) * 10) / 10}`)
                  .fontSize(12).fontColor($r('sys.color.font_secondary'))
              }.width('100%').alignItems(VerticalAlign.Center)
            }
          }
          Select(this.rerankModels.map((item: RAGModelOption): SelectOption =>
            ({ value: this.modelLabel(this.rerankModels, item.model) } as SelectOption)))
            .selected(this.modelIndex(this.rerankModels, this.rerankModel))
            .value(this.modelLabel(this.rerankModels, this.rerankModel))
            .font({ size: 14 })
            .onSelect((index: number) => {
              if (index >= 0 && index < this.rerankModels.length) {
                this.rerankModel = this.rerankModels[index].model;
              }
            })
        }
        Row({ space: 16 }) {
          Column({ space: 4 }) {
            this.fieldLabel('Top K')
            TextInput({ text: $$this.topK }).height(38).width(110)
          }.alignItems(HorizontalAlign.Start)
          Row({ space: 6 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.scoreEnabled })
              .selectedColor($r('app.color.brand_blue'))
              .onChange((isOn: boolean) => this.scoreEnabled = isOn)
            this.fieldLabel('Score 阈值')
            TextInput({ text: $$this.scoreThreshold }).enabled(this.scoreEnabled).height(38).width(110)
          }.alignItems(VerticalAlign.Center)
        }.width('100%')
      }

      if (this.createError.length > 0) {
        Text(this.createError).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
      }
      Row({ space: 12 }) {
        Button('← 上一步').height(40).fontSize(14)
          .fontColor($r('sys.color.font_secondary')).backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.pathStack.pop())
        Button(this.creating ? '处理中…' : '保存并处理').layoutWeight(1).height(40).fontSize(14)
          .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
          .onClick(() => this.saveAndProcess())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private createdContent() {
    Column({ space: 14 }) {
      Text('🎉 知识库已创建').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      this.fieldLabel('知识库名称')
      Text(this.createdName).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      Row({ space: 8 }) {
        Text('嵌入处理中').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text(this.progressStatus).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(6).borderRadius(3).backgroundColor($r('sys.color.comp_background_secondary'))
        Row().width(`${this.progressPercent}%`).height(6).borderRadius(3)
          .backgroundColor($r('app.color.brand_blue'))
      }.width('100%').height(6)
      Row({ space: 6 }) {
        Text(`${this.progressPercent}%`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        Blank()
        Text(`${this.files.length} 个文件`).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.width('100%')
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
      this.configSummaryRow('分段模式', this.segmentMode === 'general' ? '通用' :
        (this.parentMode === 'paragraph' ? '父子分段 · 段落' : '父子分段 · 全文'))
      this.configSummaryRow('最大分段长度', this.segmentMode === 'general' ?
        `${Math.round(Number(this.segMax) || 1024)}` :
        `父 ${Math.round(Number(this.segMax) || 1024)}；子 ${Math.round(Number(this.childMax) || 512)}`)
      this.configSummaryRow('索引方式', this.indexingTechnique === 'high_quality' ? '高质量' : '经济')
      this.configSummaryRow('检索设置', this.searchMethod === 'semantic_search' ? '向量检索' :
        this.searchMethod === 'full_text_search' ? '全文检索' : '混合检索')
      Button('返回知识库').width('100%').height(40).fontSize(14)
        .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
        .onClick(() => this.pathStack.pop())
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private configSummaryRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label).fontSize(13).fontColor($r('sys.color.font_secondary')).width(120)
      Text(value).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
    }.width('100%')
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll(this.scroller) {
          Row() {
            Column({ space: 16 }) {
              this.stepBar()
              if (this.step === 'config') {
                this.configContent()
              } else {
                this.createdContent()
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: 1280 })
            .padding({
              left: 28, right: 28,
              top: 12,
              bottom: 40 + this.naviIndicatorHeight
            })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
    }
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: '知识库' } },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
