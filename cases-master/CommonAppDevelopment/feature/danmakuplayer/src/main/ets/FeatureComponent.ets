import { AppRouter } from 'routermodule';
import { DanmakuVideoDemo } from './view/VideoView';

@AppRouter({ name: 'danmakuplayer/DanmakuVideoDemoComponent' })
@Component
export struct DanmakuVideoDemoComponent {
  build() {
    DanmakuVideoDemo()
  }
}