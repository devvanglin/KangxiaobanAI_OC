import { LengthMetrics } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';
import { DashboardContent } from '../component/dashboard/DashboardContent';

@Entry
@ComponentV2
struct Index {
  @Provider('dashboardPathStack') pathStack: NavPathStack = new NavPathStack();
  private pageScroller: Scroller = new Scroller();

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      padding: {
        start: LengthMetrics.vp(16),
        end: LengthMetrics.vp(16)
      },
      content: {
        title: {
          mainTitle: '全院信息中心'
        },
        menu: { value: [] }
      }
    };
  }

  build() {
    HdsNavigation(this.pathStack) {
      DashboardContent({
        pageScroller: this.pageScroller
      })
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .bindToScrollable([this.pageScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
