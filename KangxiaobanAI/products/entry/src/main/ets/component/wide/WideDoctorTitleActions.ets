import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

@ComponentV2
export struct WideDoctorTitleActions {
  @Param @Require selectedIndex: number;
  @Param compactWidth: boolean = false;
  @Param isDoctor: boolean = true;
  @Event onSelect: (index: number) => void = (_index: number) => {};
  @Event onOpenAbout: () => void = () => {};
  @Event onOpenGeneral: () => void = () => {};
  @Event onLogout: () => void = () => {};

  private navigationItems(): WideSlidingCapsuleItem[] {
    if (!this.isDoctor) {
      return [
        { title: '总览', index: 0 },
        { title: '角色', index: 1 },
        { title: '用户', index: 2 },
        { title: '区域', index: 3 },
        { title: '计划', index: 4 },
        { title: '大模型', index: 5 },
        { title: '设备', index: 6 }
      ];
    }
    return [
      { title: '工作台', symbol: $r('sys.symbol.square_grid_2x2'), index: 0 },
      { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
      { title: '康小伴 AI', symbol: $r('sys.symbol.AI_model'), index: 2 }
    ];
  }

  @Builder
  private accountMenu() {
    Menu() {
      MenuItem({ content: '通用设置' })
        .height(46)
        .onClick(() => this.onOpenGeneral())
      MenuItem({ content: '关于我们' })
        .height(46)
        .onClick(() => this.onOpenAbout())
      MenuItem({ content: '退出登录' })
        .height(46)
        .contentFontColor($r('app.color.doctor_workspace_danger'))
        .onClick(() => this.onLogout())
    }
    .width(220)
    .radius(16)
  }

  @Builder
  private accountEntry() {
    Button({ type: this.isDoctor ? ButtonType.Circle : ButtonType.Normal, stateEffect: true }) {
      if (this.isDoctor) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_primary')])
      } else {
        Text('账户').fontSize(13).fontColor($r('sys.color.font_primary'))
      }
    }
    .width(this.isDoctor ? 42 : 58)
    .height(42)
    .padding(0)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .accessibilityText(this.isDoctor ? '医师账户' : '管理端账户')
    .bindMenu(this.accountMenu, {
      placement: Placement.BottomRight,
      enableArrow: true,
      offset: { x: 0, y: 8 }
    })
  }

  build() {
    Row({ space: 8 }) {
      Blank()
        .layoutWeight(1)
      WideSlidingCapsule({
        items: this.navigationItems(),
        selectedIndex: this.selectedIndex,
        itemWidth: this.compactWidth ? (this.isDoctor ? 46 : 64) : (this.isDoctor ? 104 : 88),
        iconOnly: this.isDoctor && this.compactWidth,
        deferSelectionUntilAnimation: true,
        onSelect: (index: number) => this.onSelect(index)
      })
      this.accountEntry()
    }
    .width('100%')
    .height('100%')
    .padding({ right: this.compactWidth ? 18 : 28 })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }
}
