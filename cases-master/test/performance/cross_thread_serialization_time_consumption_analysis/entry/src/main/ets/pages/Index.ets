import { NotUseSendable } from './NotUseSendable';
import { UseSendable } from './UseSendable';

@Entry
@Component
struct Index {
  @Provide('NavPathStack') pathStack: NavPathStack = new NavPathStack();

  @Builder
  pagesMap(name: string) {
    if (name === 'NotUseSendable') {
      NotUseSendable()
    } else {
      UseSendable()
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column({ space: 8 }) {
        Button('未使用Sendable方式')
          .onClick(() => {
            this.pathStack.pushPathByName('NotUseSendable', '');
          })
        Button('使用Sendable方式优化后')
          .onClick(() => {
            this.pathStack.pushPathByName('UseSendable', '');
          })
      }
    }
    .height('100%')
    .width('100%')
    .navDestination(this.pagesMap)
  }
}