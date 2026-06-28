import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

@Entry
@Component
struct UsingZeroWidthSpace {
  @State message: string = 'Using Zero Width Space';

  aboutToAppear(): void {
    getContext().resourceManager.getRawFileContent('sanguo.txt', (error: BusinessError, value: Uint8Array) => {
      if (error != null) {
        console.error("error is " + error);
      } else {
        this.message = util.TextDecoder.create().decodeWithStream(value);
      }
    })
  }

  build() {
    Column() {
      Scroll() {
        Text(this.message.split("").join("\u200B"))
          .fontSize(12)
      }
    }
    .height('100%')
    .width('100%')
  }
}