import { media } from '@kit.MediaKit';
import { ApiClient } from '../../network/ApiClient';

interface StorageBucket {
  name: string;
  creation_date: string;
  object_count: number;
  total_size: number;
}

interface StorageBucketPage {
  configured: boolean;
  buckets: StorageBucket[];
}

interface StorageObject {
  key: string;
  size: number;
  last_modified: string;
}

interface StorageObjectPage {
  bucket: string;
  objects: StorageObject[];
}

interface StoragePreviewsReq {
  keys: string[];
}

interface StoragePreviewsPage {
  urls: Record<string, string>;
}

type StorageObjectKind = 'image' | 'video' | 'audio' | 'file';

const IMAGE_EXTENSIONS: string[] = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'];
const VIDEO_EXTENSIONS: string[] = ['mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'];
const AUDIO_EXTENSIONS: string[] = ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'oga', 'opus'];

/** 管理端「存储」一级模块：MinIO/S3 对象存储只读预览（桶、桶内图片视频与文件）。 */
@ComponentV2
export struct WideStorageManagement {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param managementScroller: Scroller = new Scroller();

  @Local storageConfigured: boolean = true;
  @Local bucketsLoading: boolean = false;
  @Local bucketsError: string = '';
  @Local buckets: StorageBucket[] = [];
  @Local selectedBucket: string = '';
  @Local objectsLoading: boolean = false;
  @Local objectsError: string = '';
  @Local objects: StorageObject[] = [];
  @Local objectFilter: string = '';
  @Local previewUrls: Record<string, string> = {};
  @Local previewObject: StorageObject | null = null;
  @Local audioPlaying: boolean = false;
  @Local audioReady: boolean = false;
  @Local audioCurrentMs: number = 0;
  @Local audioDurationMs: number = 0;
  private videoController: VideoController = new VideoController();
  private audioPlayer: media.AVPlayer | null = null;

  aboutToAppear(): void {
    this.loadBuckets();
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (_error) {
      // Toast 展示失败时静默，不打断页面。
    }
  }

