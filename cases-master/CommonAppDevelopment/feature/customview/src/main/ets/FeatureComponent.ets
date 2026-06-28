import { AppRouter } from 'routermodule';
import { CustomView } from './view/CustomView';

@AppRouter({ name: "customview/CustomViewComponent" })
@Component
export struct CustomViewComponent {
  build() {
    CustomView()
  }
}