import { HERMES_CATEGORIES, HERMES_NAV_ITEMS } from '../data/HermesCatalog';
import { HermesNavItem } from '../model/HermesModels';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';

@ComponentV2
export struct HermesSidebar {
  @Param @Require selectedKey: string;
  @Param collapsed: boolean = false;
  @Param mobile: boolean = false;
  @Event onSelect: (key: string) => void = (_key: string) => {};
  @Event onToggleCollapse: () => void = () => {};
  @Event onLogout: () => void = () => {};

  private itemsFor(category: string): HermesNavItem[] {
    return HERMES_NAV_ITEMS.filter((item: HermesNavItem) => item.category === category);
  }

  @Builder
  private navItem(item: HermesNavItem) {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconSize: IconSize.SYSTEM_ICON,
        iconValue: {
          symbol: new SymbolGlyphModifier($r('sys.symbol.chevron_right'))
            .fontColor([this.selectedKey === item.key ? $r('app.color.hermes_text_primary') :
              $r('app.color.hermes_text_secondary')])
        }
      }),
      textItem: this.collapsed ? undefined : {
        primaryText: { text: item.title }
      },
      suffixItem: this.collapsed ? undefined : (this.selectedKey === item.key ?
        new SuffixText({ text: '当前' }) : new SuffixArrow()),
      cardHeight: 42,
      cardBorderRadius: 8,
      cardPrefixMargin: this.collapsed ? 0 : 2,
      cardSuffixMargin: 0,
      hoverBorderRadius: 8,
      cardBackgroundColor: this.selectedKey === item.key ? $r('app.color.hermes_bg_surface') : Color.Transparent,
      cardId: `nav-${item.key}`,
      accessibilityOptions: {
        accessibilityText: item.title,
        accessibilityDescription: item.description,
        accessibilityLevel: 'yes',
        accessibilityRole: AccessibilityRoleType.BUTTON,
        accessibilitySelected: this.selectedKey === item.key
      },
      onClick: () => {
        this.onSelect(item.key);
      }
    })
    .focusable(true)
    .focusOnTouch(true)
    .width('100%')
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.hermes_logo'))
          .width(38)
          .height(38)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
          .accessibilityText('Hermes Studio')

        if (!this.collapsed) {
          Column({ space: 1 }) {
            Text('Hermes Studio')
              .fontSize($r('app.float.hermes_text_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.hermes_text_primary'))
            Text('HarmonyOS')
              .fontSize($r('app.float.hermes_text_caption'))
              .fontColor($r('app.color.hermes_text_muted'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height(62)
      .padding({ left: this.collapsed ? 12 : 14, right: 12 })
      .border({ width: { bottom: 1 }, color: $r('app.color.hermes_border_light') })

      Scroll() {
        Column({ space: 6 }) {
          ForEach(HERMES_CATEGORIES, (category: string) => {
            if (!this.collapsed) {
              Text(category)
                .width('100%')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.hermes_text_muted'))
                .padding({ left: 10, top: 12, bottom: 2 })
            }

            ForEach(this.itemsFor(category), (item: HermesNavItem) => {
              this.navItem(item)
            }, (item: HermesNavItem) => item.key)
          }, (category: string) => category)
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)

      Column({ space: 6 }) {
        HdsListItemCard({
          prefixItem: new PrefixIcon({
            iconSize: IconSize.SYSTEM_ICON,
            iconValue: {
              symbol: new SymbolGlyphModifier($r('sys.symbol.person_crop_circle_fill'))
                .fontColor([$r('app.color.hermes_text_secondary')])
            }
          }),
          textItem: this.collapsed ? undefined : {
            primaryText: { text: 'default' },
            secondaryText: { text: 'Profile 已连接' }
          },
          suffixItem: this.collapsed ? undefined : new SuffixText({ text: '在线' }),
          cardHeight: 54,
          cardBorderRadius: 8,
          cardPrefixMargin: 2,
          cardSuffixMargin: 0,
          cardBackgroundColor: $r('app.color.hermes_bg_surface'),
          accessibilityOptions: {
            accessibilityText: 'default Profile 已连接',
            accessibilityLevel: 'yes'
          }
        })
        .width('100%')

        if (!this.mobile) {
          HdsListItemCard({
            textItem: { primaryText: { text: this.collapsed ? '展开' : '收起侧栏' } },
            suffixItem: this.collapsed ? undefined : new SuffixArrow(),
            cardHeight: 38,
            cardBorderRadius: 8,
            cardPrefixMargin: 0,
            cardSuffixMargin: 0,
            cardBackgroundColor: Color.Transparent,
            accessibilityOptions: {
              accessibilityText: this.collapsed ? '展开侧栏' : '收起侧栏',
              accessibilityRole: AccessibilityRoleType.BUTTON
            },
            onClick: () => this.onToggleCollapse()
          })
          .width('100%')
          .focusable(true)
        }

        HdsListItemCard({
          textItem: { primaryText: { text: this.collapsed ? '退出' : '退出登录' } },
          suffixItem: this.collapsed ? undefined : new SuffixArrow(),
          cardHeight: 38,
          cardBorderRadius: 8,
          cardPrefixMargin: 0,
          cardSuffixMargin: 0,
          cardBackgroundColor: Color.Transparent,
          accessibilityOptions: {
            accessibilityText: '退出登录',
            accessibilityRole: AccessibilityRoleType.BUTTON
          },
          onClick: () => this.onLogout()
        })
        .width('100%')
        .focusable(true)
      }
      .width('100%')
      .padding(8)
      .border({ width: { top: 1 }, color: $r('app.color.hermes_border_light') })
    }
    .width(this.mobile ? '100%' : (this.collapsed ? $r('app.float.hermes_sidebar_compact_width') :
      $r('app.float.hermes_sidebar_width')))
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_sidebar'))
  }
}
