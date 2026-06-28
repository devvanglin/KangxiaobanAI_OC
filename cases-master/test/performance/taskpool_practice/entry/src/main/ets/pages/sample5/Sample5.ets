import { ErrorEvent, taskpool } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
// DocsCode 1
@Observed
class Foo {
  id: number = 0;
  name: string = 'foo';
}
// DocsCode 1
// DocsCode 2
@Concurrent
function correctConcurrentFunc() {
  let count: number = 0;
  let id = setInterval(() => {
    count++;
    if (count === 10) {
      hilog.info(0xFF00, 'sampleTag', 'the value has reached the threshold');
      clearInterval(id);
    }
  }, 1000);
}
// DocsCode 2
// DocsCode 3
@Concurrent
function correctConcurrentFunc1(foo: Foo) {
  hilog.info(0xFF00, 'sampleTag', 'the id is:' + foo.id);
}
// DocsCode 3
// DocsCode 4
@Concurrent
function correctConcurrentFunc2() {
  let error: Error = new Error('TaskPoolThread error');
  throw error;
}
// DocsCode 4
@Entry
@Component
struct Sample4 {
  @State message: string = 'Hello World';
  build() {
    Row() {
      Column({ space: 12 }) {
        Blank()
        // DocsCode 5
        Button('CorrectSample timer')
          .height(40)
          .width('100%')
          .onClick(() => {
            let task: taskpool.Task = new taskpool.Task(correctConcurrentFunc);
            taskpool.execute(task);
          })
        // DocsCode 5
        // DocsCode 6
        Button('Correct Sample MainThread Catch')
          .height(40)
          .width('100%')
          .onClick(() => {
            try {
              let foo = new Foo();
              taskpool.execute(correctConcurrentFunc1, foo);
            } catch (e) {
              let error: ErrorEvent = e;
              hilog.error(0xFF00, 'sampleTag', 'error info: ' + error.message);
            }
          })
        // DocsCode 6
        // DocsCode 7
        Button('Correct Sample TaskPoolThread Catch')
          .height(40)
          .width('100%')
          .onClick(() => {
            taskpool.execute(correctConcurrentFunc2).catch((error: BusinessError) => {
              hilog.error(0xFF00, 'sampleTag', 'error info: ' + error.message);
            })
          })
        // DocsCode 7
      }
      .height('100%')
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}