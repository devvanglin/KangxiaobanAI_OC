import {webview} from '@kit.ArkWeb';

@Preview
@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  url = $rawfile('img_list.html');

  aboutToAppear(): void {
    // 配置Web开启调试模式
    webview.WebviewController.setWebDebuggingAccess(true);
  }

  build() {
    Column(){
      Web({src:this.url,controller:this.controller})
        .width('100%')
        .height('100%')
    }
    .height('100%')
    .width('100%')
  }
}