import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { ifaa } from '@kit.OnlineAuthenticationKit';

/**
 * “IFAA免密认证获取匿名化ID” - 反例：使用异步接口getAnonymousId
 */

// 开发者需要按照IIFAA的TLV格式构造入参，并转换为Uint8Array参数；此处arg需要开发者替换为真实入参。
let arg = new Uint8Array([0]);

@Entry
@Component
export struct GetAnonymousId {
  @State message: string = 'getAnonymousId';

  build() {
    RelativeContainer() {
      Text(this.message)
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
        .onClick(()=>{
          hiTraceMeter.startTrace('getAnonymousId', 1);
          ifaa.getAnonymousId(arg).then((getAnonIdResult: Uint8Array)=>{
          })
          hiTraceMeter.finishTrace('getAnonymousId', 1);
        })
    }
    .height('100%')
    .width('100%')
  }
}