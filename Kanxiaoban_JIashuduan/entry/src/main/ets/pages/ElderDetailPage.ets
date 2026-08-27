import { router } from '@kit.ArkUI';
import ApiClient from '../network/ApiClient';
import { ApiResp, Elder, HealthRecord, Paged } from '../network/Dto';
import Logger from '../util/Logger';

const TAG: string = '[ElderDetailPage]';

@Entry
@ComponentV2
struct ElderDetailPage {
  @Local elderId: number = 0;
  @Local elder: Elder | null = null;
  @Local records: HealthRecord[] = [];
  @Local loading: boolean = true;

  aboutToAppear(): void {
    const params: Record<string, Object> = router.getParams() as Record<string, Object>;
    this.elderId = Number(params['elderId']);
    this.loadDetail();
  }

  private async loadDetail(): Promise<void> {
    this.loading = true;
    try {
      const [e, h] = await Promise.all([
        ApiClient.get<ApiResp<Elder>>(`/elders/${this.elderId}`),
        ApiClient.get<ApiResp<Paged<HealthRecord>>>(`/elders/${this.elderId}/health-records?size=20`)
      ]);
      this.elder = e.data ?? null;
      this.records = h.data ? (h.data as Paged<HealthRecord>).list ?? [] : [];
    } catch (err) {
      Logger.error(TAG, `detail err: ${JSON.stringify(err)}`);
    }
    this.loading = false;
  }

  private fmt(ts: string): string {
    if (!ts) {
      return '-';
    }
    const d = new Date(ts);
    const p = (n: number): string => String(n).padStart(2, '0');
    return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(14)
          .fontColor($r('app.color.brand_blue'))
          .onClick(() => { router.back(); })
        Blank()
        Text(this.elder ? this.elder.name : '长者详情').fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.elder) {
            Column({ space: 4 }) {
              Text(this.elder.name).fontSize(22).fontWeight(FontWeight.Bold)
              Text(`${this.elder.gender === 'M' ? '男' : '女'} · 照护等级 ${this.elder.care_level} · ${this.elder.status === 2 ? '在院' : '其他'}`)
                .fontSize(13)
                .fontColor($r('sys.color.font_tertiary'))
              if (this.elder.contact_phone && this.elder.contact_phone.length > 0) {
                Text(`联系 ${this.elder.contact_phone}`).fontSize(13).fontColor($r('sys.color.font_secondary'))
              }
            }
            .alignItems(HorizontalAlign.Center)
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .borderRadius(14)
          }

          Text('最近健康记录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')

          ForEach(this.records, (r: HealthRecord) => {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(`体温 ${r.temperature ?? '-'}℃`)
                  .fontSize(14)
                Text(this.fmt(r.record_time))
                  .fontSize(12)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Row({ space: 6 }) {
                Text(r.is_abnormal ? '异常' : '正常')
                  .fontSize(12)
                  .fontColor(r.is_abnormal ? Color.fromRgb(255, 93, 108) : $r('sys.color.font_secondary'))
                Text(`${r.source === 'iot' ? '雷达' : '手录'}`)
                  .fontSize(12)
                  .fontColor($r('sys.color.font_tertiary'))
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .borderRadius(12)
          })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      if (this.loading) {
        LoadingProgress().width(42).height(42)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}