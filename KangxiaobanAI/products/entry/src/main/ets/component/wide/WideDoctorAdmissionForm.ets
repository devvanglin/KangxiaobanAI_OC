import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { Bed } from '../../network/Dto';
import { BusinessStore } from '../../network/BusinessStore';
import AdmissionRepository, { AdmissionFailureKind } from '../../network/AdmissionRepository';
import { AdmissionIntakePayload, AdmissionIntakeResult } from '../../network/AdmissionApi';

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

/** 医师端办理入住页面：沉浸式详情页表单，提交到服务端完成入住办理。 */
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
  @Local freeBeds: Bed[] = [];
  @Local bedsLoading: boolean = false;
  @Local bedsError: string = '';
  @Local bedId: number = 0;
  @Local submitting: boolean = false;
  @Local submitError: string = '';
  @Local submitErrorKind: AdmissionFailureKind = 'none';
  @Local intakeResult: AdmissionIntakeResult | null = null;
  @Local idempotencyKey: string = '';

  private scroller: Scroller = new Scroller();
  private readonly careLevelOptions: string[] = ['自理', '半护理', '全护理', '重度护理', '特级护理'];

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

  /**
   * Keep the form readable without forcing a tablet window into a 720vp
   * column.  The admission surface is already inside a scroll container, so
   * the parent can shrink this value naturally on smaller windows while
   * medium windows get enough width for their single-column controls.
   */
  private formMaxWidth(): number {
    return this.compactWidth ? 1040 : 1320;
  }

  private controlHeight(): number {
    return this.compactWidth ? 46 : 48;
  }

  private requiredReady(): boolean {
    return this.name.trim().length > 0 && this.gender.length > 0 &&
      this.idCard.trim().length > 0 && this.birthDate.trim().length > 0 && this.age.trim().length > 0 &&
      this.admissionDate.trim().length > 0 && this.careLevel.length > 0 && this.bedId > 0;
  }

  private newIdempotencyKey(): string {
    return `intake-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
  }

  private validDate(value: string): boolean {
    const normalized: string = value.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
      return false;
    }
    const parsed: Date = new Date(`${normalized}T12:00:00`);
    return !Number.isNaN(parsed.getTime()) &&
      `${parsed.getFullYear()}-${(parsed.getMonth() + 1).toString().padStart(2, '0')}-${parsed.getDate().toString().padStart(2, '0')}` === normalized;
  }

  private amountValue(value: string, label: string): number | null {
    const normalized: string = value.trim();
    if (normalized.length === 0) {
      return 0;
    }
    const amount: number = Number(normalized);
    if (!Number.isFinite(amount) || amount < 0) {
      this.showToast(`${label}请输入有效的非负金额`);
      return null;
    }
    return amount;
  }

  private bedLabel(bed: Bed): string {
    const roomText: string = bed.room === undefined ? '' : `${bed.room.floor}F-${bed.room.room_no} · `;
    return `${roomText}${bed.bed_no}床`;
  }

  private selectedBedRoomType(): string {
    for (const bed of this.freeBeds) {
      if (bed.id === this.bedId && bed.room !== undefined) {
        return bed.room.type;
      }
    }
    return '';
  }

  private async loadFreeBeds(): Promise<void> {
    this.bedsLoading = true;
    this.bedsError = '';
    const result = await AdmissionRepository.freeBeds();
    this.bedsLoading = false;
    if (!result.ok || result.data === undefined) {
      this.bedsError = result.message.length > 0 ? result.message : '空床位加载失败';
      return;
    }
    this.freeBeds = result.data.list ?? [];
    if (this.bedId > 0 && !this.freeBeds.some((item: Bed) => item.id === this.bedId)) {
      this.bedId = 0;
      this.bedName = '';
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // 页面退出后不阻断表单状态。
    }
  }

  private intakePayload(): AdmissionIntakePayload | null {
    if (!this.validDate(this.birthDate) || !this.validDate(this.admissionDate)) {
      this.showToast('出生日期和入住开始日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    if (this.admissionEndDate.trim().length > 0 && !this.validDate(this.admissionEndDate)) {
      this.showToast('入住结束日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    if (this.feeStartDate.trim().length > 0 && !this.validDate(this.feeStartDate)) {
      this.showToast('费用开始日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    if (this.feeEndDate.trim().length > 0 && !this.validDate(this.feeEndDate)) {
      this.showToast('费用结束日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    const deposit: number | null = this.amountValue(this.deposit, '押金');
    const careFee: number | null = this.amountValue(this.careFee, '护理费用');
    const bedFee: number | null = this.amountValue(this.bedFee, '床位费用');
    const otherFee: number | null = this.amountValue(this.otherFee, '其他费用');
    const medicalInsurance: number | null = this.amountValue(this.medicalInsurance, '医保支付');
    const subsidy: number | null = this.amountValue(this.subsidy, '政府补贴');
    if (deposit === null || careFee === null || bedFee === null || otherFee === null ||
      medicalInsurance === null || subsidy === null) {
      return null;
    }
    return {
      idempotency_key: this.idempotencyKey,
      resident_name: this.name.trim(),
      gender: this.gender,
      birth_date: this.birthDate.trim(),
      age: Number(this.age.trim()),
      id_card: this.idCard.trim(),
      contact_phone: this.phone.trim(),
      family_address: this.familyAddress.trim(),
      family_name: this.familyName.trim(),
      family_phone: this.familyPhone.trim(),
      family_relation: this.familyRelation,
      admission_start_date: this.admissionDate.trim(),
      admission_end_date: this.admissionEndDate.trim(),
      fee_start_date: this.feeStartDate.trim(),
      fee_end_date: this.feeEndDate.trim(),
      // The room type is derived from the server-provided bed instead of a
      // second free-text selector, so the request cannot disagree with the
      // actual room that owns the selected bed.
      room_type: this.selectedBedRoomType(),
      care_level: this.careLevel,
      bed_id: this.bedId,
      deposit: deposit,
      care_fee: careFee,
      bed_fee: bedFee,
      other_fee: otherFee,
      medical_insurance: medicalInsurance,
      subsidy: subsidy,
      note: this.note.trim()
    };
  }

  private async confirmForm(): Promise<void> {
    if (!this.requiredReady()) {
      this.showToast('请填写必填项并选择真实空床位');
      return;
    }
    if (this.submitting) {
      return;
    }
    const payload: AdmissionIntakePayload | null = this.intakePayload();
    if (payload === null) {
      return;
    }
    this.submitting = true;
    this.submitError = '';
    this.submitErrorKind = 'none';
    const result = await AdmissionRepository.createIntake(payload);
    this.submitting = false;
    if (!result.ok || result.data === undefined || result.data.intake === undefined ||
      result.data.intake.status !== 'completed') {
      this.submitError = result.message.length > 0 ? result.message : '入住办理未完成，请稍后重试';
      this.submitErrorKind = result.kind;
      return;
    }
    this.intakeResult = result.data;
    this.submitted = true;
    // Refresh the shared operational snapshot after the server transaction
    // commits so resident, bed, task, and billing surfaces see the new record.
    void BusinessStore.getShared().load(true);
  }

  private resultPrimaryText(): string {
    return this.intakeResult === null ? this.name :
      `${this.intakeResult.elder.name} · ${this.intakeResult.intake.intake_no}`;
  }

  private resultSecondaryText(): string {
    return `${this.careLevel} · ${this.bedName} · ${this.admissionDate}`;
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
    this.bedName = '';
    this.bedId = 0;
    this.deposit = '';
    this.careFee = '';
    this.bedFee = '';
    this.otherFee = '';
    this.medicalInsurance = '';
    this.subsidy = '';
    this.note = '';
    this.submitted = false;
    this.submitting = false;
    this.submitError = '';
    this.submitErrorKind = 'none';
    this.intakeResult = null;
    this.idempotencyKey = this.newIdempotencyKey();
    this.activeField = '';
  }

  aboutToAppear(): void {
    this.idempotencyKey = this.newIdempotencyKey();
    void this.loadFreeBeds();
  }

  /**
   * All admission fields use the same label-above-control rhythm.  This is
   * deliberately a local form pattern instead of a second navigation shell:
   * it keeps long labels and large-font settings from stealing width from the
   * actual input control.
   */
  @Builder
  private stackedTextField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, required: boolean = false, numeric: boolean = false) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(this.controlHeight())
        .fontSize(16)
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
  private stackedTextAreaField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      TextArea({ text: value, placeholder: placeholder })
        .width('100%')
        .height(this.compactWidth ? 112 : 104)
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .onChange((next: string) => onChange(next))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stackedChoiceField(label: string, options: string[], selected: string,
    onSelect: (value: string) => void, required: boolean = false, optionWidth: number = 88) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(options, (option: string) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Text(option).fontSize(15)
              .textAlign(TextAlign.Center)
              .fontColor(selected === option ? Color.White : $r('sys.color.font_secondary'))
          }
          .width(optionWidth)
          .padding(0)
          .height(40)
          .margin({ right: optionWidth <= 72 ? 6 : 8, bottom: 8 })
          .borderRadius(10)
          .backgroundColor(selected === option ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_secondary'))
          .border({ width: selected === option ? 0 : 0.5, color: $r('sys.color.comp_divider') })
          .accessibilityText(`${label}${option}`)
          .accessibilitySelected(selected === option)
          .onClick(() => onSelect(option))
        }, (option: string) => `${label}-${option}`)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stackedDateRangeField(label: string, startPlaceholder: string, endPlaceholder: string,
    startValue: string, endValue: string, onStartChange: (value: string) => void,
    onEndChange: (value: string) => void, required: boolean = false) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 8 }) {
        TextInput({ text: startValue, placeholder: startPlaceholder })
          .layoutWeight(1)
          .height(this.controlHeight())
          .fontSize(15)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onStartChange(next))
        Text('至').fontSize(14).fontColor($r('sys.color.font_secondary'))
        TextInput({ text: endValue, placeholder: endPlaceholder })
          .layoutWeight(1)
          .height(this.controlHeight())
          .fontSize(15)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onEndChange(next))
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start)
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
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 0 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.minus')).fontSize(18)
            .fontColor([$r('sys.color.font_secondary')])
        }
          .width(44)
          .height(this.controlHeight())
          .padding(0)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topLeft: 10, bottomLeft: 10 })
          .accessibilityText(`减少${label}`)
          .onClick(() => this.adjustAmount(value, -100, onChange))
        TextInput({ text: value, placeholder: placeholder })
          .layoutWeight(1)
          .height(this.controlHeight())
          .fontSize(16)
          .type(InputType.Number)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(0)
          .border({ width: { top: 0.5, bottom: 0.5 }, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onChange(next))
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(18)
            .fontColor([$r('sys.color.font_secondary')])
        }
          .width(44)
          .height(this.controlHeight())
          .padding(0)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topRight: 10, bottomRight: 10 })
          .accessibilityText(`增加${label}`)
          .onClick(() => this.adjustAmount(value, 100, onChange))
      }
      .width('100%')
      .borderRadius(10)
      .clip(true)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 只允许选择服务端返回的空床位，避免提交无法占用的自由文本。 */
  @Builder
  private bedField() {
    Column({ space: 8 }) {
      Text('入住床位 *')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
        if (this.bedsLoading) {
          Row({ space: 8 }) {
            LoadingProgress().width(20).height(20)
            Text('正在加载空闲床位…').fontSize(14).fontColor($r('sys.color.font_tertiary'))
          }.width('100%').height(42).alignItems(VerticalAlign.Center)
        } else if (this.bedsError.length > 0) {
          Row({ space: 8 }) {
            Text(this.bedsError).fontSize(13).fontColor($r('app.color.doctor_workspace_danger')).layoutWeight(1)
            Button('重试', { type: ButtonType.Normal, stateEffect: true })
              .height(34).padding({ left: 12, right: 12 }).borderRadius(17)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .onClick(() => this.loadFreeBeds())
          }.width('100%').alignItems(VerticalAlign.Center)
        } else if (this.freeBeds.length === 0) {
          Text('暂无空闲床位，请先在床位管理中释放床位')
            .fontSize(14).fontColor($r('sys.color.font_tertiary')).height(42)
            .textAlign(TextAlign.Start)
        } else {
          Scroll() {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.freeBeds, (bed: Bed) => {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Text(this.bedLabel(bed)).fontSize(14)
                    .fontColor(this.bedId === bed.id ? Color.White : $r('sys.color.font_secondary'))
                }
                .height(42).padding({ left: 14, right: 14 }).margin({ right: 8, bottom: 8 })
                .borderRadius(10)
                .backgroundColor(this.bedId === bed.id ? $r('app.color.brand_blue') :
                  $r('sys.color.comp_background_secondary'))
                .border({ width: this.bedId === bed.id ? 0 : 0.5, color: $r('sys.color.comp_divider') })
                .accessibilityText(`选择床位${this.bedLabel(bed)}`)
                .accessibilitySelected(this.bedId === bed.id)
                .onClick(() => {
                  this.bedId = bed.id;
                  this.bedName = this.bedLabel(bed);
                })
              }, (bed: Bed) => `free-bed-${bed.id}`)
            }.width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: this.compactWidth ? 184 : 156 })
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private uploadField(label: string, description: string) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(22)
          .fontColor([$r('app.color.brand_blue')])
        Column({ space: 2 }) {
          Text('点击上传').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_blue'))
          Text(description).fontSize(12).fontColor($r('sys.color.font_tertiary'))
        }.alignItems(HorizontalAlign.Start)
      }
      // The upload card is a direct child of the field Column. A vertical
      // layoutWeight does not guarantee horizontal expansion, so fill the
      // grid cell explicitly to keep all three cards aligned.
      .width('100%')
      .height(72)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(10)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .onClick(() => this.showToast('照片上传功能待接入'))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** A wide field with the label above the control, avoiding compressed labels. */
  @Builder
  private familyStackedTextField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, numeric: boolean = false) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(this.controlHeight())
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .type(numeric ? InputType.Number : InputType.Normal)
        .onFocus(() => this.activeField = label)
        .onChange((next: string) => {
          onChange(next);
          this.activeField = label;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** Relationship choices share the same grid cell and remain one line wide. */
  @Builder
  private familyStackedRelationField() {
    Column({ space: 8 }) {
      Text('与长者关系')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 6 }) {
        ForEach(['子女', '配偶', '亲属', '其他'], (option: string) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Text(option)
              .fontSize(14)
              .textAlign(TextAlign.Center)
              .fontColor(this.familyRelation === option ? Color.White : $r('sys.color.font_secondary'))
          }
          // Share the available cell width so the relationship choices align
          // with the adjacent full-width fields instead of leaving a large
          // unexplained trailing gap on wide windows.
          .layoutWeight(1)
          .constraintSize({ minWidth: this.compactWidth ? 56 : 60 })
          .height(40)
          .padding(0)
          .borderRadius(10)
          .backgroundColor(this.familyRelation === option ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_secondary'))
          .border({ width: this.familyRelation === option ? 0 : 0.5,
            color: $r('sys.color.comp_divider') })
          .accessibilityText(`与长者关系${option}`)
          .accessibilitySelected(this.familyRelation === option)
          .onClick(() => this.familyRelation = option)
        }, (option: string) => `family-relation-${option}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private familyActions() {
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
      .accessibilityText('添加家属')
      .onClick(() => this.showToast('家属信息可继续添加'))
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.minus')).fontSize(16)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width(38)
      .height(38)
      .padding(0)
      .borderRadius(19)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .accessibilityText('删除家属')
      .onClick(() => this.showToast('当前至少保留一位联系人'))
    }
    .width(144)
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private familyGroupCard() {
    Column({ space: 0 }) {
      Row() {
        Text('家属信息')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        this.familyActions()
      }
      .width('100%')
      .height(58)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 16, right: 16 })
      Column({ space: 0 }) {
        this.familyFields()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 20 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private formContent() {
    Column({ space: 20 }) {
      AdmissionGroupCard({ title: '基本信息',
        content: (): void => { this.identityFields(); } });
      this.familyGroupCard();
      AdmissionGroupCard({ title: '入住配置',
        content: (): void => { this.arrangementFields(); } });
    }.width('100%')
  }

  @Builder
  private identityFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('姓名', '请输入长者姓名', this.name, (value: string) => this.name = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('身份证号', '请输入身份证号', this.idCard,
          (value: string) => this.idCard = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('出生日期', '请选择出生日期', this.birthDate,
          (value: string) => this.birthDate = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('年龄', '请输入年龄', this.age,
          (value: string) => this.age = value, true, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedChoiceField('性别', ['男', '女'], this.gender, (value: string) => this.gender = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('联系方式', '请输入手机号或其他联系方式', this.phone,
          (value: string) => this.phone = value, false, true)
      }
      GridCol({ span: 12 }) {
        this.stackedTextAreaField('家庭住址', '请输入家庭住址', this.familyAddress,
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
    if (this.compactWidth) {
      Column({ space: 12 }) {
        this.stackedTextField('家属姓名', '请输入主要联系人姓名', this.familyName,
          (value: string) => this.familyName = value)
        this.stackedTextField('家属联系方式', '请输入手机号或其他联系方式', this.familyPhone,
          (value: string) => this.familyPhone = value, false, true)
        this.stackedChoiceField('与长者关系', ['子女', '配偶', '亲属', '其他'], this.familyRelation,
          (value: string) => this.familyRelation = value, false, 72)
      }.width('100%')
    } else {
      GridRow({ columns: 12, gutter: { x: 18, y: 14 } }) {
        GridCol({ span: 4 }) {
          this.familyStackedTextField('家属姓名', '请输入主要联系人姓名', this.familyName,
            (value: string) => this.familyName = value)
        }
        GridCol({ span: 4 }) {
          this.familyStackedTextField('家属联系方式', '请输入手机号或其他联系方式', this.familyPhone,
            (value: string) => this.familyPhone = value, true)
        }
        GridCol({ span: 4 }) {
          this.familyStackedRelationField()
        }
      }.width('100%')
    }
  }

  @Builder
  private arrangementFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedDateRangeField('入住期限', '开始日期', '结束日期', this.admissionDate, this.admissionEndDate,
          (value: string) => this.admissionDate = value,
          (value: string) => this.admissionEndDate = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedDateRangeField('费用期限', '开始日期', '结束日期', this.feeStartDate, this.feeEndDate,
          (value: string) => this.feeStartDate = value,
          (value: string) => this.feeEndDate = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedChoiceField('护理等级', this.careLevelOptions, this.careLevel,
          (value: string) => this.careLevel = value, true)
      }
      GridCol({ span: 12 }) {
        this.bedField()
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('押金', '请输入金额', this.deposit, (value: string) => this.deposit = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('护理费用', '请输入金额', this.careFee, (value: string) => this.careFee = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('床位费用', '请输入金额', this.bedFee, (value: string) => this.bedFee = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('其他费用', '请输入金额', this.otherFee, (value: string) => this.otherFee = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('医保支付', '请输入金额', this.medicalInsurance,
          (value: string) => this.medicalInsurance = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('政府补贴', '请输入金额', this.subsidy, (value: string) => this.subsidy = value)
      }
      GridCol({ span: 12 }) {
        this.stackedTextAreaField('入住备注', '记录接待安排、饮食偏好或其他需要关注的事项', this.note,
          (value: string) => this.note = value)
      }
    }.width('100%')
  }

  @Builder
  private resultView() {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(52)
        .fontColor([$r('app.color.brand_blue')])
      Text('入住办理已完成').fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text('服务端已完成老人档案、床位和护理计划同步。')
        .fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      AdmissionGroupCard({ title: '填写完成', content: () => {
        HdsListItemCard({
          textItem: {
            primaryText: { text: this.resultPrimaryText() },
            secondaryText: { text: this.resultSecondaryText() }
          },
          suffixItem: new SuffixText({ text: '已完成' }),
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
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Button('取消').height(44).borderRadius(12).fontSize(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.onClose())
        Button(this.submitting ? '提交中…' : '确认办理入住').height(44).borderRadius(12).fontSize(14)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .opacity(this.requiredReady() && !this.submitting ? 1 : 0.45)
          .enabled(this.requiredReady() && !this.submitting)
          .onClick(() => this.confirmForm())
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      if (this.submitError.length > 0) {
        Text(this.submitError)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_danger'))
          .textAlign(TextAlign.End)
          .maxLines(2)
      }
    }
    .width('100%')
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
              // Keep the form close to the available canvas while retaining a
              // readable line length. The medium-window cap is intentionally
              // wider than the old 720vp value so tablet layouts do not leave
              // an unexplained empty band at either side.
              .constraintSize({ maxWidth: this.formMaxWidth() })
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
        title: { mainTitle: '办理入住' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
