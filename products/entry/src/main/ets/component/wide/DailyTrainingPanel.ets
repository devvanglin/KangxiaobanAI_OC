// DailyTrainingPanel 每日认知训练（阿尔茨海默老人 · 10 分钟）。
// 素材由后端从 MinIO 训练桶按日随机采样：图片/音乐/视频混合播放。
import { media } from '@kit.MediaKit';
import ApiClient from '../../network/ApiClient';

interface TrainingItem {
  kind: string; // picture / music / video
  bucket: string;
  key: string;
  title: string;
  url: string;
  suggest_seconds: number;
}

interface TrainingSession {
  date: string;
  total_seconds: number;
  items: TrainingItem[];
}

const PROMPTS: Map<string, string> = new Map([
  ['picture', '看图说一说：画面里是什么？让长者回忆相关的故事。'],
  ['music', '怀旧金曲：跟着旋律轻轻哼唱，聊聊这首老歌的往事。'],
  ['video', '影音回味：一起看短片，看完聊聊里面的内容。']
]);

@ComponentV2
export struct DailyTrainingPanel {
  @Event onClose: () => void = () => {};
  @Local items: TrainingItem[] = [];
  @Local currentIndex: number = 0;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local remaining: number = 600;
  @Local finished: boolean = false;
  @Local musicPlaying: boolean = false;
  private timerId: number = -1;
  private audioPlayer: media.AVPlayer | null = null;

  aboutToAppear(): void {
    this.loadSession();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.releaseAudio();
  }

