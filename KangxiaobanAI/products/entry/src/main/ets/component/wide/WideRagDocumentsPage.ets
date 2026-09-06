import ApiClient, { HttpMethod } from '../../network/ApiClient';
import pasteboard from '@ohos.pasteboard';
import { hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { ApiResp } from '../../network/Dto';

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
    if (item.indexing_status === 'completed') { return '已完成'; }
    if (item.indexing_status === 'error') { return '失败'; }
    return '解析中';
  }

  private docStatusColor(item: RagDocument): ResourceColor {
    if (item.indexing_status === 'completed') { return $r('app.color.doctor_workspace_success'); }
    if (item.indexing_status === 'error') { return $r('app.color.doctor_workspace_danger'); }
    return '#B45309';
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

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (_error) {
      // 展示失败静默。
    }
  }

  @Builder
  private docStatusBadge(item: RagDocument) {
    Text(this.docStatusText(item))
      .fontSize(11).fontColor(this.docStatusColor(item))
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(10).backgroundColor($r('sys.color.comp_background_secondary'))
  }

  @Builder
  private docRow(item: RagDocument, isLast: boolean) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Checkbox({ name: item.id ?? '' }).select(this.isSelected(item.id ?? ''))
          .selectedColor($r('app.color.brand_blue'))
          .onChange((value: boolean) => {
            if (value) { this.toggleSelected(item.id ?? ''); }
          })
        Text(item.name ?? '未命名文档')
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        this.docStatusBadge(item)
      }.width('100%').alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        if (item.word_count !== undefined) {
          Text(`${item.word_count} 字符`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }
        Blank()
        this.actionLink('分段', () => this.toggleChunks(item.id ?? ''))
        this.actionLink('下载', () => this.downloadDoc(item.id ?? ''))
        this.actionLink('删除', () => this.deleteDoc(item.id ?? ''), true)
      }.width('100%').alignItems(VerticalAlign.Center)

      if (this.expandedDocId === item.id) {
        Column({ space: 6 }) {
          if (this.chunksLoading) {
            Text('正在加载分段…').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          } else if (this.chunks.length === 0) {
            Text('该文档暂无分段').fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
          } else {
            ForEach(this.chunks, (chunk: RagChunk, index: number) => {
              Column({ space: 2 }) {
                Text(`#${index + 1} · ${chunk.status ?? ''} · ${chunk.word_count ?? 0} 字符`)
                  .fontSize(11).fontColor($r('sys.color.font_tertiary'))
                Text(chunk.content ?? '')
                  .fontSize(12).fontColor($r('sys.color.font_primary'))
                  .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)
                .padding(8).borderRadius(6)
                .backgroundColor($r('sys.color.comp_background_secondary'))
            }, (chunk: RagChunk, chunkIndex: number) => `chunk-${chunk.id ?? chunkIndex}`)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
        .padding(10).borderRadius(8)
        .backgroundColor($r('sys.color.comp_background_secondary'))
      }
    }.width('100%')
    .padding({ top: 12, bottom: 12, left: 14, right: 14 })
    .alignItems(HorizontalAlign.Start)
    if (!isLast) {
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider'))
    }
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
            Row({ space: 10 }) {
              Search({ value: $$this.keyword, placeholder: '搜索文档名称...' })
                .height(38).layoutWeight(1)
                .onChange((value: string) => this.keyword = value)
              Button('搜索').height(38).fontSize(13)
                .fontColor(Color.White).backgroundColor(DARK_BUTTON_BG)
                .onClick(() => this.loadDocs())
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
              Column({ space: 0 }) {
                ForEach(this.docs, (item: RagDocument, index: number) => {
                  this.docRow(item, index === this.docs.length - 1)
                }, (item: RagDocument) => `doc-${item.id}`)
              }.width('100%')
              .borderRadius(10)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })
              .clip(true)
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
            }.width('100%')

            if (this.hint.length > 0) {
              Text(this.hint).fontSize(12).fontColor($r('app.color.doctor_workspace_danger')).width('100%')
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 1280 })
          .padding({ left: 28, right: 28, top: 12, bottom: 40 + this.naviIndicatorHeight })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: this.datasetName } },
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
