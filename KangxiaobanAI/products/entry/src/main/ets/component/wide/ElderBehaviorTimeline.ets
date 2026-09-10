// ElderBehaviorTimeline 长者行为时间线（监控回放式）。
// 数据源：GET /elders/:id/behavior-events（InsightFace 认人 + EmotiEffLib/Qwen 表情 + JoyAI 行为，
// 脸图与视频片段存 MinIO cctv-footage-storage，URL 为服务端预签名地址）。
import ApiClient from '../../network/ApiClient';

interface BehaviorEventItem {
  id: number;
  elder_id: number;
  device_id: string;
  detected_at: string;
  behavior: string;
  expression: string;
  expression_source: string;
  emotieff_label: string;
  similarity: number;
  face_crop_object?: string;
  video_object?: string;
  face_crop_url?: string;
  video_url?: string;
  error?: string;
}

interface BehaviorEventPage { list: BehaviorEventItem[]; total: number; }

@ComponentV2
export struct ElderBehaviorTimeline {
  @Param elderId: number = 0;
  @Local events: BehaviorEventItem[] = [];
  @Local loading: boolean = false;
  @Local errorMsg: string = '';
  @Local selectedDay: string = ''; // YYYY-MM-DD；空 = 最新一天
  @Local playingEventId: number = -1;
  private loadedForElder: number = -1;

  aboutToAppear(): void {
    this.load();
  }

  @Monitor('elderId')
  onElderChange(): void {
    this.load();
  }

  private async load(): Promise<void> {
    if (this.elderId <= 0) { return; }
    this.loadedForElder = this.elderId;
    this.loading = true;
    this.errorMsg = '';
    this.playingEventId = -1;
    this.selectedDay = '';
    try {
      const response = await ApiClient.get<BehaviorEventPage>(
        `/elders/${this.elderId}/behavior-events?page=1&size=100`);
      if (response.code !== 0 || response.data === undefined) {
        this.errorMsg = response.msg.length > 0 ? response.msg : '行为记录加载失败';
        this.events = [];
      } else {
        this.events = response.data.list ?? [];
        this.selectedDay = this.dayChips().length > 0 ? this.dayChips()[0] : '';
      }
    } catch (_error) {
      this.errorMsg = '行为记录加载失败，请检查网络';
      this.events = [];
    }
    this.loading = false;
  }

  private dayOf(event: BehaviorEventItem): string {
    return (event.detected_at ?? '').slice(0, 10);
  }

  private timeOf(event: BehaviorEventItem): string {
    const stamp: string = event.detected_at ?? '';
    return stamp.length >= 19 ? stamp.slice(11, 19) : stamp;
  }

  private dayChips(): string[] {
    const days: string[] = [];
    this.events.forEach((event: BehaviorEventItem) => {
      const day: string = this.dayOf(event);
      if (day.length > 0 && !days.includes(day)) {
        days.push(day);
      }
    });
    return days;
  }

  private dayEvents(): BehaviorEventItem[] {
    return this.events.filter((event: BehaviorEventItem) => this.dayOf(event) === this.selectedDay);
  }

  private expressionBadgeColor(event: BehaviorEventItem): ResourceColor {
    if (event.expression === '高兴' || event.expression === '满意') {
      return $r('app.color.doctor_workspace_success');
    }
    if (event.expression === '悲伤' || event.expression === '恐惧' || event.expression === '愤怒') {
      return $r('app.color.doctor_workspace_warning');
    }
    return $r('sys.color.font_secondary');
  }

  private togglePlay(event: BehaviorEventItem): void {
    if ((event.video_url ?? '').length === 0) { return; }
    this.playingEventId = this.playingEventId === event.id ? -1 : event.id;
  }

