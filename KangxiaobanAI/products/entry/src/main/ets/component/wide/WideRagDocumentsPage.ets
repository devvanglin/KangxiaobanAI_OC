import ApiClient, { HttpMethod } from '../../network/ApiClient';
import pasteboard from '@ohos.pasteboard';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsListItemCard,
  PrefixCustomBuilder,
  ScrollEffectType,
  SuffixCustomBuilder,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { ApiResp } from '../../network/Dto';
import { KBCreatePageParam, KBFileParam } from './WideKnowledgeCreatePage';

export class RagDocsPageParam {
  datasetId: string;
  datasetName: string;
  statusBarHeight: number;
  naviIndicatorHeight: number;

  constructor(datasetId: string, datasetName: string, statusBarHeight: number, naviIndicatorHeight: number) {
    this.datasetId = datasetId;
    this.datasetName = datasetName;
    this.statusBarHeight = statusBarHeight;
    this.naviIndicatorHeight = naviIndicatorHeight;
  }
}

interface RagDocument {
  id?: string;
  name?: string;
  indexing_status?: string;
  enabled?: boolean;
  archived?: boolean;
  word_count?: number;
  hit_count?: number;
  doc_form?: string;
  created_at?: string;
  updated_at?: string;
  display_status?: string;
}

interface RagChunk {
  id?: string;
  content?: string;
  status?: string;
  word_count?: number;
}

interface RetrievalSettings {
  search_method: string;
  reranking_enable: boolean;
  top_k: number;
  score_threshold_enabled: boolean;
}

interface RagStatusBatchRequest {
  document_ids: string[];
  action: string;
}

interface RagDocsListResponse {
  data?: RagDocument[];
}

interface RagDownloadResponse {
  download_url?: string;
}

interface RagChunksResponse {
  data?: RagChunk[];
}

const DARK_BUTTON_BG: string = '#1D63ED';
const KB_MAX_FILES: number = 5;
const KB_MAX_BYTES: number = 15 * 1024 * 1024;
const KB_EXTENSIONS: string[] =
  ['vtt', 'html', 'properties', 'markdown', 'md', 'xls', 'htm', 'mdx', 'pdf', 'csv', 'docx', 'txt', 'odt', 'xlsx'];

