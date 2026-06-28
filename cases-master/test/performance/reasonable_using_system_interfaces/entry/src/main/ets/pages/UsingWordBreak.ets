import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

@Entry
@Component
struct UsingWordBreak {
  @State message: string = 'Using Word Break';

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
      Scroll(){
        Text(this.message)
          .fontSize(12)
          .wordBreak(WordBreak.BREAK_ALL)
      }
    }
    .height('100%')
    .width('100%')
  }
}