import { AppRouter } from 'routermodule';
import { CustomKeyboardToH5 } from './view/CustomKeyboardToH5';

@AppRouter({ name: "customkeyboardtoh5/CustomKeyboardToH5Component" })
@Component
export struct CustomKeyboardToH5Component{
  build() {
    CustomKeyboardToH5()
  }
}