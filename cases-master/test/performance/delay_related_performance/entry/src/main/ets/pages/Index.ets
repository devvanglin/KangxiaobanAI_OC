import router from '@ohos.router';

@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('PullToRefreshNews')
        .fontSize(32)
        .fontColor(Color.Blue)
        .margin({bottom: 30})
        .onClick(() => {
          router.pushUrl({ url: 'pages/PullToRefreshNews' })
        })
      Text('FriendMoment')
        .fontSize(32)
        .fontColor(Color.Blue)
        .margin({bottom: 30})
        .onClick(() => {
          router.pushUrl({ url: 'pages/FriendMoment' })
        })
      Text('BottomDrawerSlideCase')
        .fontSize(32)
        .fontColor(Color.Blue)
        .margin({bottom: 30})
        .onClick(() => {
          router.pushUrl({ url: 'pages/BottomDrawerSlideCase' })
        })
    }
    .height('100%')
    .width('100%')
  }
}