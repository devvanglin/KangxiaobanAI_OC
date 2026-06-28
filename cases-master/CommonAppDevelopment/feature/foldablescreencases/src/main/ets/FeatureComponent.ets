import { AppRouter } from 'routermodule';
import { MusicPlayerPage } from './pages/MusicPlayerPage';

@AppRouter({ name: "foldablescreencases/MusicPlayerPageComponent" })
@Preview
@Component
export struct MusicPlayerPageComponent {
  build() {
    MusicPlayerPage()
  }
}