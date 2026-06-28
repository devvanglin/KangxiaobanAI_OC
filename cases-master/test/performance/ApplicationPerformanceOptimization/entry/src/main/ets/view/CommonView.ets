import { promptAction } from '@kit.ArkUI'

/**
 * 弹窗函数
 */
export function showToast() {
  promptAction.showToast({
    message: $r('app.string.container_nested_only_show_for_ux')
  })
}

@Builder
export function navDestinationTitleImg(res: Resource, fun: () => void) {
  Image(res)
    .padding(8)
    .width(40)
    .height(40)
    .borderRadius('50%')
    .colorFilter('#171717')
    .backgroundColor('#e6e8e9')
    .onClick(() => {
      fun();
    })
}

@Builder
export function navDestinationTitle(title:string, fun: () => void) {
  Row() {
    navDestinationTitleImg($r('app.media.back'), () => {
      fun();
    })

    Text(title)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .textAlign(TextAlign.Start)
      .lineHeight(26)
      .padding({ left: 8 })
      .fontColor(Color.Black)
      .layoutWeight(1)

    navDestinationTitleImg($r('app.media.more'), () => {
      showToast();
    })
  }
  .width('100%')
  .height(56)
  .margin({ top: 36 })
  .padding({
    left: 16,
    right: 16
  })
  .backgroundColor('#F1F3F5')
}