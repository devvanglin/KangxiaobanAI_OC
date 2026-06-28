import { CommonConstants } from '../common/CommonConstants';
import { Model } from '../model/Model';
import { CardType } from '../common/CommonEnums';

@Reusable
@Component
export struct ReusableItemView {
  @State item: Model | undefined = undefined;
  @State isSelected: boolean = false;

  aboutToReuse(params: ESObject): void {
    this.item = params.item;
    this.isSelected = params.isSelected;
  }

  @Builder
  viewsBuilder() {
    Row() {
      Image($r("app.media.ic_eye_open"))
        .fillColor($r('sys.color.ohos_id_color_text_secondary'))
        .width($r("app.float.ske_icon_size"))
        .aspectRatio(CommonConstants.IMAGE_ASPECT_RATIO_ONE)
        .margin({ right: $r("app.float.ske_xs_padding_margin") })
      Text(`${this.item?.views}`)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .fontSize($r("app.float.ske_normal_text_size"))
        .width($r("app.float.ske_view_count_icon_width"))
        .opacity(CommonConstants.SECOND_LEVEL_OPACITY)
    }
  }

  @Builder
  likesBuilder() {
    Row() {
      Image(this.item?.isLike ? $r('app.media.ic_good_on') : $r('app.media.ic_good_off'))
        .fillColor($r('sys.color.ohos_id_color_text_secondary'))
        .width($r("app.float.ske_icon_size"))
        .aspectRatio(CommonConstants.IMAGE_ASPECT_RATIO_ONE)
        .margin({ right: $r("app.float.ske_xs_padding_margin") })
      Text(`${this.item?.likes}`)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .fontSize($r("app.float.ske_normal_text_size"))
        .width($r("app.float.ske_view_count_icon_width"))
        .opacity(CommonConstants.SECOND_LEVEL_OPACITY)
    }
  }

  @Builder
  collectBuilder() {
    Row() {
      Image(this.item?.isCollection ? $r('app.media.ic_collect_on') : $r('app.media.ic_collect_off'))
        .fillColor($r('sys.color.ohos_id_color_text_secondary'))
        .width($r("app.float.ske_icon_size"))
        .aspectRatio(CommonConstants.IMAGE_ASPECT_RATIO_ONE)
        .margin({ right: $r("app.float.ske_xs_padding_margin") })
      Text(`${this.item?.collections}`)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .fontSize($r("app.float.ske_normal_text_size"))
        .width($r("app.float.ske_view_count_icon_width"))
        .opacity(CommonConstants.SECOND_LEVEL_OPACITY)
    }
  }

  @Builder
  typeBuilder() {
    Text($r("app.string.ske_photography_works"))
      .fontSize($r("app.float.ske_xs_font_size"))
      .fontColor('#FF3E50')
      .textAlign(TextAlign.Center)
      .fontWeight(FontWeight.Medium)
      .fontFamily(CommonConstants.HARMONY_HEI_TI_MEDIUM_FONT_FAMILY)
      .borderRadius($r("app.float.ske_xs_border_radius"))
      .backgroundColor('#1AFF3E50')
      .padding({
        left: $r("app.float.ske_sm_padding_margin"),
        right: $r("app.float.ske_sm_padding_margin"),
        top: $r("app.float.ske_xxs_padding_margin"),
        bottom: $r("app.float.ske_xxs_padding_margin")
      })
  }

  @Builder
  tagBuilder() {
    Text($r("app.string.ske_natural_scenery"))
      .fontSize($r("app.float.ske_xs_font_size"))
      .fontColor('#0A59F7')
      .textAlign(TextAlign.Center)
      .fontWeight(FontWeight.Medium)
      .fontFamily(CommonConstants.HARMONY_HEI_TI_MEDIUM_FONT_FAMILY)
      .borderRadius($r("app.float.ske_xs_border_radius"))
      .backgroundColor('#1A0A59F7')
      .padding({
        left: $r("app.float.ske_sm_padding_margin"),
        right: $r("app.float.ske_sm_padding_margin"),
        top: $r("app.float.ske_xxs_padding_margin"),
        bottom: $r("app.float.ske_xxs_padding_margin")
      })
  }

