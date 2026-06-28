import { taskpool } from '@kit.ArkTS';
import { emitter } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// DocsCode 1
@Concurrent
function wrongConcurrentFunc() {
  let promise = Promise.resolve();
  promise.then(() => {
    taskpool.Task.sendData();
  })
}
// DocsCode 1
// DocsCode 2
@Concurrent
function correctConcurrentFunc() {
  let promise = Promise.resolve();
  promise.then(() => {
    emitter.emit("1", {data: {name: "anonymous"}});
  })
}
// DocsCode 2

@Entry
@Component
struct Sample3 {
  @State message: string = 'Hello World';

  build() {
    Row() {
      Column({ space: 12 }) {
        Blank()
        // DocsCode 3
        Button('Wrong Sample')
          .height(40)
          .width('100%')
          .onClick(() => {
            let task: taskpool.Task = new taskpool.Task(wrongConcurrentFunc);
            task.onReceiveData(() => {
              hilog.info(0xFF00, 'sampleTag', 'onReceiveData has been called');
            })
            taskpool.execute(task);
          })
        // DocsCode 3

        // DocsCode 4
        Button('Correct Sample')
          .height(40)
          .width('100%')
          .onClick(() => {
            let task: taskpool.LongTask = new taskpool.LongTask(correctConcurrentFunc);
            emitter.on("1", (data: emitter.EventData) => {
              hilog.info(0xff00, 'sampleTag', 'name is : ' + data.data?.name);
              emitter.off("1");
              taskpool.terminateTask(task);
            })
            taskpool.execute(task);
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