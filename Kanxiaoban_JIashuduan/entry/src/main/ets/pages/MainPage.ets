import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { router } from '@kit.ArkUI';
import { ApiClient } from '../network/ApiClient';
import { ApiResp, Paged, Elder, Alert, Bill } from '../network/Dto';
import Logger from '../util/Logger';

const TAG: string = '[MainPage]';

@Entry
@ComponentV2
struct MainPage {
  @Local controller: HdsTabsController = new HdsTabsController();
  @Local selectedTabIndex: number = 0;
  @Local elders: Elder[] = [];
  @Local alerts: Alert[] = [];
  @Local bills: Bill[] = [];
  @Local loading: boolean = false;
  @Local loaded: boolean = false;
  @Local error: string = '';

  private elderName(elderId: number): string {
    const elder: Elder | undefined = this.elders.find((item: Elder): boolean => item.id === elderId);
    return elder?.name ?? `长者 #${elderId}`;
  }

  aboutToAppear(): void {
    this.loadAll();
  }

  private async loadAll(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const er: ApiResp<Paged<Elder>> = await ApiClient.getAll<Elder>('/elders');
      const ar: ApiResp<Paged<Alert>> = await ApiClient.getAll<Alert>('/alerts');
      const br: ApiResp<Paged<Bill>> = await ApiClient.getAll<Bill>('/bills');
      if (er.code !== 0 || ar.code !== 0 || br.code !== 0) {
        this.error = er.msg || ar.msg || br.msg || '数据加载失败';
      } else {
        this.elders = er.data?.list ?? [];
        this.alerts = ar.data?.list ?? [];
        this.bills = br.data?.list ?? [];
        this.loaded = true;
      }
    } catch (_error) {
      Logger.error(TAG, 'load failed');
      this.error = '无法连接服务器，请稍后重试';
    }
    this.loading = false;
  }

  @Builder
  private listState(emptyText: string) {
    ListItem() {
      Column({ space: 10 }) {
        if (this.loading) {
          LoadingProgress().width(30).height(30)
          Text('正在加载服务器数据')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
        } else {
          Text(this.error.length > 0 ? this.error : emptyText)
            .fontSize(14)
            .fontColor(this.error.length > 0 ? '#FF5D6C' :
              $r('sys.color.font_secondary'))
          if (this.error.length > 0) {
            Button('重试')
              .height(36)
              .borderRadius(18)
              .onClick(() => this.loadAll())
          }
        }
      }
      .width('100%')
      .padding({ top: 56, bottom: 56 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  private openDetail(id: number): void {
    router.pushUrl({ url: 'pages/ElderDetailPage', params: { elderId: id } });
  }

  @Builder
  private elderTab() {
    List() {
      if (this.elders.length === 0) {
        this.listState('暂无已绑定长者')
      } else {
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
    }
    .width('100%')
    .height('100%')
    .padding(12)
  }

  @Builder
  private statusTab() {
    List() {
      if (this.alerts.length === 0) {
        this.listState('暂无告警记录')
      } else {
        ForEach(this.alerts, (a: Alert) => {
        ListItem() {
          Row({ space: 10 }) {
            Text(a.level === 'emergency' ? '紧急' : a.level === 'important' ? '重要' : '提示')
              .fontSize(12)
              .fontColor(a.level === 'emergency' ? '#FF5D6C' :
                a.level === 'important' ? '#FFB547' : $r('sys.color.font_tertiary'))
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
    }
    .width('100%')
    .height('100%')
    .padding(12)
  }

  @Builder
  private billTab() {
    List() {
      if (this.bills.length === 0) {
        this.listState('暂无账单记录')
      } else {
        ForEach(this.bills, (b: Bill) => {
        ListItem() {
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text(b.bill_month).fontSize(16).fontWeight(FontWeight.Medium)
              Text(`${this.elderName(b.elder_id)} · ${b.status}`).fontSize(12).fontColor($r('sys.color.font_tertiary'))
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

      HdsTabs({ controller: this.controller, index: this.selectedTabIndex }) {
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
