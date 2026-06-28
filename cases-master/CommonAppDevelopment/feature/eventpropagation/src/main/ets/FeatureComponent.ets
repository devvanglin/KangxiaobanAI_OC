import { AppRouter } from 'routermodule';
import { EventPropagation } from './view/EventPropagation';

@AppRouter({ name: "eventpropagation/EventPropagationComponent" })
@Component
export struct EventPropagationComponent {
  build() {
    EventPropagation()
  }
}