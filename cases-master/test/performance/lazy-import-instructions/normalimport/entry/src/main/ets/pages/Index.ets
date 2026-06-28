import { A } from "../component/A";

@Entry
@Component
struct Index {

  build() {
    RelativeContainer() {
      Button('点击执行A')
        .onClick(() => {
          console.log("执行A文件", A);
        })
    }
    .height('100%')
    .width('100%')
  }
}