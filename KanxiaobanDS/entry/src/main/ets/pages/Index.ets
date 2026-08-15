import { DashboardContent } from '../component/dashboard/DashboardContent';

@Entry
@ComponentV2
struct Index {
  build() {
    Stack() {
      DashboardContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
