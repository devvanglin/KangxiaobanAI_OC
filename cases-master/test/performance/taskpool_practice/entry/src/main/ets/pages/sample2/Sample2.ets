import { http } from '@kit.NetworkKit';
import { taskpool } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

// DocsCode 1
@Concurrent
function concurrentFunc() {
  let httpRequest = http.createHttp();
  httpRequest.on('headersReceive', (header: Object) => {
    hilog.info(0xFF00, 'sampleTag', 'header: ' + JSON.stringify(header));
  });

  httpRequest.on('dataEnd', () => {
    hilog.info(0xFF00, 'sampleTag', 'No more data in response, data receive end');
  });
}
// DocsCode 1

@Entry
@Component
struct Sample2 {
  @State message: string = 'Hello World';

  build() {
    Row() {
      Column({ space: 12 }) {
        Blank()
        // DocsCode 2
        Button('Wrong Sample')
          .height(40)
          .width('100%')
          .onClick(() => {
            taskpool.execute(concurrentFunc);
          })
        // DocsCode 2

        // DocsCode 3
        Button('Correct Sample')
          .height(40)
          .width('100%')
          .onClick(() => {
            let task: taskpool.LongTask = new taskpool.LongTask(concurrentFunc);
            taskpool.execute(task).then(() => {
              hilog.info(0xFF00, 'sampleTag', 'receive http msg success.');
              taskpool.terminateTask(task);
            })
          })
        // DocsCode 3
      }
      .height('100%')
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}