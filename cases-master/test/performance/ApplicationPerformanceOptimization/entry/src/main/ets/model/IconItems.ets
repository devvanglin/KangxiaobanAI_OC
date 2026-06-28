@Component
export struct IconItem {
  renderGroupFlag: boolean = false;
  image: string | Resource = '';
  text: string | Resource = '';

  build() {
    Flex({
      direction: FlexDirection.Column,
      justifyContent: FlexAlign.Center,
      alignContent: FlexAlign.Center
    }) {
      Image(this.image)
        .height(20)
        .width(20)
        .objectFit(ImageFit.Contain)
        .margin({ left: 15 })
          // 系统组件Image应用透明度渐变动效
        .transition(
          TransitionEffect.OPACITY.animation({ duration: 3000, curve: Curve.EaseIn, iterations: -1 })
        )

      Text(this.text)
        .fontSize(10)
        .fontColor("#182431")
        .margin({ top: 5 })
        .width(50)
        .opacity(0.8)
        .textAlign(TextAlign.Center)
    }
    .backgroundColor('#e3e3e3')
    .width(50)
    .height(50)
    .borderRadius(25)
    //  在IconItem内调用renderGroup，true为开启，false为关闭
    .renderGroup(this.renderGroupFlag)
  }
}