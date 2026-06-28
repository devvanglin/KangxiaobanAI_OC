import { taskpool } from '@kit.ArkTS';
import { BusinessError } from '@ohos.base';
import { hilog } from '@kit.PerformanceAnalysisKit';

// DocsCode 1
@Concurrent
async function returnModule() {
  let module = await import('./a');
  return module;
}
// DocsCode 1

// DocsCode 2
@Concurrent
async function returnPromise() {
  let promise = new Promise<void>((resolve) => {
    setTimeout(() => {
      resolve();
    }, 1000);
  });
  return promise;
}
// DocsCode 2

@Entry
@Component
struct Sample4 {
  @State message: string = 'Hello World';

  build() {
    Row() {
      Column({ space: 12 }) {
        Blank()
        // DocsCode 3
        Button('TaskPool Thread return module')
          .height(40)
          .width('100%')
          .onClick(() => {
            taskpool.execute(returnModule).catch((e: BusinessError) => {
              hilog.error(0xFF00, 'sampleTag', 'error info: ' + e.message);
            })
          })
        // DocsCode 3

        // DocsCode 4
        Button('TaskPool Thread return promise')
          .height(40)
          .width('100%')
          .onClick(() => {
            taskpool.execute(returnPromise).catch((e: BusinessError) => {
              hilog.error(0xFF00, 'sampleTag', 'error info: ' + e.message);
            })
          })
        // DocsCode 4
      }
      .height('100%')
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}