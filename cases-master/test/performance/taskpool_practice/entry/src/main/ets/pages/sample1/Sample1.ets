import { BusinessError } from '@ohos.base';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
// DocsCode 3
import { Foo } from './correct/b';
// DocsCode 3
// DocsCode 1
import { Bar } from './wrong/a';
@Concurrent
function wrongConcurrentFunc() {
  try {
    let bar: Bar = new Bar;
  } catch (e) {
    let error: BusinessError = e;
    hilog.error(0xFF00, 'sampleTag', 'error occur: ' + error.message);
  }
}
// DocsCode 1

// DocsCode 4
@Concurrent
function correctConcurrentFunc() {
  let foo: Foo = new Foo;
}
// DocsCode 4

@Entry
@Component
struct Sample1 {
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
            taskpool.execute(wrongConcurrentFunc);
          })
        // DocsCode 2

        // DocsCode 5
        Button('Correct Sample')
          .height(40)
          .width('100%')
          .onClick(() => {
            taskpool.execute(correctConcurrentFunc);
          })
        // DocsCode 5
      }
      .height('100%')
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}