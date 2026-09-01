import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';

@ComponentV2
struct AdmissionGroupCard {
  @Param @Require icon: Resource;
  @Param @Require title: string;
  @Param @Require subtitle: string;
  @BuilderParam @Require content: () => void;

  build() {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(this.icon).fontColor([$r('app.color.brand_blue')])
          }
        }),
        textItem: {
          primaryText: { text: this.title },
          secondaryText: { text: this.subtitle }
        },
        suffixItem: new SuffixText({ text: '填写' }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 64,
        cardPrefixMargin: 16,
        cardSuffixMargin: 16,
        hoverBorderRadius: 0
      })
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 });
      Column({ space: 16 }) {
      this.content()
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }
}

/** 医师端办理入住页面：设置详情页风格，当前只做前端填写与确认。 */
@ComponentV2
export struct WideDoctorAdmissionForm {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local name: string = '';
  @Local gender: string = '';
  @Local idCard: string = '';
  @Local birthDate: string = '';
  @Local phone: string = '';
  @Local contact: string = '';
  @Local contactPhone: string = '';
  @Local admissionDate: string = '';
  @Local careLevel: string = '';
  @Local roomType: string = '';
  @Local diagnosis: string = '';
  @Local medication: string = '';
  @Local allergy: string = '';
  @Local note: string = '';
  @Local submitted: boolean = false;
  @Local activeField: string = '';

  private scroller: Scroller = new Scroller();
  private readonly careLevelOptions: string[] = ['自理', '半护理', '全护理', '特级护理'];
  private readonly roomOptions: string[] = ['普通房', '双人房', '单人房'];

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

  private horizontalPadding(): number {
    return this.compactWidth ? 16 : 24;
  }