  build() {
    // TODO: 知识点：相对布局组件，用于复杂场景中元素对齐的布局，容器内子组件区分水平方向，垂直方向子组件可以将容器或者其他子组件设为锚点。
    RelativeContainer() {
      Row() {
        Column() {
          // 标题
          Text(this.item?.title)
            .fontSize($r("app.float.ske_normal_text_size"))
            .fontFamily(CommonConstants.HARMONY_HEI_TI_FONT_FAMILY)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .opacity(CommonConstants.FIRST_LEVEL_OPACITY)
            .width(CommonConstants.FULL_PERCENT)
            .maxLines(CommonConstants.MAX_LINE_ONE)
            .alignRules({
              top: { anchor: "__container__", align: VerticalAlign.Top },
              left: { anchor: "__container__", align: HorizontalAlign.Start }
            })
            .id("title")
          // 内容
          Text(this.item?.content)
            .fontSize($r("app.float.ske_small_text_size"))
            .fontFamily(CommonConstants.HARMONY_HEI_TI_FONT_FAMILY)
            .opacity(CommonConstants.SECOND_LEVEL_OPACITY)
            .maxLines(CommonConstants.MAX_LINE_TWO)
            .width(CommonConstants.FULL_PERCENT)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .alignRules({
              left: { anchor: "title", align: HorizontalAlign.Start },
              top: { anchor: "title", align: VerticalAlign.Bottom }
            })
            .margin({ top: $r("app.float.ske_xs_padding_margin") })
            .id("content")


          if (this.item?.type === CardType.OTHER) {
            Row() {
              // 浏览量
              this.viewsBuilder()
              // 点赞数
              this.likesBuilder()
              // 收藏量
              this.collectBuilder()
            }
            .width(CommonConstants.FULL_PERCENT)
            .height($r("app.float.ske_row_height"))
            .alignRules({
              left: { anchor: "content", align: HorizontalAlign.Start },
              top: { anchor: "content", align: VerticalAlign.Bottom }
            })
            .justifyContent(FlexAlign.SpaceBetween)
          } else {
            Row({ space: CommonConstants.SPACE_12 }) {
              // 摄影作品标签
              this.typeBuilder()
              // 自然风光标签
              this.tagBuilder()
            }
            .width('100%')
            .height($r("app.float.ske_row_height"))
            .padding({ left: $r("app.float.ske_sm_padding_margin"), right: $r("app.float.ske_sm_padding_margin") })
            .alignRules({
              left: { anchor: "content", align: HorizontalAlign.Start },
              top: { anchor: "content", align: VerticalAlign.Bottom }
            })
            .justifyContent(FlexAlign.Start)
          }
        }
        .padding($r("app.float.ske_md_padding_margin"))
        .height(CommonConstants.FULL_PERCENT)
        .layoutWeight(CommonConstants.LAYOUT_WEIGHT)

        // 图片
        Image(this.item?.uri)
          .height($r("app.float.ske_image_height"))
          .backgroundColor($r('app.color.skeleton_color_light'))
          .aspectRatio(CommonConstants.IMAGE_ASPECT_RATIO_ONE_POINT_SIX)
          .objectFit(ImageFit.Cover)
          .borderRadius($r("app.float.ske_small_border_radius"))
          .alignRules({
            center: { anchor: "__container__", align: VerticalAlign.Center },
            right: { anchor: "__container__", align: HorizontalAlign.End }
          })
          .margin({ right: $r("app.float.ske_md_padding_margin") })
          .id("image")
      }
    }
    .backgroundColor(Color.White)
    .borderRadius($r("app.float.ske_small_border_radius"))
    .width(CommonConstants.FULL_PERCENT)
    .height($r("app.float.ske_card_height"))
    // item选中时的背景渐变色
    .linearGradient(this.isSelected ? {
      angle: '90',
      colors: [["#FFDCEAF9", 0], ["#FFF1F3F5", 1]]
    } : { colors: [] })
  }
}