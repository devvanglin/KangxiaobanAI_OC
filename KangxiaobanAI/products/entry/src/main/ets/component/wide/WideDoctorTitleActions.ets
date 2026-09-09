import { WideSlidingCapsule, WideSlidingCapsuleItem } from './WideSlidingCapsule';

@ComponentV2
export struct WideDoctorTitleActions {
  @Param @Require selectedIndex: number;
  @Param compactWidth: boolean = false;
  @Param isDoctor: boolean = true;
  @Param aiHistoryCollapsed: boolean = false;
  @Event onSelect: (index: number) => void = (_index: number) => {};
  @Event onOpenAiHistory: () => void = () => {};
  @Event onSearchAiHistory: () => void = () => {};
  @Event onNewAiConversation: () => void = () => {};
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
        { title: '药物', symbol: $r('sys.symbol.cross_case'), index: 7 },
        { title: '存储', symbol: $r('sys.symbol.archivebox_fill'), index: 8 }
      ];
    }
    return [
      { title: '工作台', symbol: $r('sys.symbol.square_grid_2x2'), index: 0 },
      { title: '长者', symbol: $r('sys.symbol.person_2_fill'), index: 1 },
      { title: '康小伴 AI', symbol: $r('sys.symbol.AI_model'), index: 2 }
    ];
  }

  @Builder
  private aiHistoryActionButton(symbol: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(19)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(36)
    .height(36)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .focusable(true)
    .focusOnTouch(true)
    .onClick(action)
  }

  /** 医师 AI 会话栏收起后保留的恢复、搜索和新建入口。 */
  @Builder
  private aiHistoryActions() {
    Row({ space: 2 }) {
      this.aiHistoryActionButton($r('sys.symbol.open_sidebar'), '展开对话记录', () => {
        this.onOpenAiHistory();
      })
      this.aiHistoryActionButton($r('sys.symbol.magnifyingglass'), '搜索对话记录', () => {
        this.onSearchAiHistory();
      })
      this.aiHistoryActionButton($r('sys.symbol.message_badge_plus_fill'), '新建对话', () => {
        this.onNewAiConversation();
      })
    }
    .height(44)
    .padding({ left: 5, right: 5 })
    .borderRadius(22)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.08)', offsetY: 2 })
    .opacity(this.aiHistoryCollapsed ? 1 : 0)
    .scale({
      x: this.aiHistoryCollapsed ? 1 : 0.82,
      y: this.aiHistoryCollapsed ? 1 : 0.82,
      centerX: '0%',
      centerY: '50%'
    })
    .translate({ x: this.aiHistoryCollapsed ? 0 : -16 })
    .animation({ duration: 240, curve: Curve.Friction })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 8 }) {
        Blank()
          .layoutWeight(1)
          .hitTestBehavior(HitTestMode.None)
        WideSlidingCapsule({
          items: this.navigationItems(),
          selectedIndex: this.selectedIndex,
          itemWidth: this.compactWidth ? (this.isDoctor ? 46 : 64) : (this.isDoctor ? 124 : 100),
          iconOnly: this.isDoctor && this.compactWidth,
          onSelect: (index: number) => this.onSelect(index)
        })
      }
      .width('100%')
      .height('100%')
      // 头像由 MainPage 的稳定节点承载，这里预留其宽度避免胶囊与其重叠。
      .padding({ right: (this.compactWidth ? 18 : 28) + 50 })
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.None)

      if (this.isDoctor && this.selectedIndex === 2) {
        Row() {
          this.aiHistoryActions()
        }
        .width('100%')
        .height('100%')
        .padding({ left: this.compactWidth ? 136 : 144 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .zIndex(3)
        .hitTestBehavior(this.aiHistoryCollapsed ? HitTestMode.Transparent : HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.None)
  }
}
