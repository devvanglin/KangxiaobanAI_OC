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
        { title: '总览', symbol: $r('sys.symbol.square_grid_2x2'), index: 0 },
        { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
        { title: '排班', symbol: $r('sys.symbol.person_crop_circle_fill'), index: 2 },
        { title: '质量', symbol: $r('sys.symbol.checkmark_shield_fill'), index: 3 },
        { title: '风险', symbol: $r('sys.symbol.exclamationmark_triangle_fill'), index: 4 },
        { title: '设备', symbol: $r('sys.symbol.archivebox_fill'), index: 5 },
        { title: '报表', symbol: $r('sys.symbol.waveform_path_ecg_square'), index: 6 }
      ];
    }
    return [
      { title: '工作台', symbol: $r('sys.symbol.square_grid_2x2'), index: 0 },
      { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
      { title: '协作', symbol: $r('sys.symbol.person_crop_circle_fill'), index: 2 },
      { title: '评估', symbol: $r('sys.symbol.checkmark_shield_fill'), index: 3 },
      { title: '风险', symbol: $r('sys.symbol.exclamationmark_triangle_fill'), index: 4 },
      { title: '监测', symbol: $r('sys.symbol.waveform_path_ecg_square'), index: 5 },
      { title: '记录', symbol: $r('sys.symbol.doc_text'), index: 6 }
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
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
        .fontSize(22)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .width(42)
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
        itemWidth: this.compactWidth ? 46 : 88,
        iconOnly: this.compactWidth,
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
