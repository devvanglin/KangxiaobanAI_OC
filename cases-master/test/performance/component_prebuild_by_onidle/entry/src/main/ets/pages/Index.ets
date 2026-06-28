import { router } from '@kit.ArkUI';
import { IdleCallback } from '@ohos/customreusablepool/src/main/ets/pages/BuilderNodePoolDemo';
import { furnitureData, natureData } from '@ohos/customreusablepool/src/main/ets/data/MockData';
import { ViewItem } from '@ohos/customreusablepool/src/main/ets/data/ViewItem';

@Entry
@Component
struct Index {
  @State timer: number = 2;

  aboutToAppear(): void {
    let intervalId = setInterval(() => {
      if (this.timer === 1) {
        router.pushUrl({ url: 'pages/OnIdlePage' });
        router.clear();
        clearInterval(intervalId)
      } else {
        this.timer--;
      }
    }, 1000)
    let viewItems: ViewItem[] = [];
    viewItems.push(...furnitureData());
    viewItems.push(...natureData());
    let context = this.getUIContext();
    context.postFrameCallback(new IdleCallback(context, viewItems));
  }

  build() {
    RelativeContainer() {
      Image($r('app.media.startIcon'))
        .height(100)
        .width(100)
        .id('image')
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
          bottom: { anchor: "__container__", align: VerticalAlign.Bottom }
        })
      Text(this.timer + "s")
        .id('text')
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontColor(Color.White)
        .padding(5)
        .alignRules({
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top }
        })
        .margin({
          right: 20
        })
        .width(50)
        .backgroundColor('#B3CFFF')
        .borderRadius(10)
    }
    .width('100%')
    .height('100%')
  }
}