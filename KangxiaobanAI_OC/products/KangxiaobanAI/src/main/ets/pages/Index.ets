/*
 * 首页 - 自适应悬浮导航
 */
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsBarStyle,
  hdsMaterial,
  HdsNavDestination,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { BreakpointModel } from '@kit.CommonUI';
import { getWindowInfoState } from '../../../../common/src/main/ets/model/BreakpointModel';

@Entry
@ComponentV2
struct Index {
  private tabsBar: BottomTabBarStyle[] = [
    new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.house_fill')).fontColor([$r('sys.color.icon_primary')]),
      selected: new SymbolGlyphModifier($r('sys.symbol.house_fill')).fontColor([$r('sys.color.icon_emphasize')])
    }, $r('app.string.tab_home')).labelStyle({ unselectedColor: $r('sys.color.icon_primary'), selectedColor: $r('sys.color.icon_emphasize') }),
    new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.compass')).fontColor([$r('sys.color.icon_primary')]),
      selected: new SymbolGlyphModifier($r('sys.symbol.compass')).fontColor([$r('sys.color.icon_emphasize')])
    }, $r('app.string.tab_discover')).labelStyle({ unselectedColor: $r('sys.color.icon_primary'), selectedColor: $r('sys.color.icon_emphasize') }),
    new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.message')).fontColor([$r('sys.color.icon_primary')]),
      selected: new SymbolGlyphModifier($r('sys.symbol.message_fill')).fontColor([$r('sys.color.icon_emphasize')])
    }, $r('app.string.tab_message')).labelStyle({ unselectedColor: $r('sys.color.icon_primary'), selectedColor: $r('sys.color.icon_emphasize') }),
    new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.person')).fontColor([$r('sys.color.icon_primary')]),
      selected: new SymbolGlyphModifier($r('sys.symbol.person_fill')).fontColor([$r('sys.color.icon_emphasize')])
    }, $r('app.string.tab_mine')).labelStyle({ unselectedColor: $r('sys.color.icon_primary'), selectedColor: $r('sys.color.icon_emphasize') }),
  ];
  private controller: HdsTabsController = new HdsTabsController();
  @Local isMiniBar: boolean = true;

  @Builder
  miniBarBuilder() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(this.isMiniBar ? 28 : $r('sys.float.Title_M'))
          .fontColor([$r('sys.color.icon_primary')])
      }
      .padding(this.isMiniBar ? 14 : $r('sys.float.padding_level3'))
      .width(56)
      .aspectRatio(1)
      .justifyContent(FlexAlign.Center)

      Column({ space: 6 }) {
        Text('康小伴')
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        Text('沉浸光感体验')
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
      }
      .padding({ left: $r('sys.float.padding_level1') })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
          .fontSize($r('sys.float.Title_M'))
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize($r('sys.float.Title_M'))
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize($r('sys.float.Title_M'))
      }
      .padding({
        left: $r('sys.float.padding_level4'),
        right: $r('sys.float.padding_level8')
      })
    }
  }

  build() {
    HdsNavDestination() {
      HdsTabs({ controller: this.controller }) {
        ForEach(this.tabsBar, (tab: BottomTabBarStyle, index: number) => {
          TabContent() {
            Column() {
              Search({ placeholder: '搜索内容' })
                .width('100%')
                .margin({ bottom: $r('sys.float.padding_level4') })
                .borderRadius($r('sys.float.corner_radius_level8'))
                .height(40)

              Text('Tab ' + index)
                .fontSize(24)
            }
            .width('100%')
            .height('100%')
            .padding({
              left: $r('sys.float.padding_level4'),
              right: $r('sys.float.padding_level4'),
              top: $r('sys.float.padding_level4')
            })
            .justifyContent(FlexAlign.Start)
          }
          .tabBar(tab)
        })
      }
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        barBottomMargin: getWindowInfoState().navigationBarBottomVp > 0 ? getWindowInfoState().navigationBarBottomVp :
          $r('sys.float.padding_level8'),
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        miniBar: {
          miniBarBuilder: () => this.miniBarBuilder(),
          onBarStyleChange: (miniBarStyle: HdsBarStyle) => {
            this.isMiniBar = miniBarStyle === HdsBarStyle.COLLAPSE
          }
        }
      })
      .onAttach(() => {
        try {
          this.controller.preloadItems([0, 1, 2, 3]);
        } catch (error) {
          console.error('OnAttach preloadItems failed');
        }
      })
    }
    .titleBar({
      content: {
        title: {
          mainTitle: '首页',
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    })
    .hideBackButton(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}