// Index.ets
@Entry
@Component
struct Index {
  pageInfos: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.pageInfos) {
      Column() {
        Button('加载下一页')
          .width('80%')
          .height(40)
          .onClick(() => {
            this.pageInfos.pushPath({ name: 'pageOne' });
          })
      }
      .width('100%')
    }
    .title('NavIndex')
  }
}