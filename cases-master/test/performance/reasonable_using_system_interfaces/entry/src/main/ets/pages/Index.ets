import router from '@ohos.router';

@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('getStringSync(id)')
        .fontSize(32)
        .fontColor(Color.Blue)
        .margin({bottom: 30})
        .onClick(() => {
          router.pushUrl({ url: 'pages/GetStringSyncAfter' })
        })
      Text('getStringSync(Resource)')
        .fontSize(32)
        .fontColor(Color.Blue)
        .margin({bottom: 30})
        .onClick(() => {
          router.pushUrl({ url: 'pages/GetStringSync' })
        })
      Text('Using Word Break')
        .fontSize(32)
        .fontColor(Color.Blue)
        .margin({bottom: 30})
        .onClick(() => {
          router.pushUrl({ url: 'pages/UsingWordBreak' })
        })
      Text('Using Zero Width Space')
        .fontSize(32)
        .fontColor(Color.Blue)
        .onClick(() => {
          router.pushUrl({ url: 'pages/UsingZeroWidthSpace' })
        })
      Text('GetAnonymousIdSync')
        .fontSize(32)
        .fontColor(Color.Blue)
        .onClick(() => {
          router.pushUrl({ url: 'pages/GetAnonymousIdSync' })
        })
      Text('GetAnonymousId')
        .fontSize(32)
        .fontColor(Color.Blue)
        .onClick(() => {
          router.pushUrl({ url: 'pages/GetAnonymousId' })
        })
      Text('RuntimeInterface')
        .fontSize(32)
        .fontColor(Color.Blue)
        .onClick(() => {
          router.pushUrl({ url: 'pages/RuntimeInterface' })
        })
      Text('LocalizationKitInterface')
        .fontSize(32)
        .fontColor(Color.Blue)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LocalizationKitInterface' })
        })
    }
    .height('100%')
    .width('100%')
  }
}