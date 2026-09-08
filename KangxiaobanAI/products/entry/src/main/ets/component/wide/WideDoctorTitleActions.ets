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
        { title: '角色', symbol: $r('sys.symbol.key_shield_badge_person_crop_circle_fill'), index: 1 },
        { title: '用户', symbol: $r('sys.symbol.person_crop_circle_fill'), index: 2 },
        { title: '区域', symbol: $r('sys.symbol.map'), index: 3 },
        { title: '订阅', symbol: $r('sys.symbol.calendar_badge_clock'), index: 4 },
        { title: '大模型', symbol: $r('sys.symbol.AI_model'), index: 5 },
        { title: '设备', symbol: $r('sys.symbol.beacon_tower_fill'), index: 6 },
        { title: '药物', symbol: $r('sys.symbol.cross_case'), index: 7 }
      ];
    }
    return [
      { title: '工作台', symbol: $r('sys.symbol.square_grid_2x2'), index: 0 },
      { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
      { title: '康小伴 AI', symbol: $r('sys.symbol.AI_model'), index: 2 }
    ];
  }

  build() {
    Row({ space: 8 }) {
      Blank()
        .layoutWeight(1)
      WideSlidingCapsule({
        items: this.navigationItems(),
        selectedIndex: this.selectedIndex,
        itemWidth: this.compactWidth ? (this.isDoctor ? 46 : 64) : (this.isDoctor ? 124 : 100),
        iconOnly: this.isDoctor && this.compactWidth,
        slideMemoryKey: this.isDoctor ? 'doctor-title-nav' : 'admin-title-nav',
        onSelect: (index: number) => this.onSelect(index)
      })
    }
    .width('100%')
    .height('100%')
    // 头像由 MainPage 的稳定节点承载，这里预留其宽度避免胶囊与其重叠。
    .padding({ right: (this.compactWidth ? 18 : 28) + 50 })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }
}