  private requiredReady(): boolean {
    return this.name.trim().length > 0 && this.gender.length > 0 &&
      this.idCard.trim().length > 0 && this.birthDate.trim().length > 0 &&
      this.admissionDate.trim().length > 0 && this.careLevel.length > 0;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // 页面退出后不阻断表单状态。
    }
  }

  private confirmForm(): void {
    if (!this.requiredReady()) {
      this.showToast('请先填写带 * 的必填项');
      return;
    }
    this.submitted = true;
  }

  private resetForm(): void {
    this.name = '';
    this.gender = '';
    this.idCard = '';
    this.birthDate = '';
    this.phone = '';
    this.contact = '';
    this.contactPhone = '';
    this.admissionDate = '';
    this.careLevel = '';
    this.roomType = '';
    this.diagnosis = '';
    this.medication = '';
    this.allergy = '';
    this.note = '';
    this.submitted = false;
    this.activeField = '';
  }

  @Builder
  private textField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, required: boolean = false, numeric: boolean = false) {
    Column({ space: 6 }) {
      Row() {
        Text(required ? `${label} *` : label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        if (required && value.trim().length === 0) {
          Text('必填').fontSize(10).fontColor($r('sys.color.font_tertiary'))
        }
      }.width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(46)
        .fontSize(14)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: this.activeField === label ? 1.5 : 0.5,
          color: this.activeField === label ? $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
        .type(numeric ? InputType.Number : InputType.Normal)
        .onFocus(() => this.activeField = label)
        .onChange((next: string) => {
          onChange(next);
          this.activeField = label;
        })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private textAreaField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).width('100%')
      TextArea({ text: value, placeholder: placeholder })
        .width('100%')
        .height(88)
        .fontSize(14)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .onChange((next: string) => onChange(next))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private choiceField(label: string, options: string[], selected: string,
    onSelect: (value: string) => void, required: boolean = false) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label).fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(options, (option: string) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Text(option).fontSize(13)
              .fontColor(selected === option ? Color.White : $r('sys.color.font_secondary'))
          }
          .height(40)
          .padding({ left: 18, right: 18 })
          .margin({ right: 8, bottom: 8 })
          .borderRadius(20)
          .backgroundColor(selected === option ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_secondary'))
          .border({ width: selected === option ? 0 : 0.5, color: $r('sys.color.comp_divider') })
          .accessibilityText(`${label}${option}`)
          .onClick(() => onSelect(option))
        }, (option: string) => `${label}-${option}`)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private formContent() {
    Column({ space: 16 }) {
      AdmissionGroupCard({ icon: $r('sys.symbol.person_fill'), title: '长者身份', subtitle: '基本身份与联系资料',
        content: (): void => { this.identityFields(); } });
      AdmissionGroupCard({ icon: $r('sys.symbol.heart_fill'), title: '健康情况', subtitle: '疾病、用药与过敏信息',
        content: (): void => { this.healthFields(); } });
      AdmissionGroupCard({ icon: $r('sys.symbol.calendar_fill'), title: '入住安排', subtitle: '日期、护理等级与房型偏好',
        content: (): void => { this.arrangementFields(); } });

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.info_circle')).fontSize(18)
          .fontColor([$r('app.color.brand_blue')])
        Text('当前为前端填写预览，确认后不会提交服务器。')
          .fontSize(12).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    }.width('100%')
  }

  @Builder
  private identityFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('姓名', '请输入长者姓名', this.name, (value: string) => this.name = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.choiceField('性别', ['男', '女'], this.gender, (value: string) => this.gender = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('证件号码', '身份证或其他证件号', this.idCard,
          (value: string) => this.idCard = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('出生日期', '例如 1942-06-18', this.birthDate,
          (value: string) => this.birthDate = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('联系电话', '长者本人手机号（可选）', this.phone,
          (value: string) => this.phone = value, false, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('紧急联系人', '姓名或关系', this.contact, (value: string) => this.contact = value)
      }
      GridCol({ span: 12 }) {
        this.textField('紧急联系电话', '联系人手机号', this.contactPhone,
          (value: string) => this.contactPhone = value, false, true)
      }
    }.width('100%')
  }

  @Builder
  private healthFields() {
    Column({ space: 16 }) {
      this.textAreaField('既往诊断', '例如：高血压、骨关节病', this.diagnosis,
        (value: string) => this.diagnosis = value)
      this.textAreaField('用药说明', '例如：阿司匹林，每日一次', this.medication,
        (value: string) => this.medication = value)
      this.textAreaField('过敏史', '例如：青霉素，皮疹；无过敏史可填写“无”', this.allergy,
        (value: string) => this.allergy = value)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private arrangementFields() {
    Column({ space: 16 }) {
      this.textField('计划入住日期', '例如 2026-09-01', this.admissionDate,
        (value: string) => this.admissionDate = value, true)
      this.choiceField('护理等级', this.careLevelOptions, this.careLevel,
        (value: string) => this.careLevel = value, true)
      this.choiceField('房型偏好', this.roomOptions, this.roomType,
        (value: string) => this.roomType = value)
      this.textAreaField('入住备注', '记录接待安排、饮食偏好或其他需要关注的事项', this.note,
        (value: string) => this.note = value)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private resultView() {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(52)
        .fontColor([$r('app.color.brand_blue')])
      Text('入住资料已填写完成').fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text('这是前端确认状态，后续可接入入住申请接口。')
        .fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      AdmissionGroupCard({ icon: $r('sys.symbol.checkmark_circle_fill'), title: '填写完成', subtitle: '前端确认信息', content: () => {
        HdsListItemCard({
          textItem: {
            primaryText: { text: this.name },
            secondaryText: { text: `${this.careLevel} · ${this.admissionDate}` }
          },
          suffixItem: new SuffixText({ text: '待提交' }),
          cardBorderRadius: 0,
          cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          cardHeight: 68,
          cardPrefixMargin: 16,
          cardSuffixMargin: 16,
          hoverBorderRadius: 0
        })
      } }).width(this.compactWidth ? '100%' : 520)
      Row({ space: 10 }) {
        Button('重新填写').height(44).borderRadius(12).fontSize(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.resetForm())
        Button('返回工作台').height(44).borderRadius(12).fontSize(14)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .onClick(() => this.onClose())
      }
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private footer() {
    Row({ space: 10 }) {
      Button('取消').height(44).borderRadius(12).fontSize(14)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .onClick(() => this.onClose())
      Button('确认填写完成').height(44).borderRadius(12).fontSize(14)
        .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
        .opacity(this.requiredReady() ? 1 : 0.45)
        .onClick(() => this.confirmForm())
    }
    .width(this.compactWidth ? '100%' : undefined)
    .padding({ top: 12, bottom: 12 + this.naviIndicatorHeight })
  }

  build() {
    HdsNavDestination() {
      if (this.submitted) {
        Column() {
          this.resultView()
        }
        .width('100%')
        .height('100%')
        .padding({ left: this.horizontalPadding(), right: this.horizontalPadding(),
          top: 24 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      } else {
          Column() {
            Scroll(this.scroller) {
              Row() {
                Column({ space: 18 }) {
                  this.formContent()
                }
                .width('100%')
                .constraintSize({ maxWidth: 720 })
                .padding({ left: this.horizontalPadding(), right: this.horizontalPadding(),
                  top: this.statusBarHeight + 56, bottom: 32 + this.naviIndicatorHeight })
                .alignItems(HorizontalAlign.Center)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          Row() {
            this.footer()
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .border({ width: { top: 0.5 }, color: { top: $r('sys.color.comp_divider') } })
          .padding({ left: this.horizontalPadding(), right: this.horizontalPadding() })
        }
        .width('100%')
        .height('100%')
      }
    }
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '办理入住' },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.xmark'),
              isEnabled: true,
              action: () => this.onClose()
            }
          }]
        }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