  private async loadSession(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      const response = await ApiClient.get<TrainingSession>('/training/daily');
      if (response.code !== 0 || response.data === undefined) {
        this.errorMsg = response.msg.length > 0 ? response.msg : '训练素材加载失败';
      } else {
        this.items = response.data.items ?? [];
        this.remaining = response.data.total_seconds > 0 ? response.data.total_seconds : 600;
        if (this.items.length === 0) {
          this.errorMsg = '训练素材库还是空的，请先在 MinIO 训练桶上传图片/音乐/视频。';
        } else {
          this.startTimer();
        }
      }
    } catch (_error) {
      this.errorMsg = '训练素材加载失败，请检查网络';
    }
    this.loading = false;
  }

  private startTimer(): void {
    this.stopTimer();
    this.timerId = setInterval((): void => {
      if (this.remaining <= 1) {
        this.stopTimer();
        this.releaseAudio();
        this.remaining = 0;
        this.finished = true;
        return;
      }
      this.remaining -= 1;
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private current(): TrainingItem | undefined {
    return this.items[this.currentIndex];
  }

  private clockText(): string {
    const m: number = Math.floor(this.remaining / 60);
    const s: number = this.remaining % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  private goTo(index: number): void {
    if (index < 0 || index >= this.items.length) { return; }
    this.releaseAudio();
    this.musicPlaying = false;
    this.currentIndex = index;
  }

  private async toggleMusic(url: string): Promise<void> {
    if (this.musicPlaying) {
      await this.releaseAudio();
      this.musicPlaying = false;
      return;
    }
    if (canIUse('SystemCapability.Multimedia.Media.AVPlayer')) {
      try {
        await this.releaseAudio();
        // @SuppressWarnings syscap 能力档案已含 AVPlayer，命名空间检查误报
        const player: media.AVPlayer = await media.createAVPlayer();
        this.audioPlayer = player;
        player.url = url;
        player.on('error', () => { this.musicPlaying = false; });
        player.play();
        this.musicPlaying = true;
      } catch (_error) {
        this.musicPlaying = false;
      }
    }
  }

  private async releaseAudio(): Promise<void> {
    const player: media.AVPlayer | null = this.audioPlayer;
    this.audioPlayer = null;
    if (player !== null) {
      try {
        await player.stop();
      } catch (_error) { }
      try {
        await player.release();
      } catch (_error) { }
    }
  }

  @Builder
  private emptyState(text: string, retry: boolean) {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(40).fontColor([$r('app.color.doctor_workspace_warning')])
      Text(text).fontSize(15).fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center).width('100%')
      if (retry) {
        Button('重试').height(40).borderRadius(20)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .onClick(() => this.loadSession())
      }
    }.width('100%').padding({ top: 60, bottom: 60 }).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private itemStage(item: TrainingItem) {
    Column({ space: 16 }) {
      Text(item.title).fontSize(20).fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary')).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.kind === 'picture') {
        Image(item.url)
          .objectFit(ImageFit.Contain)
          .width('100%').layoutWeight(1)
          .borderRadius(16)
      } else if (item.kind === 'music') {
        Column({ space: 18 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(168).height(168).borderRadius(84)
              .backgroundColor($r('sys.color.comp_background_secondary'))
            SymbolGlyph($r('sys.symbol.music_note_list'))
              .fontSize(72).fontColor([$r('app.color.brand_blue')])
          }
          Button(this.musicPlaying ? '暂停播放' : '播放音乐').height(44).borderRadius(22)
            .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
            .onClick(() => { void this.toggleMusic(item.url); })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Video({ src: item.url, previewUri: undefined, controller: undefined })
          .autoPlay(true).controls(true)
          .width('100%').layoutWeight(1)
          .borderRadius(16)
      }
      Text(PROMPTS.get(item.kind) ?? '')
        .fontSize(14).fontColor($r('sys.color.font_secondary'))
        .width('100%')
    }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text('每日训练').fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('认知训练 · 每天 10 分钟').fontSize(12).fontColor($r('sys.color.font_secondary'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(this.clockText()).fontSize(24).fontWeight(FontWeight.Bold)
            .fontColor(this.remaining <= 60 ? $r('app.color.doctor_workspace_warning') :
              $r('app.color.brand_blue'))
          Button('结束').height(38).borderRadius(19)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .onClick(() => this.onClose())
        }.width('100%').alignItems(VerticalAlign.Center)

        Progress({ value: this.items.length > 0 ? this.currentIndex + 1 : 0,
          total: this.items.length > 0 ? this.items.length : 1, type: ProgressType.Linear })
          .width('100%').color($r('app.color.brand_blue'))

        if (this.loading) {
          Column({ space: 12 }) {
            LoadingProgress().width(42).height(42).color($r('app.color.brand_blue'))
            Text('正在准备今日训练…').fontSize(14).fontColor($r('sys.color.font_secondary'))
          }.width('100%').padding({ top: 70, bottom: 70 })
        } else if (this.errorMsg.length > 0) {
          this.emptyState(this.errorMsg, true)
        } else if (this.finished) {
          Column({ space: 16 }) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(64).fontColor([$r('app.color.doctor_workspace_success')])
            Text('今日训练完成').fontSize(24).fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('辛苦啦，明天同一时间再来一起锻炼大脑吧。')
              .fontSize(14).fontColor($r('sys.color.font_secondary'))
            Button('好的，返回').height(44).borderRadius(22)
              .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
              .onClick(() => this.onClose())
          }.width('100%').padding({ top: 70, bottom: 70 })
        } else if (this.current() !== undefined) {
          this.itemStage(this.current()!)
          Row({ space: 16 }) {
            Button('上一项').height(42).borderRadius(21)
              .fontColor($r('sys.color.font_primary'))
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .enabled(this.currentIndex > 0)
              .onClick(() => this.goTo(this.currentIndex - 1))
            Text(`第 ${this.currentIndex + 1} / ${this.items.length} 项`)
              .fontSize(14).fontColor($r('sys.color.font_secondary'))
            Button(this.currentIndex + 1 < this.items.length ? '下一项' : '提前完成')
              .height(42).borderRadius(21)
              .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
              .enabled(this.currentIndex + 1 < this.items.length || !this.finished)
              .onClick(() => {
                if (this.currentIndex + 1 < this.items.length) {
                  this.goTo(this.currentIndex + 1);
                } else {
                  this.stopTimer();
                  this.releaseAudio();
                  this.finished = true;
                }
              })
          }.width('100%').justifyContent(FlexAlign.Center)
        }
      }
      .width('100%').height('100%')
      .padding({ left: 28, right: 28, top: 24, bottom: 24 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
