import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { TextModifier } from '@ohos.arkui.modifier';
import { BusinessStore } from '../../network/BusinessStore';
import { Bed, Room } from '../../network/Dto';
import {
  QuickEmptyHint,
  QuickMetricStrip,
  quickBedStatusTone,
  quickBedStatusText,
  quickElderName,
  quickRoomLabel
} from './WideDoctorQuickPageKit';

/** 医师端「床位预览」：沉浸式只读路由页，按房间分组展示床位与入住状态。 */
@ComponentV2
export struct WideDoctorBedsPage {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local businessStore: BusinessStore = BusinessStore.getShared();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // Idempotent refresh so beds/rooms/elders are present even if the user
    // deep-navigates before the workspace snapshot finishes loading.
    void this.businessStore.load();
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  private bedsInRoom(room: Room): Bed[] {
    return this.businessStore.beds.filter((bed: Bed) => bed.room_id === room.id);
  }

  private statusToneModifier(tone: ResourceColor): TextModifier {
    return new TextModifier().fontColor(tone);
  }

  @Builder
  private bedRows(room: Room) {
    ForEach(this.bedsInRoom(room), (bed: Bed) => {
      HdsListItemCard({
        textItem: {
          primaryText: { text: `床位 ${bed.bed_no}` },
          secondaryText: { text: bed.status === 'occupied' ?
            quickElderName(this.businessStore, bed.elder_id) : '未入住' }
        },
        suffixItem: new SuffixText({
          text: quickBedStatusText(bed.status),
          modifier: this.statusToneModifier(quickBedStatusTone(bed.status))
        }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 56,
        hoverBorderRadius: 0
      })
    }, (bed: Bed) => `quick-bed-${bed.id}`)
  }

  @Builder
  private roomCard(room: Room) {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text(quickRoomLabel(room))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        Text(`${this.bedsInRoom(room).length} 床`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .height(58)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })

      Column({ space: 0 }) {
        this.bedRows(room)
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private roomCards() {
    ForEach(this.businessStore.rooms, (room: Room) => {
      this.roomCard(room)
    }, (room: Room) => `quick-room-${room.id}`)
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 16 }) {
            QuickMetricStrip({
              metrics: [
                { label: '总床位', value: `${this.businessStore.beds.length}`, tone: $r('sys.color.font_secondary') },
                {
                  label: '已入住',
                  value: `${this.businessStore.beds.filter((bed: Bed) => bed.status === 'occupied').length}`,
                  tone: $r('app.color.doctor_workspace_focus')
                },
                {
                  label: '空闲',
                  value: `${this.businessStore.beds.filter((bed: Bed) => bed.status !== 'occupied' &&
                    bed.status !== 'maintenance').length}`,
                  tone: $r('app.color.doctor_workspace_success')
                },
                {
                  label: '维护中',
                  value: `${this.businessStore.beds.filter((bed: Bed) => bed.status === 'maintenance').length}`,
                  tone: $r('sys.color.font_tertiary')
                }
              ]
            })

            if (this.businessStore.rooms.length === 0 && this.businessStore.beds.length === 0) {
              Column({ space: 0 }) {
                Row({ space: 8 }) {
                  Text('床位列表')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                }
                .width('100%')
                .height(58)
                .padding({ left: 16, right: 16 })
                .alignItems(VerticalAlign.Center)

                Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })

                QuickEmptyHint({ text: '暂无床位数据', loading: this.businessStore.loading })
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .clip(true)
              .border({ width: 0.5, color: $r('sys.color.comp_divider') })
            } else {
              this.roomCards()
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: this.compactWidth ? 1040 : 1320 })
          .padding({
            left: this.compactWidth ? 16 : 24,
            right: this.compactWidth ? 16 : 24,
            top: this.statusBarHeight + 56,
            bottom: 20 + this.naviIndicatorHeight
          })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onBackPressed((): boolean => {
      this.onClose();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '床位预览' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
