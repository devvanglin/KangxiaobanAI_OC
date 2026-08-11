import { HdsNavigation } from '@kit.UIDesignKit';
import { DashboardContent } from '../component/dashboard/DashboardContent';
import { DashboardSection } from '../model/DashboardModels';

@Entry
@ComponentV2
struct Index {
  @Provider('dashboardPathStack') pathStack: NavPathStack = new NavPathStack();
  @Local currentSection: DashboardSection = 'overview';
  private pageScroller: Scroller = new Scroller();

  build() {
    HdsNavigation(this.pathStack) {
      DashboardContent({
        currentSection: this.currentSection,
        pageScroller: this.pageScroller,
        onSectionChange: (section: DashboardSection) => {
          this.currentSection = section;
          this.pageScroller.scrollEdge(Edge.Top);
        }
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true, true)
    .hideBackButton(true)
    .bindToScrollable([this.pageScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.cockpit_background'))
  }
}
