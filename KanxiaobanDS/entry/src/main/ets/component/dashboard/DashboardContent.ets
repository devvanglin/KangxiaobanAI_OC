import { CockpitOverview } from './CockpitOverview';
import DashboardStore from '../../network/DashboardStore';

@ComponentV2
export struct DashboardContent {
  @Local layoutWidth: number = 0;
  @Local layoutHeight: number = 0;
  @Local store: DashboardStore = DashboardStore.getShared();

  private lengthValue(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return parseFloat(value);
    }
    return 0;
  }

  private updateLayoutSize(width: Length, height: Length): void {
    const nextWidth: number = this.lengthValue(width);
    const nextHeight: number = this.lengthValue(height);
    if (nextWidth > 0 && Math.abs(nextWidth - this.layoutWidth) > 0.5) {
      this.layoutWidth = nextWidth;
    }
    if (nextHeight > 0 && Math.abs(nextHeight - this.layoutHeight) > 0.5) {
      this.layoutHeight = nextHeight;
    }
  }

  private isCompact(): boolean {
    return this.layoutWidth > 0 && this.layoutWidth < 720;
  }

  private pagePadding(): number {
    if (this.layoutWidth >= 1180) {
      return 24;
    }
    if (this.layoutWidth >= 720) {
      return 20;
    }
    return 12;
  }

  build() {
    Stack() {
      if (this.store.authenticated) {
        CockpitOverview({
          compact: this.isCompact(),
          layoutWidth: this.layoutWidth,
          layoutHeight: this.layoutHeight,
          store: this.store
        })
        .width('100%')
        .height('100%')
        .padding(this.pagePadding())
      } else {
        DashboardLogin({ store: this.store, compact: this.isCompact() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateLayoutSize(newValue.width, newValue.height);
    })
  }
}

@ComponentV2
struct DashboardLogin {
  @Param @Require store: DashboardStore;
  @Param compact: boolean = false;
  @Local username: string = '';
  @Local password: string = '';
  @Local tenantCode: string = '';
  @Local passwordVisible: boolean = false;

  private submit(): void {
    if (this.username.trim().length === 0 || this.password.length === 0 || this.store.loading) {
      return;
    }
    this.store.login(this.username, this.password, this.tenantCode);
  }

  @Builder
  private field(symbol: Resource, placeholder: string, value: string, password: boolean,
    onChange: (value: string) => void) {
    Row({ space: 12 }) {
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor([$r('sys.color.icon_secondary')])
      TextInput({ placeholder: placeholder, text: value })
        .type(password && !this.passwordVisible ? InputType.Password : InputType.Normal)
        .showPasswordIcon(false)
        .layoutWeight(1)
        .height(52)
        .fontSize($r('sys.float.Body_L'))
        .backgroundColor(Color.Transparent)
        .onChange(onChange)
      if (password) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.passwordVisible ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'))
            .fontSize(17)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(34)
        .height(34)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.passwordVisible ? '隐藏密码' : '显示密码')
        .onClick(() => this.passwordVisible = !this.passwordVisible)
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 10 })
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_secondary'))
  }

  build() {
    Column({ space: 24 }) {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.building_fill'))
              .fontSize(28)
              .fontColor([$r('app.color.brand_primary')])
          }
          .width(50)
          .height(50)
          .borderRadius(8)
          .backgroundColor($r('app.color.brand_soft'))
          Column({ space: 3 }) {
            Text('康小伴运营驾驶舱')
              .fontSize(this.compact ? 22 : 26)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text('使用机构员工账号登录')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        this.field($r('sys.symbol.person_fill'), '账号', this.username, false,
          (value: string) => this.username = value)
        this.field($r('sys.symbol.lock_fill'), '密码', this.password, true,
          (value: string) => this.password = value)
        this.field($r('sys.symbol.building_fill'), '机构代码（默认机构可不填）', this.tenantCode, false,
          (value: string) => this.tenantCode = value)

        if (this.store.error.length > 0) {
          Text(this.store.error)
            .width('100%')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.status_danger'))
        }

        Button() {
          if (this.store.loading) {
            LoadingProgress()
              .width(22)
              .height(22)
              .color(Color.White)
          } else {
            Text('登录驾驶舱')
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(52)
        .borderRadius(8)
        .backgroundColor($r('app.color.brand_primary'))
        .enabled(!this.store.loading && this.username.trim().length > 0 && this.password.length > 0)
        .opacity(!this.store.loading && this.username.trim().length > 0 && this.password.length > 0 ? 1 : 0.45)
        .onClick(() => this.submit())
      }
      .width('100%')
    }
    .width(this.compact ? 'calc(100% - 32vp)' : 420)
    .padding(this.compact ? 22 : 30)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: $r('app.color.cockpit_border') })
  }
}