  private async loadBuckets(): Promise<void> {
    this.bucketsLoading = true;
    this.bucketsError = '';
    try {
      const response = await ApiClient.get<StorageBucketPage>('/admin/storage/buckets');
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        this.bucketsError = response.msg.length > 0 ? response.msg : '桶列表获取失败';
        this.buckets = [];
      } else if (!response.data.configured) {
        this.storageConfigured = false;
        this.buckets = [];
      } else {
        this.storageConfigured = true;
        this.buckets = response.data.buckets ?? [];
        if (this.selectedBucket.length === 0 && this.buckets.length > 0) {
          this.selectBucket(this.buckets[0].name);
        }
      }
    } catch (error) {
      this.bucketsError = error instanceof Error && error.message.length > 0 ? error.message : '桶列表获取失败';
      this.buckets = [];
    }
    this.bucketsLoading = false;
  }

  private selectBucket(name: string): void {
    this.selectedBucket = name;
    this.objectFilter = '';
    this.loadObjects(name);
  }

  private async loadObjects(bucket: string): Promise<void> {
    this.objectsLoading = true;
    this.objectsError = '';
    this.objects = [];
    this.previewUrls = {};
    try {
      const response = await ApiClient.get<StorageObjectPage>(
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/objects?max_keys=300`);
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        this.objectsError = response.msg.length > 0 ? response.msg : '对象列表获取失败';
      } else {
        const list: StorageObject[] = response.data.objects ?? [];
        // 最近修改的排前面，符合"先看新内容"的浏览习惯。
        this.objects = list.sort((a: StorageObject, b: StorageObject): number =>
          b.last_modified.localeCompare(a.last_modified));
        await this.fetchPreviewUrls(bucket, this.objects);
      }
    } catch (error) {
      this.objectsError = error instanceof Error && error.message.length > 0 ? error.message : '对象列表获取失败';
    }
    this.objectsLoading = false;
  }

  /** 批量换取图片/音频预签名链接，供缩略图与播放器直连 MinIO；单个失败不影响其余。 */
  private async fetchPreviewUrls(bucket: string, objects: StorageObject[]): Promise<void> {
    const keys: string[] = objects.filter((item: StorageObject): boolean => {
      const kind: StorageObjectKind = this.objectKind(item.key);
      return kind === 'image' || kind === 'audio';
    }).slice(0, 100).map((item: StorageObject): string => item.key);
    if (keys.length === 0) {
      return;
    }
    try {
      const request: StoragePreviewsReq = { keys: keys };
      const response = await ApiClient.send<StoragePreviewsPage>('POST',
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/previews`, request);
      if (response.code === 0 && response.data !== undefined && response.data !== null) {
        this.previewUrls = response.data.urls ?? {};
      }
    } catch (_error) {
      // 预签名失败时缩略图回退为文件图标，不打断列表浏览。
    }
  }

  private visibleObjects(): StorageObject[] {
    const query: string = this.objectFilter.trim().toLowerCase();
    if (query.length === 0) {
      return this.objects;
    }
    return this.objects.filter((item: StorageObject): boolean => item.key.toLowerCase().includes(query));
  }

  private objectKind(key: string): StorageObjectKind {
    const name: string = key.toLowerCase();
    if (IMAGE_EXTENSIONS.some((ext: string): boolean => name.endsWith(`.${ext}`))) {
      return 'image';
    }
    if (VIDEO_EXTENSIONS.some((ext: string): boolean => name.endsWith(`.${ext}`))) {
      return 'video';
    }
    if (AUDIO_EXTENSIONS.some((ext: string): boolean => name.endsWith(`.${ext}`))) {
      return 'audio';
    }
    return 'file';
  }

  private displayName(key: string): string {
    const index: number = key.lastIndexOf('/');
    return index >= 0 ? key.substring(index + 1) : key;
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    const kb: number = bytes / 1024;
    if (kb < 1024) {
      return `${kb.toFixed(1)} KB`;
    }
    const mb: number = kb / 1024;
    if (mb < 1024) {
      return `${mb.toFixed(1)} MB`;
    }
    return `${(mb / 1024).toFixed(2)} GB`;
  }

  private formatDate(iso: string): string {
    return iso.length >= 10 ? iso.slice(0, 10) : iso;
  }

  private openPreview(item: StorageObject): void {
    if (this.objectKind(item.key) !== 'file') {
      this.previewObject = item;
    } else {
      this.showToast('该类型暂不支持预览');
    }
  }

  /** 音频预览的 AVPlayer 生命周期：进出预览、切换对象时统一在这里创建/释放。 */
  @Monitor('previewObject')
  onPreviewObjectChange(): void {
    if (this.previewObject === null) {
      void this.releaseAudio();
      return;
    }
    if (this.objectKind(this.previewObject.key) === 'audio') {
      void this.prepareAudio(this.previewUrls[this.previewObject.key] ?? '');
    } else {
      void this.releaseAudio();
    }
  }

  aboutToDisappear(): void {
    void this.releaseAudio();
  }

  private async prepareAudio(url: string): Promise<void> {
    if (url.length === 0) {
      this.showToast('音频预览链接不可用');
      return;
    }
    await this.releaseAudio();
    try {
      const player: media.AVPlayer = await media.createAVPlayer();
      player.on('stateChange', (state: media.AVPlayerState): void => {
        if (state === 'prepared') {
          this.audioDurationMs = player.duration;
          this.audioReady = true;
        } else if (state === 'completed') {
          this.audioPlaying = false;
          this.audioCurrentMs = this.audioDurationMs;
        } else if (state === 'error') {
          this.audioPlaying = false;
        }
      });
      player.on('timeUpdate', (time: number): void => {
        this.audioCurrentMs = time;
      });
      player.url = url;
      await player.prepare();
      this.audioPlayer = player;
      await player.play();
      this.audioPlaying = true;
    } catch (_error) {
      this.audioPlaying = false;
      this.showToast('音频加载失败，请稍后重试');
    }
  }

  private async releaseAudio(): Promise<void> {
    const player: media.AVPlayer | null = this.audioPlayer;
    this.audioPlayer = null;
    this.audioPlaying = false;
    this.audioReady = false;
    this.audioCurrentMs = 0;
    this.audioDurationMs = 0;
    if (player === null) {
      return;
    }
    try {
      await player.stop();
    } catch (_error) {
      // 可能尚未进入 prepared，直接释放。
    }
    try {
      await player.release();
    } catch (_error) {
      // 已释放时忽略。
    }
  }

  private async toggleAudio(): Promise<void> {
    const player: media.AVPlayer | null = this.audioPlayer;
    if (player === null) {
      return;
    }
    try {
      if (this.audioPlaying) {
        await player.pause();
        this.audioPlaying = false;
      } else {
        await player.play();
        this.audioPlaying = true;
      }
    } catch (_error) {
      // 状态竞争时静默，下一次点击重试。
    }
  }

  private seekAudio(ms: number): void {
    if (this.audioPlayer !== null && this.audioReady && ms >= 0) {
      this.audioPlayer.seek(Math.floor(ms), media.SeekMode.SEEK_PREV_SYNC);
    }
  }

  private formatMs(ms: number): string {
    const totalSeconds: number = Math.max(0, Math.floor(ms / 1000));
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private cardColumns(): number {
    return this.compactWidth ? 2 : 3;
  }

  private cardRows(): StorageObject[][] {
    const columns: number = this.cardColumns();
    const items: StorageObject[] = this.visibleObjects();
    const rows: StorageObject[][] = [];
    for (let i = 0; i < items.length; i += columns) {
      rows.push(items.slice(i, i + columns));
    }
    return rows;
  }

  private rowFillers(rowLength: number): number[] {
    const fillers: number[] = [];
    for (let i = rowLength; i < this.cardColumns(); i++) {
      fillers.push(i);
    }
    return fillers;
  }

  @Builder
  private bucketChip(bucket: StorageBucket) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.folder_fill')).fontSize(15)
        .fontColor([this.selectedBucket === bucket.name ? Color.White : $r('sys.color.font_secondary')])
      Column({ space: 1 }) {
        Text(bucket.name).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(this.selectedBucket === bucket.name ? Color.White : $r('sys.color.font_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${bucket.object_count} 项 · ${this.formatSize(bucket.total_size)}`).fontSize(10)
          .fontColor(this.selectedBucket === bucket.name ? 'rgba(255,255,255,0.8)' : $r('sys.color.font_tertiary'))
      }.alignItems(HorizontalAlign.Start).constraintSize({ maxWidth: 200 })
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .borderRadius(16)
    .backgroundColor(this.selectedBucket === bucket.name ? $r('app.color.brand_blue') :
      $r('sys.color.comp_background_primary'))
    .border({ width: this.selectedBucket === bucket.name ? 0 : 0.5, color: $r('sys.color.comp_divider') })
    .onClick(() => this.selectBucket(bucket.name))
  }

  @Builder
  private objectTile(item: StorageObject) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.objectKind(item.key) === 'video') {
        Column({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.play_circle_fill')).fontSize(34).fontColor(['rgba(255,255,255,0.92)'])
          Text('视频').fontSize(10).fontColor('rgba(255,255,255,0.75)')
        }
      } else if (this.objectKind(item.key) === 'audio') {
        Column({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.music_note_list')).fontSize(30).fontColor(['rgba(255,255,255,0.9)'])
          Text('音频').fontSize(10).fontColor('rgba(255,255,255,0.75)')
        }
      } else if (this.objectKind(item.key) === 'file') {
        Column({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.doc_text')).fontSize(30).fontColor([$r('sys.color.font_tertiary')])
          Text('文件').fontSize(10).fontColor($r('sys.color.font_tertiary'))
        }
      } else {
        // 缩略图加载失败时露出底层的文件图标，不出现空白块。
        Column({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.doc_text')).fontSize(30).fontColor([$r('sys.color.font_tertiary')])
        }
        if (this.previewUrls[item.key] !== undefined && this.previewUrls[item.key].length > 0) {
          Image(this.previewUrls[item.key])
            .width('100%').height('100%').objectFit(ImageFit.Cover)
        }
      }
    }
    .width('100%').height(110)
    .borderRadius(12)
    .clip(true)
    .backgroundColor(this.objectKind(item.key) === 'video' || this.objectKind(item.key) === 'audio' ?
      '#202124' : $r('sys.color.comp_background_secondary'))
  }

  @Builder
  private objectCard(item: StorageObject) {
    Column({ space: 8 }) {
      this.objectTile(item)
      Text(this.displayName(item.key))
        .fontSize(13).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Row({ space: 6 }) {
        Text(this.formatSize(item.size)).fontSize(11).fontColor($r('sys.color.font_tertiary'))
        Text(this.formatDate(item.last_modified)).fontSize(11).fontColor($r('sys.color.font_tertiary'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .onClick(() => this.openPreview(item))
  }

  @Builder
  private objectGrid() {
    ForEach(this.cardRows(), (row: StorageObject[], rowIndex: number) => {
      Row({ space: 12 }) {
        ForEach(row, (item: StorageObject) => {
          Column() {
            this.objectCard(item)
          }.layoutWeight(1)
        }, (item: StorageObject) => `obj-${item.key}`)
        ForEach(this.rowFillers(row.length), (filler: number) => {
          Column().layoutWeight(1)
        }, (filler: number) => `obj-fill-${rowIndex}-${filler}`)
      }
      .width('100%').alignItems(VerticalAlign.Top)
    }, (row: StorageObject[], rowIndex: number) => `obj-row-${rowIndex}-${row.length}`)
  }

  @Builder
  private storageContent() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Text('存储').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Blank()
        Button('刷新').height(36).fontSize(13).borderRadius(12)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.buckets = [];
            this.selectedBucket = '';
            this.loadBuckets();
          })
      }.width('100%').alignItems(VerticalAlign.Center)

      if (this.bucketsLoading) {
        Text('正在连接对象存储…').fontSize(14).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
      } else if (!this.storageConfigured) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.archivebox_fill')).fontSize(42).fontColor([$r('sys.color.font_tertiary')])
          Text('对象存储未配置').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          Text('请在后端服务器 .env 中配置 KXB_MINIO_ENDPOINT / KXB_MINIO_ACCESS_KEY / KXB_MINIO_SECRET_KEY，并重启服务后重试。')
            .fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
            .constraintSize({ maxWidth: 460 })
        }.width('100%').padding({ top: 48, bottom: 48 }).alignItems(HorizontalAlign.Center)
      } else if (this.bucketsError.length > 0) {
        Column({ space: 12 }) {
          Text(this.bucketsError).fontSize(14).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
          Button('重试').height(36).fontSize(13).borderRadius(12)
            .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
            .onClick(() => this.loadBuckets())
        }.width('100%').padding({ top: 48, bottom: 48 }).alignItems(HorizontalAlign.Center)
      } else {
        if (this.buckets.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.buckets, (bucket: StorageBucket) => {
              this.bucketChip(bucket)
            }, (bucket: StorageBucket) => `bucket-${bucket.name}`)
          }.width('100%')
        }
        Row({ space: 10 }) {
          Search({ value: this.objectFilter, placeholder: this.selectedBucket.length > 0 ?
            `在 ${this.selectedBucket} 中搜索文件名` : '搜索文件名' })
            .height(38).width(260)
            .onChange((value: string) => this.objectFilter = value)
          Blank()
          Text(`${this.visibleObjects().length} 个对象`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }.width('100%').alignItems(VerticalAlign.Center)

        if (this.selectedBucket.length === 0) {
          Text('请选择一个桶查看内容').fontSize(14).fontColor($r('sys.color.font_secondary'))
            .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
        } else if (this.objectsLoading) {
          Text(`正在加载 ${this.selectedBucket} 的内容…`).fontSize(14).fontColor($r('sys.color.font_secondary'))
            .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
        } else if (this.objectsError.length > 0) {
          Column({ space: 12 }) {
            Text(this.objectsError).fontSize(14).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
            Button('重试').height(36).fontSize(13).borderRadius(12)
              .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
              .onClick(() => this.loadObjects(this.selectedBucket))
          }.width('100%').padding({ top: 32, bottom: 32 }).alignItems(HorizontalAlign.Center)
        } else if (this.visibleObjects().length === 0) {
          Text(this.objectFilter.length > 0 ? '没有匹配的文件' : '该桶暂无内容')
            .fontSize(14).fontColor($r('sys.color.font_secondary'))
            .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
        } else {
          this.objectGrid()
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private mediaPreview() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        if (this.previewObject !== null && this.objectKind(this.previewObject.key) === 'video') {
          Video({
            src: this.previewUrls[this.previewObject.key] ?? '',
            controller: this.videoController
          })
            .width('100%').layoutWeight(1)
            .autoPlay(true).controls(true).objectFit(ImageFit.Contain)
            .backgroundColor(Color.Black)
        } else if (this.previewObject !== null && this.objectKind(this.previewObject.key) === 'audio') {
          Column({ space: 22 }) {
            SymbolGlyph($r('sys.symbol.music_note_list')).fontSize(72).fontColor(['rgba(255,255,255,0.85)'])
            Text(this.displayName(this.previewObject.key))
              .fontSize(15).fontColor(Color.White).textAlign(TextAlign.Center)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '72%' })
            Text(`${this.formatMs(this.audioCurrentMs)} / ${this.formatMs(this.audioDurationMs)}`)
              .fontSize(12).fontColor('rgba(255,255,255,0.6)')
            Slider({
              value: Math.min(this.audioCurrentMs, this.audioDurationMs > 0 ? this.audioDurationMs : 1),
              min: 0,
              max: this.audioDurationMs > 0 ? this.audioDurationMs : 1
            })
              .width('72%')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  this.seekAudio(value);
                }
              })
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph(this.audioPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(28).fontColor([Color.White])
            }
            .width(64).height(64)
            .backgroundColor($r('app.color.brand_blue'))
            .onClick(() => this.toggleAudio())
          }
          .width('100%').layoutWeight(1)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        } else if (this.previewObject !== null) {
          Image(this.previewUrls[this.previewObject.key] ?? '')
            .width('100%').layoutWeight(1)
            .objectFit(ImageFit.Contain)
            .autoResize(true)
        }
      }.width('100%').height('100%')
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
        }
        .width(38).height(38)
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => this.previewObject = null)
        Text(this.previewObject === null ? '' : this.displayName(this.previewObject.key))
          .fontSize(14).fontColor(Color.White)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        if (this.previewObject !== null) {
          Text(this.formatSize(this.previewObject.size)).fontSize(12).fontColor('rgba(255,255,255,0.7)')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 8, bottom: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%').height('100%')
    .backgroundColor(Color.Black)
  }

  build() {
    Stack() {
      Scroll(this.managementScroller) {
        Column() {
          this.storageContent()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%', maxWidth: 1280 })
        .padding({
          left: this.compactWidth ? 16 : 28,
          right: this.compactWidth ? 16 : 28,
          top: 88 + this.statusBarHeight,
          bottom: 24 + this.naviIndicatorHeight
        })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    // 图片/视频全屏预览：黑底浮层，返回键与关闭按钮均可退出。
    .bindContentCover(this.previewObject !== null, this.mediaPreview(), {
      modalTransition: ModalTransition.DEFAULT,
      backgroundColor: Color.Black,
      onWillDisappear: () => this.previewObject = null
    })
  }
}