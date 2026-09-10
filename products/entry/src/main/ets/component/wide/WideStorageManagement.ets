import { media } from '@kit.MediaKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';
import Logger from '../../util/Logger';
import { ApiClient } from '../../network/ApiClient';
import { ApiConfig } from '../../network/ApiConfig';

const TAG: string = '[WideStorageManagement]';

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
  prefix: string;
  folders: StorageFolderInfo[];
  objects: StorageObject[];
}

interface StorageFolderInfo {
  name: string;
  prefix: string;
}

interface StoragePreviewsReq {
  keys: string[];
}

interface StoragePreviewsPage {
  urls: Record<string, string>;
}

interface StorageRenameReq {
  from_key: string;
  to_key: string;
}

interface StoragePreviewPage {
  url: string;
  expires_in: number;
}

interface StoragePlaybackFd {
  fd: number;
  length: number;
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
  @Local currentPrefix: string = '';
  @Local folders: StorageFolderInfo[] = [];
  @Local objectsLoading: boolean = false;
  @Local objectsError: string = '';
  @Local objects: StorageObject[] = [];
  @Local objectFilter: string = '';
  @Local previewUrls: Record<string, string> = {};
  @Local previewObject: StorageObject | null = null;
  @Local showMediaSheet: boolean = false;
  @Local audioPlaying: boolean = false;
  @Local audioReady: boolean = false;
  @Local audioCurrentMs: number = 0;
  @Local audioDurationMs: number = 0;
  @Local uploading: boolean = false;
  @Local downloading: string = '';
  @Local showRenameEditor: boolean = false;
  @Local renameFromKey: string = '';
  @Local renameValue: string = '';
  private videoController: VideoController = new VideoController();
  private audioPlayer: media.AVPlayer | null = null;
  private audioStateResolve: (() => void) | null = null;
  private audioStateReject: ((e: Error) => void) | null = null;
  // 播放走本地缓存文件：模拟器/部分设备的媒体服务进程拉网络流不可靠，
  // 先用应用进程下载，再以 fdSrc 交给 AVPlayer 本地播放。
  @Local playbackPreparing: boolean = false;
  @Local videoPlaybackPath: string = '';
  private playbackFd: number = -1;
  private playbackFilePath: string = '';

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

  /** 代理流地址是相对路径，拼上 API 基地址供播放器/图片/下载直连后端。 */
  private absoluteMediaUrl(path: string): string {
    return ApiConfig.API_BASE + path;
  }