  @Builder
  private dayChipsRow() {
    Row({ space: 8 }) {
      ForEach(this.dayChips(), (day: string) => {
        Text(day === new Date().toISOString().slice(0, 10) ? '今天' : day.slice(5))
          .fontSize(13)
          .fontColor(this.selectedDay === day ? Color.White : $r('sys.color.font_primary'))
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(this.selectedDay === day ? '#1D63ED' : $r('sys.color.comp_background_secondary'))
          .onClick(() => { this.selectedDay = day; this.playingEventId = -1; })
      }, (day: string) => `day-${day}`)
      Blank()
      SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(15)
        .fontColor([$r('sys.color.font_secondary')])
        .onClick(() => this.load())
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder
  private eventRow(event: BehaviorEventItem, showDivider: boolean) {
    Row({ space: 12 }) {
      Text(this.timeOf(event)).fontSize(13).fontColor($r('sys.color.font_secondary'))
        .width(64)
        .constraintSize({ minWidth: 64 })
      // 时间轴竖线
      Column() {
        Row().width(2).height(14).backgroundColor($r('sys.color.comp_divider'))
        Row().width(8).height(8).borderRadius(4)
          .backgroundColor($r('app.color.brand_blue'))
        Row().width(2).layoutWeight(1).backgroundColor($r('sys.color.comp_divider'))
      }.width(8).height(showDivider ? 120 : 96).alignItems(HorizontalAlign.Center)

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          if ((event.face_crop_url ?? '').length > 0) {
            Image(event.face_crop_url)
              .width(52).height(52).borderRadius(10).objectFit(ImageFit.Cover)
          } else {
            Stack({ alignContent: Alignment.Center }) {
              Row().width(52).height(52).borderRadius(10)
                .backgroundColor($r('sys.color.comp_background_secondary'))
              SymbolGlyph($r('sys.symbol.questionmark_circle'))
                .fontSize(24).fontColor([$r('sys.color.icon_secondary')])
            }
          }
          Column({ space: 3 }) {
            Text(event.behavior.length > 0 ? event.behavior : '检测到长者出现')
              .fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: 8 }) {
              if (event.expression.length > 0) {
                Text(`表情 ${event.expression}`).fontSize(11)
                  .fontColor(this.expressionBadgeColor(event))
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(8)
                  .backgroundColor($r('sys.color.comp_background_secondary'))
              }
              Text(`相似度 ${(event.similarity * 100).toFixed(0)}%`).fontSize(11)
                .fontColor($r('sys.color.font_tertiary'))
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          if ((event.video_url ?? '').length > 0) {
            Button(this.playingEventId === event.id ? '收起' : '回放')
              .height(32).fontSize(13).borderRadius(16)
              .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
              .onClick(() => this.togglePlay(event))
          }
        }.width('100%').alignItems(VerticalAlign.Center)

        if (this.playingEventId === event.id) {
          Video({ src: event.video_url ?? '' })
            .autoPlay(true).controls(true)
            .width('100%').height(240).borderRadius(12)
            .objectFit(ImageFit.Contain)
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 12 }) {
      if (this.loading) {
        Column({ space: 12 }) {
          LoadingProgress().width(38).height(38).color($r('app.color.brand_blue'))
          Text('正在加载行为记录…').fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.width('100%').padding({ top: 32, bottom: 32 })
      } else if (this.errorMsg.length > 0) {
        Column({ space: 10 }) {
          Text(this.errorMsg).fontSize(14).fontColor($r('sys.color.font_secondary'))
          Text('重试').fontSize(14).fontColor($r('app.color.brand_blue'))
            .onClick(() => this.load())
        }.width('100%').padding({ top: 24, bottom: 24 }).alignItems(HorizontalAlign.Center)
      } else if (this.events.length === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.play_circle_fill')).fontSize(32)
            .fontColor([$r('sys.color.icon_secondary')])
          Text('暂无行为记录').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('绑定走廊的摄像头识别到长者后，行为与监控片段会出现在这里。')
            .fontSize(12).fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center).width('100%')
        }.width('100%').padding({ top: 32, bottom: 32 }).alignItems(HorizontalAlign.Center)
      } else {
        this.dayChipsRow()
        Column() {
          ForEach(this.dayEvents(), (event: BehaviorEventItem, index: number) => {
            this.eventRow(event, index < this.dayEvents().length - 1)
          }, (event: BehaviorEventItem) => `be-${event.id}-${this.playingEventId}`)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
