import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';

@ComponentV2
struct AdmissionGroupCard {
  @Param @Require title: string;
  @BuilderParam @Require content: () => void;

  build() {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: this.title },
        },
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 58,
        hoverBorderRadius: 0
      })
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 });
      Column({ space: 18 }) {
      this.content()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 22 })
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
  @Local age: string = '';
  @Local phone: string = '';
  @Local familyAddress: string = '';
  @Local familyName: string = '';
  @Local familyPhone: string = '';
  @Local familyRelation: string = '';
  @Local admissionDate: string = '';
  @Local admissionEndDate: string = '';
  @Local feeStartDate: string = '';
  @Local feeEndDate: string = '';
  @Local careLevel: string = '';
  @Local roomType: string = '';
  @Local bedName: string = '';
  @Local deposit: string = '';
  @Local careFee: string = '';
  @Local bedFee: string = '';
  @Local otherFee: string = '';
  @Local medicalInsurance: string = '';
  @Local subsidy: string = '';
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
      this.idCard.trim().length > 0 && this.birthDate.trim().length > 0 && this.age.trim().length > 0 &&
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
    this.age = '';
    this.phone = '';
    this.familyAddress = '';
    this.familyName = '';
    this.familyPhone = '';
    this.familyRelation = '';
    this.admissionDate = '';
    this.admissionEndDate = '';
    this.feeStartDate = '';
    this.feeEndDate = '';
    this.careLevel = '';
    this.roomType = '';
    this.bedName = '';
    this.deposit = '';
    this.careFee = '';
    this.bedFee = '';
    this.otherFee = '';
    this.medicalInsurance = '';
    this.subsidy = '';
    this.note = '';
    this.submitted = false;
    this.activeField = '';
  }

  @Builder
  private textField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, required: boolean = false, numeric: boolean = false) {
    Row({ space: 12 }) {
      Text(required ? `${label} *` : label)
        .width(this.compactWidth ? 86 : 106)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End)
      TextInput({ text: value, placeholder: placeholder })
        .layoutWeight(1)
        .height(48)
        .fontSize(15)
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
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder
  private textAreaField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void) {
    Row({ space: 12 }) {
      Text(label).width(this.compactWidth ? 86 : 106)
        .fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).textAlign(TextAlign.End)
      TextArea({ text: value, placeholder: placeholder })
        .layoutWeight(1)
        .height(112)
        .fontSize(15)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .onChange((next: string) => onChange(next))
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private choiceField(label: string, options: string[], selected: string,
    onSelect: (value: string) => void, required: boolean = false) {
    Row({ space: 12 }) {
      Text(required ? `${label} *` : label).width(this.compactWidth ? 86 : 106)
        .fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).textAlign(TextAlign.End)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(options, (option: string) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Text(option).fontSize(14)
              .textAlign(TextAlign.Center)
              .fontColor(selected === option ? Color.White : $r('sys.color.font_secondary'))
          }
          .width(88)
          .padding(0)
          .height(40)
          .margin({ right: 8, bottom: 8 })
          .borderRadius(10)
          .backgroundColor(selected === option ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_secondary'))
          .border({ width: selected === option ? 0 : 0.5, color: $r('sys.color.comp_divider') })
          .accessibilityText(`${label}${option}`)
          .onClick(() => onSelect(option))
        }, (option: string) => `${label}-${option}`)
      }.layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private dateRangeField(label: string, startPlaceholder: string, endPlaceholder: string,
    startValue: string, endValue: string, onStartChange: (value: string) => void,
    onEndChange: (value: string) => void) {
    Row({ space: 12 }) {
      Text(label).width(this.compactWidth ? 86 : 106)
        .fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).textAlign(TextAlign.End)
      Row({ space: 8 }) {
        TextInput({ text: startValue, placeholder: startPlaceholder })
          .layoutWeight(1)
          .height(48)
          .fontSize(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onStartChange(next))
        Text('至').fontSize(14).fontColor($r('sys.color.font_secondary'))
        TextInput({ text: endValue, placeholder: endPlaceholder })
          .layoutWeight(1)
          .height(48)
          .fontSize(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onEndChange(next))
      }.layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  private adjustAmount(current: string, delta: number, onChange: (value: string) => void): void {
    let amount: number = Number(current);
    if (isNaN(amount)) {
      amount = 0;
    }
    onChange(`${Math.max(0, amount + delta)}`);
  }

  @Builder
  private amountField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void) {
    Row({ space: 12 }) {
      Text(label).width(this.compactWidth ? 86 : 106)
        .fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).textAlign(TextAlign.End)
      Row({ space: 0 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text('−').fontSize(20).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
        }
          .width(38)
          .height(42)
          .padding(0)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topLeft: 10, bottomLeft: 10 })
          .accessibilityText(`减少${label}`)
          .onClick(() => this.adjustAmount(value, -100, onChange))
        TextInput({ text: value, placeholder: placeholder })
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .type(InputType.Number)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(0)
          .border({ width: { top: 0.5, bottom: 0.5 }, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onChange(next))
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text('+').fontSize(20).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
        }
          .width(38)
          .height(42)
          .padding(0)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topRight: 10, bottomRight: 10 })
          .accessibilityText(`增加${label}`)
          .onClick(() => this.adjustAmount(value, 100, onChange))
      }.layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder
  private uploadField(label: string, description: string) {
    Row({ space: 12 }) {
      Text(label).width(this.compactWidth ? 86 : 106)
        .fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary')).textAlign(TextAlign.End)
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(20)
          .fontColor([$r('app.color.brand_blue')])
        Column({ space: 2 }) {
          Text('点击上传').fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
          Text(description).fontSize(11).fontColor($r('sys.color.font_tertiary'))
        }.alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .height(72)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(10)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .onClick(() => this.showToast('照片上传功能待接入'))
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  @Builder
  private formContent() {
    Column({ space: 20 }) {
      AdmissionGroupCard({ title: '基本信息',
        content: (): void => { this.identityFields(); } });
      AdmissionGroupCard({ title: '家属信息',
        content: (): void => { this.familyFields(); } });
      AdmissionGroupCard({ title: '入住配置',
        content: (): void => { this.arrangementFields(); } });
    }.width('100%')
  }

  @Builder
  private identityFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('姓名', '请输入长者姓名', this.name, (value: string) => this.name = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('身份证号', '请输入身份证号', this.idCard,
          (value: string) => this.idCard = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('出生日期', '请选择出生日期', this.birthDate,
          (value: string) => this.birthDate = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('年龄', '请输入年龄', this.age,
          (value: string) => this.age = value, true, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.choiceField('性别', ['男', '女'], this.gender, (value: string) => this.gender = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('联系方式', '请输入手机号或其他联系方式', this.phone,
          (value: string) => this.phone = value, false, true)
      }
      GridCol({ span: 12 }) {
        this.textAreaField('家庭住址', '请输入家庭住址', this.familyAddress,
          (value: string) => this.familyAddress = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.uploadField('一寸照片', '支持 JPG、PNG 格式')
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.uploadField('身份证人像面', '请上传清晰证件照片')
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.uploadField('身份证国徽面', '请上传清晰证件照片')
      }
    }.width('100%')
  }

  @Builder
  private familyFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 3 }) {
        this.textField('家属姓名', '请输入主要联系人姓名', this.familyName,
          (value: string) => this.familyName = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 3 }) {
        this.textField('家属联系方式', '请输入手机号或其他联系方式', this.familyPhone,
          (value: string) => this.familyPhone = value, false, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.choiceField('与长者关系', ['子女', '配偶', '亲属', '其他'], this.familyRelation,
          (value: string) => this.familyRelation = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 2 }) {
        Row({ space: 8 }) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(16)
                .fontColor([$r('app.color.brand_blue')])
              Text('添加家属').fontSize(13).fontColor($r('app.color.brand_blue'))
            }
          }
          .height(38)
          .padding({ left: 10, right: 10 })
          .borderRadius(19)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showToast('家属信息可继续添加'))
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.minus')).fontSize(16)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.showToast('当前至少保留一位联系人'))
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }.width('100%')
  }

  @Builder
  private arrangementFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.dateRangeField('入住期限', '开始日期', '结束日期', this.admissionDate, this.admissionEndDate,
          (value: string) => this.admissionDate = value,
          (value: string) => this.admissionEndDate = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.dateRangeField('费用期限', '开始日期', '结束日期', this.feeStartDate, this.feeEndDate,
          (value: string) => this.feeStartDate = value,
          (value: string) => this.feeEndDate = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.choiceField('护理等级', this.careLevelOptions, this.careLevel,
          (value: string) => this.careLevel = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.textField('入住床位', '请选择入住床位', this.bedName,
          (value: string) => this.bedName = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.amountField('押金', '请输入金额', this.deposit, (value: string) => this.deposit = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.amountField('护理费用', '请输入金额', this.careFee, (value: string) => this.careFee = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.amountField('床位费用', '请输入金额', this.bedFee, (value: string) => this.bedFee = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.amountField('其他费用', '请输入金额', this.otherFee, (value: string) => this.otherFee = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.amountField('医保支付', '请输入金额', this.medicalInsurance,
          (value: string) => this.medicalInsurance = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.amountField('政府补贴', '请输入金额', this.subsidy, (value: string) => this.subsidy = value)
      }
      GridCol({ span: 12 }) {
        this.textAreaField('入住备注', '记录接待安排、饮食偏好或其他需要关注的事项', this.note,
          (value: string) => this.note = value)
      }
    }.width('100%')
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
      AdmissionGroupCard({ title: '填写完成', content: () => {
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
    .width('100%')
    .justifyContent(FlexAlign.End)
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
                this.footer()
              }
              .width('100%')
              .constraintSize({ maxWidth: this.compactWidth ? 720 : 1320 })
              .padding({ left: this.horizontalPadding(), right: this.horizontalPadding(),
                top: this.statusBarHeight + 56, bottom: 20 + this.naviIndicatorHeight })
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
