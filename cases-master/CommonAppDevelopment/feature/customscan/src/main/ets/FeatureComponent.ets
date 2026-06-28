import { AppRouter } from 'routermodule';
import { CustomScanPage } from './pages/CustomScanPage';

@AppRouter({ name: "customscan/CustomScanPageComponent" })
@Component
export struct CustomScanPageComponent {
  build() {
    CustomScanPage()
  }
}