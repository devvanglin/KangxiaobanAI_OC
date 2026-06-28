import { AppRouter } from 'routermodule';
import { RefreshTimeLine } from './view/RefreshTimeLine';

@AppRouter({ name: "refreshtimeline/RefreshTimeLineComponent" })
@Component
export struct RefreshTimeLineComponent {
  build() {
    RefreshTimeLine()
  }
}