@ComponentV2
export struct WideRagDocumentsPage {
  @Param datasetId: string = '';
  @Param datasetName: string = '';
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Consumer('mainPageStack') pathStack: NavPathStack = new NavPathStack();
  @Local docs: RagDocument[] = [];
  @Local docsLoading: boolean = false;
  @Local docsError: string = '';
  @Local keyword: string = '';
  @Local selectedIds: string[] = [];
  @Local expandedDocId: string = '';
  @Local chunks: RagChunk[] = [];
  @Local chunksLoading: boolean = false;
  @Local busy: boolean = false;
  @Local hint: string = '';
  @Local categoryIndex: number = 0;
  @Local sortIndex: number = 0;
  @Local sortDescending: boolean = true;
  @Local menuDocId: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadDocs();
  }

  /** 知识库 API 通用代理调用。 */
  private async proxy<T>(method: HttpMethod, sub: string, query: string, payload?: Object): Promise<ApiResp<T>> {
    const path: string = '/admin/ai/rag/proxy/' + sub + (query.length > 0 ? '?' + query : '');
    return ApiClient.send<T>(method, path, payload);
  }

  private async loadDocs(): Promise<void> {
    this.docsLoading = true;
    this.docsError = '';
    try {
      const query: string = `page=1&limit=50` + (this.keyword.trim().length > 0 ? `&keyword=${this.keyword.trim()}` : '');
      const response = await this.proxy<RagDocsListResponse>('GET',
        `datasets/${this.datasetId}/documents`, query);
      if (response.code !== 0 || response.data === undefined) {
        this.docsError = response.msg.length > 0 ? response.msg : '文档列表加载失败';
        this.docs = [];
      } else {
        this.docs = response.data.data ?? [];
        if (this.docs.length === 0) { this.docsError = '该知识库暂无文档'; }
      }
    } catch (error) {
      this.docsError = error instanceof Error && error.message.length > 0 ? error.message : '文档列表加载失败';
      this.docs = [];
    }
    this.docsLoading = false;
  }

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

  private docStatusText(item: RagDocument): string {
    if (item.archived === true) { return '已归档'; }
    if (item.enabled === false) { return '已停用'; }
    if (item.indexing_status === 'completed') { return '可用'; }
    if (item.indexing_status === 'error') { return '失败'; }
    return '解析中';
  }

  private categoryOptions(): string[] {
    return ['全部', '可用', '解析中', '失败', '已归档'];
  }

  private sortOptions(): string[] {
    return ['上传时间', '字符数', '召回次数'];
  }

  private matchesCategory(item: RagDocument): boolean {
    const category: string = this.categoryOptions()[this.categoryIndex] ?? '全部';
    if (category === '全部') { return true; }
    if (category === '可用') { return item.enabled !== false && item.archived !== true && item.indexing_status === 'completed'; }
    if (category === '解析中') { return item.indexing_status !== 'completed' && item.indexing_status !== 'error' && item.archived !== true; }
    if (category === '失败') { return item.indexing_status === 'error'; }
    return item.archived === true;
  }

  private documentTime(item: RagDocument): string {
    const raw: string = item.created_at ?? item.updated_at ?? '';
    if (raw.length === 0) { return '--'; }
    const date: Date = new Date(raw);
    if (isNaN(date.getTime())) { return raw; }
    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private formatCount(value?: number): string {
    if (value === undefined || value === null || !Number.isFinite(value)) { return '--'; }
    if (value >= 1000000) { return `${(value / 1000000).toFixed(1).replace(/\.0$/, '')}m`; }
    if (value >= 1000) { return `${(value / 1000).toFixed(1).replace(/\.0$/, '')}k`; }
    return Math.max(0, Math.round(value)).toString();
  }

  private docFormLabel(item: RagDocument): string {
    const form: string = (item.doc_form ?? '').toLowerCase();
    if (form.indexOf('qa') >= 0) { return '问答'; }
    if (form.indexOf('hierarchical') >= 0 || form.indexOf('parent') >= 0) { return '父子'; }
    return '通用';
  }

  private visibleDocs(): RagDocument[] {
    const query: string = this.keyword.trim().toLowerCase();
    const result: RagDocument[] = this.docs.filter((item: RagDocument): boolean => {
      const name: string = (item.name ?? '').toLowerCase();
      return this.matchesCategory(item) && (query.length === 0 || name.indexOf(query) >= 0);
    });
    const direction: number = this.sortDescending ? -1 : 1;
    result.sort((left: RagDocument, right: RagDocument): number => {
      const option: string = this.sortOptions()[this.sortIndex] ?? '上传时间';
      if (option === '字符数') {
        return ((left.word_count ?? 0) - (right.word_count ?? 0)) * direction;
      }
      if (option === '召回次数') {
        return ((left.hit_count ?? 0) - (right.hit_count ?? 0)) * direction;
      }
      return (this.documentTime(left).localeCompare(this.documentTime(right))) * direction;
    });
    return result;
  }

  private isSelected(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelected(id: string): void {
    if (this.isSelected(id)) {
      this.selectedIds = this.selectedIds.filter((item: string) => item !== id);
    } else {
      this.selectedIds = this.selectedIds.concat(id);
    }
  }

  private async deleteDoc(docId: string): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.hint = '';
    try {
      const response = await this.proxy<Object>('DELETE',
        `datasets/${this.datasetId}/documents/${docId}`, '');
      if (response.code !== 0) {
        this.hint = response.msg || '文档删除失败';
      } else {
        this.showToast('文档已删除');
        this.selectedIds = this.selectedIds.filter((item: string) => item !== docId);
        await this.loadDocs();
      }
    } catch (_error) {
      this.hint = '文档删除失败，请检查网络';
    }
    this.busy = false;
  }

  private async downloadDoc(docId: string): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.hint = '';
    try {
      const response = await this.proxy<RagDownloadResponse>('GET',
        `datasets/${this.datasetId}/documents/${docId}/download`, '');
      if (response.code !== 0 || response.data === undefined) {
        this.hint = response.msg || '下载链接获取失败';
      } else {
        const url: string = response.data.download_url ?? '';
        if (url.length === 0) {
          this.hint = '该文档没有可下载的原始文件';
        } else {
          const pasteData: pasteboard.PasteData =
            pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
          pasteboard.getSystemPasteboard().setData(pasteData);
          this.showToast('下载链接已复制，可在浏览器打开');
        }
      }
    } catch (_error) {
      this.hint = '下载链接获取失败，请检查网络';
    }
    this.busy = false;
  }

  private async toggleChunks(docId: string): Promise<void> {
    if (this.expandedDocId === docId) {
      this.expandedDocId = '';
      this.chunks = [];
      return;
    }
    this.expandedDocId = docId;
    this.chunks = [];
    this.chunksLoading = true;
    try {
      const response = await this.proxy<RagChunksResponse>('GET',
        `datasets/${this.datasetId}/documents/${docId}/segments`, 'page=1&limit=20');
      if (response.code !== 0 || response.data === undefined) {
        this.hint = response.msg || '分段加载失败';
      } else {
        this.chunks = response.data.data ?? [];
      }
    } catch (_error) {
      this.hint = '分段加载失败，请检查网络';
    }
    this.chunksLoading = false;
  }

  private async applyStatus(action: string): Promise<void> {
    if (this.selectedIds.length === 0) {
      this.hint = '请先勾选文档';
      return;
    }
    if (this.busy) { return; }
    this.busy = true;
    this.hint = '';
    try {
      const payload: RagStatusBatchRequest = { document_ids: this.selectedIds, action: action };
      const response = await this.proxy<Object>('POST',
        `datasets/${this.datasetId}/documents/status`, '', payload);
      if (response.code !== 0) {
        this.hint = response.msg || '批量操作失败';
      } else {
        this.showToast('批量操作已完成');
        this.selectedIds = [];
        await this.loadDocs();
      }
    } catch (_error) {
      this.hint = '批量操作失败，请检查网络';
    }
    this.busy = false;
  }

  private async toggleEnabled(item: RagDocument): Promise<void> {
    const id: string = item.id ?? '';
    if (id.length === 0 || this.busy) { return; }
    this.selectedIds = [id];
    await this.applyStatus(item.enabled === false ? 'enable' : 'disable');
    this.selectedIds = [];
  }

  private async pickAndCreateKnowledge(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      const selected: string[] = await documentPicker.select(options);
      if (selected.length === 0) { return; }
      const uri: string = selected[0];
      const name: string = uri.substring(uri.lastIndexOf('/') + 1);
      const lowerName: string = name.toLowerCase();
      if (!KB_EXTENSIONS.some((ext: string) => lowerName.endsWith('.' + ext))) {
        this.showToast('不支持的文件类型');
        return;
      }
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(file.fd).size;
      if (size <= 0 || size > KB_MAX_BYTES) {
        fs.closeSync(file);
        this.showToast('文件大小需在 1-15MB 以内');
        return;
      }
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, bytes);
      fs.closeSync(file);
      const files: KBFileParam[] = [new KBFileParam(name, bytes)];
      if (files.length > KB_MAX_FILES) {
        this.showToast('每批最多 5 个文件');
        return;
      }
      this.pathStack.pushPath({
        name: 'KnowledgeCreatePage',
        param: new KBCreatePageParam(files, this.statusBarHeight, this.naviIndicatorHeight)
      });
    } catch (_error) {
      this.showToast('文件选择失败');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (_error) {
      // 展示失败静默。
    }
  }

  @Builder
  private docCheckbox(item: RagDocument, index: number) {
    Row({ space: 6 }) {
      Checkbox({ name: item.id ?? '' }).select(this.isSelected(item.id ?? ''))
        .selectedColor($r('app.color.brand_blue'))
        .width(26)
        .onChange((value: boolean) => {
          if (value) {
            this.toggleSelected(item.id ?? '');
          } else {
            this.selectedIds = this.selectedIds.filter((id: string) => id !== (item.id ?? ''));
          }
        })
      Text(`${index + 1}`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
    }.alignItems(VerticalAlign.Center)
  }

  @Builder
  private docActions(item: RagDocument) {
    Row({ space: 8 }) {
      Toggle({ type: ToggleType.Switch, isOn: item.enabled !== false && item.archived !== true })
        .selectedColor($r('app.color.brand_blue'))
        .onChange((value: boolean) => {
          if ((item.enabled !== false && item.archived !== true) !== value) {
            this.toggleEnabled(item);
          }
        })
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('⋮').fontSize(20).fontColor($r('sys.color.font_secondary'))
      }
        .width(36).height(36).padding(0).backgroundColor(Color.Transparent)
        .accessibilityText(`${item.name ?? '文档'}更多操作`)
        .onClick(() => this.menuDocId = item.id ?? '')
        .bindMenu(this.documentMenu, { placement: Placement.BottomRight, enableArrow: true })
    }.alignItems(VerticalAlign.Center)
  }

  @Builder
  private docRow(item: RagDocument, index: number) {
    HdsListItemCard({
      prefixItem: new PrefixCustomBuilder((): void => {
        this.docCheckbox(item, index);
      }),
      textItem: {
        primaryText: { text: item.name ?? '未命名文档' },
        secondaryText: {
          text: `${this.docStatusText(item)} · ${this.docFormLabel(item)} · ${this.formatCount(item.word_count)} 字符 · 召回 ${this.formatCount(item.hit_count)} · ${this.documentTime(item)}`
        }
      },
      suffixItem: new SuffixCustomBuilder((): void => {
        this.docActions(item);
      }),
      cardId: `rag-doc-${item.id ?? index}`,
      onClick: () => this.toggleChunks(item.id ?? '')
    })

    if (this.expandedDocId === item.id) {
      Column({ space: 6 }) {
        if (this.chunksLoading) {
          Text('正在加载分段…').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        } else if (this.chunks.length === 0) {
          Text('该文档暂无分段').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        } else {
          ForEach(this.chunks, (chunk: RagChunk, chunkIndex: number) => {
            Column({ space: 2 }) {
              Text(`#${chunkIndex + 1} · ${chunk.status ?? ''} · ${chunk.word_count ?? 0} 字符`)
                .fontSize(11).fontColor($r('sys.color.font_tertiary'))
              Text(chunk.content ?? '').fontSize(12).fontColor($r('sys.color.font_primary'))
                .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(8).borderRadius(6)
              .backgroundColor($r('sys.color.comp_background_secondary'))
          }, (chunk: RagChunk, chunkIndex: number) => `chunk-${chunk.id ?? chunkIndex}`)
        }
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .backgroundColor($r('sys.color.comp_background_secondary')).borderRadius(8)
        .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private documentMenu() {
    Menu() {
      MenuItem({ content: '查看分段' }).onClick(() => this.toggleChunks(this.menuDocId))
      MenuItem({ content: '下载原文件' }).onClick(() => this.downloadDoc(this.menuDocId))
      MenuItem({ content: '删除文档' }).contentFontColor($r('app.color.doctor_workspace_danger'))
        .onClick(() => this.deleteDoc(this.menuDocId))
    }.width(170).radius(12)
  }

  @Builder
  private actionLink(label: string, onTap: () => void, danger: boolean = false) {
    Text(label)
      .fontSize(13)
      .fontColor(danger ? $r('app.color.doctor_workspace_danger') : $r('app.color.brand_blue'))
      .onClick(() => onTap())
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text('知识库的所有文件都在这里显示，整个知识库可以链接到 Dify 引用或通过 Chat 插件进行索引。')
                .fontSize(14).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
              Text('了解更多').fontSize(14).fontColor($r('app.color.brand_blue'))
                .onClick(() => this.showToast('文档来源与索引能力由 Dify 知识库提供'))
            }.width('100%').alignItems(VerticalAlign.Center)

            Row({ space: 10 }) {
              Checkbox({ name: 'rag-docs-select-all' })
                .select(this.visibleDocs().length > 0 && this.selectedIds.length >= this.visibleDocs().length)
                .selectedColor($r('app.color.brand_blue'))
                .width(26)
                .onChange((value: boolean) => {
                  if (value) {
                    this.selectedIds = this.visibleDocs()
                      .map((item: RagDocument): string => item.id ?? '')
                      .filter((id: string) => id.length > 0);
                  } else {
                    this.selectedIds = [];
                  }
                })
                .accessibilityText('全选文档')
              Stack({ alignContent: Alignment.Center }) {
                Select(this.categoryOptions().map((item: string): SelectOption => ({ value: item } as SelectOption)))
                  .selected(this.categoryIndex).value(this.categoryOptions()[this.categoryIndex] ?? '全部')
                  .font({ size: 14 }).height(44).width(228).backgroundColor(Color.White)
                  .border({ width: 0.5, color: '#E4E7EB' }).borderRadius(10)
                  .onSelect((index: number) => this.categoryIndex = index)
                Text('×').fontSize(18).fontColor('#A5AAB2').position({ top: 0, right: 14 })
                  .onClick(() => this.categoryIndex = 0)
              }.width(228).height(44)
              Search({ value: $$this.keyword, placeholder: '搜索' })
                .height(44).width(286).backgroundColor('#F4F6F8').borderRadius(10)
                .onChange((value: string) => this.keyword = value)
              Divider().vertical(true).height(24).strokeWidth(1).color('#E5E7EB')
              Select(this.sortOptions().map((item: string): SelectOption => ({ value: `排序：${item}` } as SelectOption)))
                .selected(this.sortIndex).value(`排序：${this.sortOptions()[this.sortIndex] ?? '上传时间'}`)
                .font({ size: 14 }).height(44).width(190).backgroundColor('#F4F6F8').borderRadius(10)
                .onSelect((index: number) => this.sortIndex = index)
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text(this.sortDescending ? '↓' : '↑').fontSize(20).fontColor($r('sys.color.font_primary'))
              }.width(46).height(44).padding(0).borderRadius(10).backgroundColor('#F4F6F8')
                .accessibilityText(this.sortDescending ? '降序排列' : '升序排列')
                .onClick(() => this.sortDescending = !this.sortDescending)
              Blank()
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.doc_text')).fontSize(17).fontColor([$r('sys.color.font_primary')])
                  Text('元数据').fontSize(14).fontColor($r('sys.color.font_primary'))
                }
              }.height(44).padding({ left: 15, right: 15 }).borderRadius(10)
                .backgroundColor(Color.White).border({ width: 0.5, color: '#E4E7EB' })
                .onClick(() => this.showToast('元数据编辑请返回知识库设置'))
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.plus')).fontSize(18).fontColor([Color.White])
                  Text('添加文件').fontSize(14).fontColor(Color.White)
                }
              }.height(44).padding({ left: 16, right: 16 }).borderRadius(10)
                .backgroundColor(DARK_BUTTON_BG).onClick(() => this.pickAndCreateKnowledge())
            }.width('100%').alignItems(VerticalAlign.Center)

            if (this.docsLoading) {
              Text('正在加载文档列表…').fontSize(13).fontColor($r('sys.color.font_secondary'))
                .width('100%').padding({ top: 24, bottom: 24 }).textAlign(TextAlign.Center)
            } else if (this.docsError.length > 0) {
              Column({ space: 8 }) {
                Text(this.docsError).fontSize(13).fontColor($r('sys.color.font_secondary'))
                  .textAlign(TextAlign.Center).width('100%')
                Text('重试').fontSize(13).fontColor($r('app.color.brand_blue'))
                  .onClick(() => this.loadDocs())
              }.width('100%').padding({ top: 20, bottom: 20 })
            } else {
              List({ space: 6 }) {
                ForEach(this.visibleDocs(), (item: RagDocument, index: number) => {
                  ListItem() {
                    Column({ space: 4 }) {
                      this.docRow(item, index)
                    }.width('100%')
                  }
                }, (item: RagDocument) => `doc-${item.id}`)
              }
              .width('100%')
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }

            if (this.selectedIds.length > 0) {
              Text(`已勾选 ${this.selectedIds.length} 个`).fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
            }
            Row({ space: 10 }) {
              Button('批量启用').height(36).fontSize(12.5).borderRadius(8)
                .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
                .enabled(this.selectedIds.length > 0 && !this.busy)
                .onClick(() => this.applyStatus('enable'))
              Button('批量禁用').height(36).fontSize(12.5).borderRadius(8)
                .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
                .enabled(this.selectedIds.length > 0 && !this.busy)
                .onClick(() => this.applyStatus('disable'))
              Button('归档').height(36).fontSize(12.5).borderRadius(8)
                .fontColor($r('sys.color.font_primary')).backgroundColor($r('sys.color.comp_background_secondary'))
                .enabled(this.selectedIds.length > 0 && !this.busy)
                .onClick(() => this.applyStatus('archive'))
            }.width('100%').visibility(this.selectedIds.length > 0 ? Visibility.Visible : Visibility.Hidden)

            if (this.hint.length > 0) {
              Text(this.hint).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 1280 })
          .padding({
            left: 24,
            right: 24,
            top: 56 + this.statusBarHeight,
            bottom: 40 + this.naviIndicatorHeight
          })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: '文档' } },
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