  /** 单个媒体链接兜底：批量列表未覆盖时（如对象较多被截断）现取现存。 */
  private async resolveMediaUrl(bucket: string, key: string): Promise<string> {
    const cached: string | undefined = this.previewUrls[key];
    if (cached !== undefined && cached.length > 0) {
      return cached;
    }
    try {
      const response = await ApiClient.get<StoragePreviewPage>(
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/preview?key=${encodeURIComponent(key)}`);
      if (response.code === 0 && response.data !== undefined && response.data.url.length > 0) {
        const url: string = this.absoluteMediaUrl(response.data.url);
        const merged: Record<string, string> = {};
        const oldUrls = this.previewUrls;
        Object.keys(oldUrls).forEach((k: string): void => {
          merged[k] = oldUrls[k];
        });
        merged[key] = url;
        this.previewUrls = merged;
        return url;
      }
    } catch (_error) {
      // 网络失败时返回空串，由调用方提示。
    }
    return '';
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
    this.currentPrefix = '';
    this.objectFilter = '';
    this.loadObjects(name, '');
  }

  private async loadObjects(bucket: string, prefix: string = ''): Promise<void> {
    this.objectsLoading = true;
    this.objectsError = '';
    this.objects = [];
    this.folders = [];
    this.previewUrls = {};
    try {
      const prefixParam: string = prefix.length > 0 ? `&prefix=${encodeURIComponent(prefix)}` : '';
      const response = await ApiClient.get<StorageObjectPage>(
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/objects?max_keys=300${prefixParam}`);
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        this.objectsError = response.msg.length > 0 ? response.msg : '对象列表获取失败';
      } else {
        this.currentPrefix = response.data.prefix ?? prefix;
        this.folders = response.data.folders ?? [];
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

  private enterFolder(folder: StorageFolderInfo): void {
    this.selectBucketPrefix(folder.prefix);
  }

  private backToParentFolder(): void {
    if (this.currentPrefix.length === 0) {
      return;
    }
    const trimmed: string = this.currentPrefix.endsWith('/') ?
      this.currentPrefix.substring(0, this.currentPrefix.length - 1) : this.currentPrefix;
    const withoutSlash: string = trimmed;
    const index: number = withoutSlash.lastIndexOf('/');
    this.selectBucketPrefix(index >= 0 ? withoutSlash.substring(0, index + 1) : '');
  }

  private selectBucketPrefix(prefix: string): void {
    this.objectFilter = '';
    this.loadObjects(this.selectedBucket, prefix);
  }

  /** 批量换取图片/音频预签名链接，供缩略图与播放器直连 MinIO；单个失败不影响其余。 */
  private async fetchPreviewUrls(bucket: string, objects: StorageObject[]): Promise<void> {
    const keys: string[] = objects.filter((item: StorageObject): boolean => {
      return this.objectKind(item.key) !== 'file';
    }).slice(0, 100).map((item: StorageObject): string => item.key);
    if (keys.length === 0) {
      return;
    }
    try {
      const request: StoragePreviewsReq = { keys: keys };
      const response = await ApiClient.send<StoragePreviewsPage>('POST',
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/previews`, request);
      if (response.code === 0 && response.data !== undefined && response.data !== null) {
        const relative: Record<string, string> = response.data.urls ?? {};
        const absolute: Record<string, string> = {};
        Object.keys(relative).forEach((key: string): void => {
          absolute[key] = this.absoluteMediaUrl(relative[key]);
        });
        this.previewUrls = absolute;
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
    return this.objects.filter((item: StorageObject): boolean =>
      this.displayName(item.key).toLowerCase().includes(query));
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
    Logger.info(TAG, `open preview: ${item.key}`);
    if (this.objectKind(item.key) !== 'file') {
      this.previewObject = item;
      this.showMediaSheet = true;
    } else {
      this.showToast('该类型暂不支持预览');
    }
  }

  /** 预览对象变化：音频/视频先下载到缓存再播放，其他类型释放播放器。 */
  @Monitor('previewObject')
  onPreviewObjectChange(): void {
    if (this.previewObject === null) {
      this.videoPlaybackPath = '';
      void this.releaseAudio();
      return;
    }
    const kind: StorageObjectKind = this.objectKind(this.previewObject.key);
    if (kind === 'audio' || kind === 'video') {
      void this.startPlayback(kind, this.previewObject.key);
    } else {
      this.videoPlaybackPath = '';
      void this.releaseAudio();
    }
  }

  private async startPlayback(kind: StorageObjectKind, key: string): Promise<void> {
    const url: string = await this.resolveMediaUrl(this.selectedBucket, key);
    if (url.length === 0) {
      this.showToast('媒体预览链接不可用');
      return;
    }
    if (kind === 'audio') {
      await this.prepareAudio(url);
    } else {
      await this.prepareVideo(url);
    }
  }

  /** 视频同样走缓存文件：下载完成后以 file:// 交给 Video 组件播放。 */
  private async prepareVideo(url: string): Promise<void> {
    if (url.length === 0) {
      this.showToast('视频预览链接不可用');
      return;
    }
    await this.releaseAudio();
    this.playbackPreparing = true;
    this.videoPlaybackPath = '';
    try {
      const data: ArrayBuffer = await ApiClient.downloadBinary(url);
      if (data.byteLength === 0) {
        this.showToast('视频下载为空，请稍后重试');
        return;
      }
      const cache = await this.writePlaybackCache(data, '.mp4');
      this.videoPlaybackPath = `file://${this.playbackFilePath}?fd=${cache.fd}`;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      Logger.error(TAG, `prepareVideo failed: ${err.code} ${err.message}`);
      this.showToast(`视频加载失败(${err.code})`);
    } finally {
      this.playbackPreparing = false;
    }
  }

  private async releaseAudio(): Promise<void> {
    const player: media.AVPlayer | null = this.audioPlayer;
    this.audioPlayer = null;
    this.audioPlaying = false;
    this.audioReady = false;
    this.audioCurrentMs = 0;
    this.audioDurationMs = 0;
    this.audioStateResolve = null;
    this.audioStateReject = null;
    this.videoPlaybackPath = '';
    this.closePlaybackFd();
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

  aboutToDisappear(): void {
    void this.releaseAudio();
  }

  private async prepareAudio(url: string): Promise<void> {
    if (url.length === 0) {
      this.showToast('音频预览链接不可用');
      return;
    }
    await this.releaseAudio();
    this.playbackPreparing = true;
    if (canIUse('SystemCapability.Multimedia.Media.AVPlayer')) {
      try {
        const data: ArrayBuffer = await ApiClient.downloadBinary(url);
        if (data.byteLength === 0) {
          this.showToast('音频下载为空，请稍后重试');
          return;
        }
        const fdResult = await this.writePlaybackCache(data, '.mp3');
        // @SuppressWarnings syscap 能力档案已含 AVPlayer，命名空间检查误报
        const player: media.AVPlayer = await media.createAVPlayer();
        this.audioPlayer = player;
        player.on('stateChange', (state: media.AVPlayerState): void => {
          if (this.audioPlayer !== player) {
            return;
          }
          Logger.info(TAG, `audio state -> ${state}`);
          if (state === 'initialized') {
            // fdSrc 异步生效，进入 initialized 状态后才能 prepare。
            player.prepare().catch((e: BusinessError): void => {
              Logger.error(TAG, `audio prepare failed: ${e.code} ${e.message}`);
              this.audioPlaying = false;
            });
          } else if (state === 'prepared') {
            this.audioDurationMs = player.duration;
            this.audioReady = true;
            this.audioStateResolve?.();
          } else if (state === 'completed') {
            this.audioPlaying = false;
            this.audioCurrentMs = this.audioDurationMs;
          } else if (state === 'error') {
            Logger.error(TAG, 'audio state -> error');
            this.audioPlaying = false;
          }
        });
        player.on('timeUpdate', (time: number): void => {
          this.audioCurrentMs = time;
        });
        player.on('error', (error: BusinessError): void => {
          Logger.error(TAG, `audio player error event: ${error.code} ${error.message}`);
          this.audioPlaying = false;
        });
        const ready: Promise<void> = new Promise<void>((resolve: () => void, reject: (e: Error) => void) => {
          this.audioStateResolve = resolve;
          this.audioStateReject = reject;
          setTimeout((): void => reject(new Error('audio prepare timeout')), 10000);
        });
        player.fdSrc = { fd: fdResult.fd, offset: 0, length: fdResult.length };
        await ready;
        await player.play();
        this.audioPlaying = true;
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        Logger.error(TAG, `prepareAudio failed: ${err.code} ${err.message}`);
        this.showToast(`音频加载失败(${err.code})`);
      } finally {
        this.playbackPreparing = false;
      }
    } else {
      this.showToast('当前设备不支持音频播放');
      this.playbackPreparing = false;
    }
  }

  /** 把媒体内容写入缓存文件并打开 fd；fd 由 releaseAudio 统一关闭。 */
  private async writePlaybackCache(data: ArrayBuffer, extension: string): Promise<StoragePlaybackFd> {
    this.closePlaybackFd();
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      throw new Error('no cache dir');
    }
    const path: string = `${hostContext.cacheDir}/storage-preview${extension}`;
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data);
    } catch (error) {
      if (file !== undefined) {
        try { fs.closeSync(file.fd); } catch (_closeError) {}
      }
      const err: BusinessError = error as BusinessError;
      throw new Error(`写入播放缓存失败(${err.code})`);
    }
    this.playbackFilePath = path;
    this.playbackFd = file.fd;
    const result: StoragePlaybackFd = { fd: file.fd, length: data.byteLength };
    return result;
  }

  private closePlaybackFd(): void {
    if (this.playbackFd >= 0) {
      try {
        fs.closeSync(this.playbackFd);
      } catch (_error) {
        // Ignore double close.
      }
      this.playbackFd = -1;
    }
    if (this.playbackFilePath.length > 0) {
      try {
        fs.unlinkSync(this.playbackFilePath);
      } catch (_error) {
        // 文件不存在时忽略。
      }
      this.playbackFilePath = '';
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
    if (canIUse('SystemCapability.Multimedia.Media.Core')) {
      if (this.audioPlayer !== null && this.audioReady && ms >= 0) {
        // @SuppressWarnings syscap media.SeekMode 命名空间站点
        this.audioPlayer.seek(Math.floor(ms), media.SeekMode.SEEK_PREV_SYNC);
      }
    }
  }

  private formatMs(ms: number): string {
    const totalSeconds: number = Math.max(0, Math.floor(ms / 1000));
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private maxUploadBytes(): number {
    return 200 * 1024 * 1024;
  }

  private contentTypeFor(name: string): string {
    const lower: string = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lower.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }

  /** 上传：文件选择器选一个文件，以原文件名上传到当前桶根目录。 */
  private async pickAndUpload(): Promise<void> {
    if (this.selectedBucket.length === 0) {
      this.showToast('请先选择一个桶');
      return;
    }
    if (this.uploading || this.objectsLoading) {
      return;
    }
    let uris: string[] = [];
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker();
      uris = await documentPicker.select(options);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      if (err.code !== 14000011) {
        this.showToast('无法打开文件选择器');
      }
      return;
    }
    if (uris === undefined || uris.length === 0) {
      return;
    }
    const uri: string = uris[0];
    let name: string = this.displayName(uri);
    try {
      name = decodeURIComponent(name);
    } catch (_error) {
      // 未编码的 URI 直接使用原始段。
    }
    if (name.length === 0 || name.includes('/')) {
      this.showToast('文件名不能为空或包含 /');
      return;
    }
    this.uploading = true;
    let file: fs.File | undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const size: number = Number(fs.statSync(file.fd).size);
      if (!Number.isFinite(size) || size <= 0) {
        this.showToast('无法读取文件内容');
        return;
      }
      if (size > this.maxUploadBytes()) {
        this.showToast('文件超出 200MB 上传上限');
        return;
      }
      const data: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, data);
      const targetKey: string = this.currentPrefix + name;
      const request = await ApiClient.uploadBinary<object>(
        `/admin/storage/buckets/${encodeURIComponent(this.selectedBucket)}/objects`,
        data, this.contentTypeFor(name), { 'X-Object-Key': encodeURIComponent(targetKey) }, name);
      if (request.code !== 0) {
        this.showToast(request.msg.length > 0 ? request.msg : '上传失败');
      } else {
        this.showToast(`已上传 ${name}`);
        await this.loadBuckets();
        this.loadObjects(this.selectedBucket, this.currentPrefix);
      }
    } catch (error) {
      this.showToast('上传失败，请稍后重试');
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_error) {
          // Ignore double close.
        }
      }
      this.uploading = false;
    }
  }

  private openRenameEditor(item: StorageObject): void {
    this.renameFromKey = item.key;
    this.renameValue = this.displayName(item.key);
    this.showRenameEditor = true;
  }

  private async confirmRename(): Promise<void> {
    const newName: string = this.renameValue.trim();
    if (newName.length === 0) {
      this.showToast('请输入新的文件名');
      return;
    }
    if (newName.includes('/')) {
      this.showToast('文件名不能包含 /');
      return;
    }
    if (newName === this.displayName(this.renameFromKey)) {
      this.showToast('新名称与原名相同');
      return;
    }
    const index: number = this.renameFromKey.lastIndexOf('/');
    const toKey: string = index >= 0 ? `${this.renameFromKey.substring(0, index + 1)}${newName}` : newName;
    const bucket: string = this.selectedBucket;
    this.showRenameEditor = false;
    try {
      const request: StorageRenameReq = { from_key: this.renameFromKey, to_key: toKey };
      const response = await ApiClient.send<object>('POST',
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/objects/rename`, request);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '重命名失败');
      } else {
        this.showToast('已重命名');
        this.loadObjects(bucket, this.currentPrefix);
      }
    } catch (_error) {
      this.showToast('重命名失败，请稍后重试');
    }
  }

  private confirmDeleteObject(item: StorageObject): void {
    try {
      this.getUIContext().showAlertDialog({
        title: '删除对象',
        message: `将永久删除 ${item.key}，该操作不可恢复。确定删除吗？`,
        autoCancel: true,
        alignment: DialogAlignment.Center,
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        buttons: [
          {
            value: '取消',
            action: () => {
            }
          },
          {
            value: '删除',
            fontColor: $r('app.color.status_danger'),
            action: () => this.deleteObject(item.key)
          }
        ]
      });
    } catch (_error) {
      this.showToast('无法打开确认弹窗');
    }
  }

  private async deleteObject(key: string): Promise<void> {
    const bucket: string = this.selectedBucket;
    try {
      const response = await ApiClient.send<object>('DELETE',
        `/admin/storage/buckets/${encodeURIComponent(bucket)}/objects?key=${encodeURIComponent(key)}`);
      if (response.code !== 0) {
        this.showToast(response.msg.length > 0 ? response.msg : '删除失败');
      } else {
        this.showToast('已删除');
        await this.loadBuckets();
        this.loadObjects(bucket, this.currentPrefix);
      }
    } catch (_error) {
      this.showToast('删除失败，请稍后重试');
    }
  }

  /** 下载：先选保存位置，再经短期预签名链接取回内容写入用户选择的文件。 */
  private async downloadObject(item: StorageObject): Promise<void> {
    if (this.downloading.length > 0 || this.uploading) {
      return;
    }
    let uris: string[] = [];
    try {
      const saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [this.displayName(item.key)];
      const documentPicker = new picker.DocumentViewPicker();
      uris = await documentPicker.save(saveOptions);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      if (err.code !== 14000011) {
        this.showToast('无法打开保存窗口');
      }
      return;
    }
    if (uris === undefined || uris.length === 0) {
      return;
    }
    const targetUri: string = uris[0];
    this.downloading = item.key;
    let file: fs.File | undefined;
    try {
      const preview = await ApiClient.get<StoragePreviewPage>(
        `/admin/storage/buckets/${encodeURIComponent(this.selectedBucket)}/preview?key=${encodeURIComponent(item.key)}`);
      if (preview.code !== 0 || preview.data === undefined || preview.data.url.length === 0) {
        this.showToast(preview.msg.length > 0 ? preview.msg : '获取下载链接失败');
        return;
      }
      const data: ArrayBuffer = await ApiClient.downloadBinary(this.absoluteMediaUrl(preview.data.url));
      if (data.byteLength === 0) {
        this.showToast('下载内容为空，请稍后重试');
        return;
      }
      file = fs.openSync(targetUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data);
      this.showToast(`已下载 ${this.displayName(item.key)}`);
    } catch (_error) {
      this.showToast('下载失败，请稍后重试');
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_error) {
          // Ignore double close.
        }
      }
      this.downloading = '';
    }
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
  private folderCard(folder: StorageFolderInfo) {
    Column({ space: 8 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.folder_fill')).fontSize(42).fontColor([$r('app.color.brand_blue')])
      }
      .width('100%').height(110)
      .justifyContent(FlexAlign.Center)
      .borderRadius(12)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      Text(folder.name)
        .fontSize(13).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text('文件夹').fontSize(11).fontColor($r('sys.color.font_tertiary')).width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .onClick(() => this.enterFolder(folder))
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
        Blank()
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.square_and_arrow_down')).fontSize(15).fontColor([$r('sys.color.font_secondary')])
        }
        .width(28).height(28)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .opacity(this.downloading === item.key ? 0.45 : 1)
        .enabled(this.downloading !== item.key)
        .accessibilityText(`下载${this.displayName(item.key)}`)
        .onClick(() => this.downloadObject(item))
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(15).fontColor([$r('sys.color.font_secondary')])
        }
        .width(28).height(28)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .accessibilityText(`重命名${this.displayName(item.key)}`)
        .onClick(() => this.openRenameEditor(item))
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.trash')).fontSize(15).fontColor([$r('app.color.status_danger')])
        }
        .width(28).height(28)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .accessibilityText(`删除${this.displayName(item.key)}`)
        .onClick(() => this.confirmDeleteObject(item))
      }
      .width('100%')
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
        Button(this.uploading ? '上传中…' : '上传文件').height(36).fontSize(13).borderRadius(12)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .opacity(this.uploading || this.selectedBucket.length === 0 ? 0.45 : 1)
          .enabled(!this.uploading && this.selectedBucket.length > 0)
          .onClick(() => this.pickAndUpload())
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

        if (this.currentPrefix.length > 0) {
          Row({ space: 10 }) {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text('返回上一级').fontSize(13)
            }
            .height(32)
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => this.backToParentFolder())
            Text(`当前目录：${this.currentPrefix}`)
              .fontSize(12).fontColor($r('sys.color.font_tertiary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 24 })
          .margin({ bottom: 4 })
          .alignItems(VerticalAlign.Center)
        }

        if (this.folders.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.folders, (folder: StorageFolderInfo) => {
              Column() {
                this.folderCard(folder)
              }.margin({ right: 12, bottom: 4 }).width(200)
            }, (folder: StorageFolderInfo) => `folder-${folder.prefix}`)
          }.width('100%')
        }

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
          if (this.folders.length === 0) {
            Text(this.objectFilter.length > 0 ? '没有匹配的文件' : '该桶暂无内容')
              .fontSize(14).fontColor($r('sys.color.font_secondary'))
              .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
          }
        } else {
          this.objectGrid()
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 半模态预览窗：白底居中弹窗，展示图片/音频/视频。 */
  @Builder
  private mediaSheetDialog() {
    Column({ space: 16 }) {
      if (this.previewObject === null) {
        Text('').fontSize(1)
      } else if (this.objectKind(this.previewObject.key) === 'image') {
        Image(this.previewUrls[this.previewObject.key] ?? '')
          .width('100%').height(this.compactWidth ? 280 : 400)
          .objectFit(ImageFit.Contain).borderRadius(12)
      } else if (this.objectKind(this.previewObject.key) === 'video') {
        if (this.videoPlaybackPath.length > 0) {
          Video({
            src: this.videoPlaybackPath,
            controller: this.videoController
          })
            .width('100%').height(this.compactWidth ? 220 : 320)
            .autoPlay(true).controls(true).objectFit(ImageFit.Contain)
            .borderRadius(12).backgroundColor(Color.Black)
        } else {
          Column({ space: 10 }) {
            LoadingProgress().width(40).height(40).color($r('app.color.brand_blue'))
            Text('正在加载视频…').fontSize(13).fontColor($r('sys.color.font_secondary'))
          }.width('100%').height(this.compactWidth ? 220 : 320).justifyContent(FlexAlign.Center)
        }
      } else {
        Column({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.music_note_list')).fontSize(52).fontColor([$r('app.color.brand_blue')])
          if (this.playbackPreparing) {
            Row({ space: 8 }) {
              LoadingProgress().width(18).height(18).color($r('app.color.brand_blue'))
              Text('正在加载音频…').fontSize(12).fontColor($r('sys.color.font_secondary'))
            }
          } else {
            Text(`${this.formatMs(this.audioCurrentMs)} / ${this.formatMs(this.audioDurationMs)}`)
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
          }
          Slider({
            value: Math.min(this.audioCurrentMs, this.audioDurationMs > 0 ? this.audioDurationMs : 1),
            min: 0,
            max: this.audioDurationMs > 0 ? this.audioDurationMs : 1
          })
            .width('100%')
            .padding({ left: 8, right: 8 })
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.seekAudio(value);
              }
            })
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(this.audioPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(24).fontColor([Color.White])
          }
          .width(56).height(56)
          .backgroundColor($r('app.color.brand_blue'))
          .opacity(this.playbackPreparing ? 0.45 : 1)
          .enabled(!this.playbackPreparing)
          .onClick(() => this.toggleAudio())
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }
    }
    .width('100%').height('100%')
    .padding({ left: 24, right: 24, top: 8, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  /** 重命名半模态内容：文件名输入。 */
  @Builder
  private renameEditorDialog() {
    Column({ space: 16 }) {
      Text('重命名').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .width('100%')
      Text(this.renameFromKey)
        .fontSize(11).fontColor($r('sys.color.font_tertiary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      TextInput({ text: this.renameValue, placeholder: '输入新的文件名' })
        .width('100%').height(42)
        .onChange((value: string) => this.renameValue = value)
      Row({ space: 10 }) {
        Button('取消').height(40).borderRadius(12).fontSize(14).layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => this.showRenameEditor = false)
        Button('确定').height(40).borderRadius(12).fontSize(14).layoutWeight(1)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .onClick(() => this.confirmRename())
      }.width('100%')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 20, bottom: 24 })
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
      // 重命名半模态：宽窗口居中弹出，窄窗口自动退化为底部半模态。
      .bindSheet(this.showRenameEditor!!, this.renameEditorDialog(), {
        height: SheetSize.FIT_CONTENT,
        showClose: true,
        title: { title: '重命名文件' },
        preferType: SheetType.CENTER,
        enableOutsideInteractive: false,
        backgroundColor: $r('sys.color.comp_background_primary')
      })
      // 媒体预览半模态：白底居中弹窗，关闭时释放播放器。
      .bindSheet(this.showMediaSheet!!, this.mediaSheetDialog(), {
        width: this.compactWidth ? '90%' : '60%',
        height: 520,
        showClose: true,
        title: { title: this.previewObject === null ? '预览' : this.displayName(this.previewObject.key) },
        preferType: SheetType.CENTER,
        enableOutsideInteractive: false,
        backgroundColor: $r('sys.color.comp_background_primary'),
        onDisappear: () => {
          if (this.showMediaSheet) {
            this.showMediaSheet = false;
            this.previewObject = null;
          }
        }
      })
    }
  }
}