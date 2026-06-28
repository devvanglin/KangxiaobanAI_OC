import { hilog } from '@kit.PerformanceAnalysisKit';
// DocsCode 1
@Observed
class Foo {
  constructor() {
    hilog.info(0xFF00, "sampleTag", "this is class Foo");
  }
}

export class Bar {
  constructor() {
    hilog.info(0xFF00, "sampleTag", "this is class Bar");
  }
}
// DocsCode 1