import { AppRouter } from 'routermodule';
import { BarChartPage } from './view/BarChart';

@AppRouter({ name: "barchart/BarChartPageComponent" })
@Component
export struct BarChartPageComponent {
  build() {
    BarChartPage()
  }
}