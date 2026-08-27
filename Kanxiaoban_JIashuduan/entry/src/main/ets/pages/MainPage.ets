import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { router } from '@kit.ArkUI';
import ApiClient from '../network/ApiClient';
import { ApiResp, Paged, Elder, Alert, Bill } from '../network/Dto';
import Logger from '../util/Logger';

const TAG: string = '[MainPage]';

@Entry
@ComponentV2
struct MainPage {
  @Local controller: HdsTabsController = new HdsTabsController();
  @Local tabIndex: number = 0;
  @Local elders: Elder[] = [];
  @Local alerts: Alert[] = [];
  @Local bills: Bill[] = [];
  @Local loading: boolean = false;

  aboutToAppear(): void {
    this.loadAll();
  }

  private async loadAll(): Promise<void> {
    this.loading = true;
    try {
      const [er, ar, br] = await Promise.all([
        ApiClient.get<ApiResp<Paged<Elder>>>('/elders?size=50'),
        ApiClient.get<ApiResp<Paged<Alert>>>('/alerts?size=50'),
        ApiClient.get<ApiResp<Paged<Bill>>>('/bills?size=50')
      ]);
      this.elders = er.data ? (er.data as Paged<Elder>).list ?? [] : [];
      this.alerts = ar.data ? (ar.data as Paged<Alert>).list ?? [] : [];
      this.bills = br.data ? (br.data as Paged<Bill>).list ?? [] : [];
    } catch (err) {
      Logger.error(TAG, `load err: ${JSON.stringify(err)}`);
    }
    this.loading = false;
  }

  private openDetail(id: number): void {
    router.pushUrl({ url: 'pages/ElderDetailPage', params: { elderId: id } });
  }

  @Builder
  private elderTab() {
    List() {
      ForEach(this.elders, (e: Elder) => {
        ListItem() {
          Row({ space: 12 }) {
            Text(e.name)
              .width(46)
              .height(46)
              .borderRadius(23)
              .fontSize(18)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand_blue'))

            Column({ space: 4 }) {
              Text(e.name).fontSize(17).fontWeight(FontWeight.Medium)
              Text(e.status === 2 ? '在院' : e.status === 1 ? '登记' : '退住')
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(e.gender === 'M' ? '男' : '女')
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
          .onClick(() => { this.openDetail(e.id); })
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding(12)
  }

  @Builder
  private statusTab() {
    List() {
      ForEach(this.alerts, (a: Alert) => {
        ListItem() {
          Row({ space: 10 }) {
            Text(a.level === 'emergency' ? '紧急' : a.level === 'important' ? '重要' : '提示')
              .fontSize(12)
              .fontColor(a.level === 'emergency' ? Color.fromRgb(255, 93, 108) : a.level === 'important' ? Color.fromRgb(255, 181, 71) : $r('sys.color.font_tertiary'))
            Text(a.content).fontSize(14).layoutWeight(1)
            Text(a.status).fontSize(11).fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding(12)
  }

  @Builder
  private billTab() {
    List() {
      ForEach(this.bills, (b: Bill) => {
        ListItem() {
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text(b.bill_month).fontSize(16).fontWeight(FontWeight.Medium)
              Text(`长者#${b.elder_id} · ${b.status}`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text(`¥${b.amount}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.brand_blue'))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding(12)
  }

  @Builder
  private mineTab() {
    Column({ space: 12 }) {
      Text('家属端 · 关于').fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 24 })
      Text('康小伴智慧养老家属端').fontSize(13).fontColor($r('sys.color.font_tertiary'))
      Blank()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text('康小伴 · 家属端').fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Text(this.loading ? '加载中…' : '刷新')
          .fontSize(14)
          .fontColor($r('app.color.brand_blue'))
          .onClick(() => { this.loadAll(); })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      HdsTabs({ controller: this.controller, index: this.tabIndex }) {
        this.elderTab()
        this.statusTab()
        this.billTab()
        this.mineTab()
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}