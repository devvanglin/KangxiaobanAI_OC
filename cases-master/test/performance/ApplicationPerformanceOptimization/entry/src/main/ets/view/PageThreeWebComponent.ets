import { webview } from "@kit.ArkWeb";
import { Constants } from "../common/Constants";
import { showToast } from "./CommonView";

@Builder
export function pageThreeWebComponentBuilder() {
  PageThreeWebComponent()
}

@Component
export struct PageThreeWebComponent{
  webviewController: webview.WebviewController = new webview.WebviewController();
  build() {
    NavDestination(){
      Web({ src: Constants.SAMPLE_HTML, controller: this.webviewController })
        .javaScriptAccess(true)
        .verticalScrollBarAccess(true)
        .onClick(() => {
          showToast();
        })
    }
    .hideTitleBar(true)

  }
}