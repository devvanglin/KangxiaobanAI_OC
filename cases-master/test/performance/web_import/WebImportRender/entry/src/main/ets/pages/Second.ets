// Second.ets
import { webview } from '@kit.ArkWeb';
import { getNWeb } from './common';

@Builder
export function PageTwoBuilder() {
  Second();
}

@Component
export struct Second {
  webviewController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    // 输出Web页面加载开始时间
    console.info('load page start time: ', Date.now());
  }

  build() {
    NavDestination() {
      Row() {
        Column() {
          // url请替换为真实地址
          NodeContainer(getNWeb('https://www.example.com'))
            .height('100')
            .width('100')
        }
        .width('100%')
      }
      .height('100%')
    }
  }
}