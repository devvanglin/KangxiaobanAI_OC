import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  // 创建scheme对象，isCodeCacheSupported为false时不支持自定义协议的JavaScript生成字节码缓存
  scheme: webview.WebCustomScheme = { schemeName: 'scheme', isSupportCORS: true, isSupportFetch: true, isCodeCacheSupported: false };
  // 请求数据
  @State jsData: string = 'xxx';

  aboutToAppear(): void {
    try {
      webview.WebviewController.customizeSchemes([this.scheme]);
    } catch (error) {
      const e: BusinessError = error as BusinessError;
      console.error(`ErrorCode: ${e.code}, Message: ${e.message}`);
    }
  }
  build() {
    Column({ space: 10 }) {
      Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center }) {
        Web({
          // 需将'https://www.example.com/'替换为真是的包含自定义协议的JavaScript的Web页面地址
          src: 'https://www.example.com/',
          controller: this.controller
        })
          .fileAccess(true)
          .javaScriptAccess(true)
          .onInterceptRequest(event => {
            const responseResource: WebResourceResponse = new WebResourceResponse();
            // 拦截页面请求
            if (event?.request.getRequestUrl() === 'scheme1://www.example.com/test.js') {
              responseResource.setResponseHeader([
                {
                  headerKey: 'ResponseDataID',
                  // 格式：不超过13位的纯数字。JS识别码，JS有更新时必须更新该字段
                  headerValue: '0000000000001'
                }
              ]);
              responseResource.setResponseData(this.jsData);
              responseResource.setResponseEncoding('utf-8');
              responseResource.setResponseMimeType('application/javascript');
              responseResource.setResponseCode(200);
              responseResource.setReasonMessage('OK');
              return responseResource;
            }
            return null;
          })
      }
    }
  }
}