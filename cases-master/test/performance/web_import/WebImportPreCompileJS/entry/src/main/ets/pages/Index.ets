import { webview } from '@kit.ArkWeb';
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit';

interface Config {
  url: string,
  localPath: string, // 本地资源路径
  options: webview.CacheOptions
}

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  // 配置预编译的JavaScript文件信息
  configs: Array<Config> = [
    {
      url: 'https://www.example.come/a.js',
      localPath: 'a.js',
      options: {
        responseHeaders: [
          { headerKey: 'E-Tag', headerValue: 'aWO42N9P9dG/5xqYQCxsx+vDOoU=' },
          { headerKey: 'Last-Modified', headerValue: 'Web, 21 Mar 2024 10:38:41 GMT' }
        ]
      }
    }
  ]

  build() {
    Column() {
      // 在适当的时机加载业务用Web组件，本例以Button点击触发为例
      Button('加载页面')
        .onClick(() => {
          // 性能打点
          hiTraceMeter.startTrace('unPrecompileJavaScript', 2);
          // url请替换为真实地址
          this.controller.loadUrl('https://www.example.com/example2.html');
        })
      Web({ src: 'https://www.example.com/example1.html', controller: this.controller })
        .onControllerAttached(async () => {
          // 读取配置，进行预编译
          for (const config of this.configs) {
            try {
              let content = await getContext().resourceManager.getRawFileContentSync(config.localPath);
              this.controller.precompileJavaScript(config.url, content, config.options)
                .then((errCode: number) => {
                  console.error('precompile successfully!' + errCode);
                }).catch((errCode: number) => {
                console.error('precompile failed1.' + errCode);
              })
            } catch (err) {
              console.error('precompile failed2!.' + err.code + err.message);
            }
          }
        })
        .fileAccess(true)
        .onPageBegin((event) => {
          console.log(`load page begin: ${event?.url}`);
          console.log('load page begin::' + Date.now());
        })
        .onPageEnd((event) => {
          // 性能打点
          hiTraceMeter.finishTrace('unPrecompileJavaScript', 2);
          console.log(`load page end: ${event?.url}`);
          console.log('load page end::' + Date.now());
        })
    }
  }
}