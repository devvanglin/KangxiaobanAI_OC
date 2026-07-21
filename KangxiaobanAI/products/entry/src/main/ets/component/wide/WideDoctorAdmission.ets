// Copyright (c) 2026 Huawei Device Co., Ltd.
// Licensed under the Apache License, Version 2.0.

import { KeyCode } from '@kit.InputKit';

/** 入住办理步骤 */
interface AdmissionStep {
  id: string;
  label: string;
  desc: string;
  symbol: Resource;
}

/** 综合评估量表单项选项 */
interface AdmissionScaleOption {
  label: string;
  score: number;
  tone: string;
}

/** 综合评估量表 */
interface AdmissionScale {
  id: string;
  title: string;
  scaleName: string;
  description: string;
  options: AdmissionScaleOption[];
}

/** 照护套餐 */
interface AdmissionPackage {
  id: string;
  name: string;
  price: string;
  priceUnit: string;
  target: string;
  features: string[];
  tone: string;
}

/** 照护等级测算结果 */
interface CareLevelResult {
  label: string;
  tone: string;
  desc: string;
  recommendedPackageId: string;
}

@ComponentV2
export struct WideDoctorAdmission {
  @Param compactWidth: boolean = false;
  @Event onExit: () => void = () => {};

  // 流程状态
  @Local currentStep: number = 0;
  @Local submitted: boolean = false;
  @Local hoveredTarget: string = '';

  // 第 1 步：基础资料
  @Local residentName: string = '';
  @Local genderIndex: number = 0;
  @Local age: string = '';
  @Local idNumber: string = '';
  @Local room: string = '';
  @Local bed: string = '';
  @Local guardianName: string = '';
  @Local guardianPhone: string = '';
  @Local diagnosis: string = '';
  @Local allergies: string = '';
  @Local sourceIndex: number = 0;

  // 第 2 步：综合评估（与 scales 顺序对齐，取值为选项下标）
  @Local scaleChoice: number[] = [0, 0, 0, 0, 0, 0];

  // 第 3 步：套餐选择
  @Local selectedPackageId: string = '';

  private genderOptions: string[] = ['男', '女'];
  private sourceOptions: string[] = ['家庭送养', '医院转介', '社区转介', '机构调床'];

  private steps: AdmissionStep[] = [
    { id: 'basic', label: '核验基础资料', desc: '身份、床位与联系人', symbol: $r('sys.symbol.person_crop_circle_fill') },
    { id: 'assess', label: '老年综合评估', desc: 'ADL / 认知 / 营养 / 风险', symbol: $r('sys.symbol.waveform_path_ecg_magnifyingglass') },
    { id: 'plan', label: '选择照护套餐', desc: '按测算等级匹配服务', symbol: $r('sys.symbol.doc_text') },
    { id: 'confirm', label: '确认并建档', desc: '生成入住档案草稿', symbol: $r('sys.symbol.checkmark_circle_fill') }
  ];

  private scales: AdmissionScale[] = [
    {
      id: 'adl',
      title: '日常生活活动能力',
      scaleName: 'Barthel 指数（ADL）',
      description: '评估进食、洗漱、如厕、转移、行走等自理程度',
      options: [
        { label: '完全自理', score: 0, tone: 'normal' },
        { label: '轻度依赖', score: 1, tone: 'warning' },
        { label: '中度依赖', score: 2, tone: 'warning' },
        { label: '重度依赖', score: 3, tone: 'danger' },
        { label: '完全依赖', score: 4, tone: 'danger' }
      ]
    },
    {
      id: 'cognition',
      title: '认知功能',
      scaleName: '简易智能状态（MMSE）',
      description: '评估定向、记忆、注意与语言等认知表现',
      options: [
        { label: '正常', score: 0, tone: 'normal' },
        { label: '轻度受损', score: 1, tone: 'warning' },
        { label: '中度受损', score: 2, tone: 'warning' },
        { label: '重度受损', score: 3, tone: 'danger' }
      ]
    },
    {
      id: 'nutrition',
      title: '营养状态',
      scaleName: '微型营养评定（MNA）',
      description: '评估近期体重、进食量与营养摄入风险',
      options: [
        { label: '营养正常', score: 0, tone: 'normal' },
        { label: '营养不良风险', score: 1, tone: 'warning' },
        { label: '营养不良', score: 2, tone: 'danger' }
      ]
    },
    {
      id: 'fall',
      title: '跌倒风险',
      scaleName: 'Morse 跌倒评估',
      description: '结合跌倒史、步态、辅助与用药评估跌倒风险',
      options: [
        { label: '低风险', score: 0, tone: 'normal' },
        { label: '中风险', score: 1, tone: 'warning' },
        { label: '高风险', score: 2, tone: 'danger' }
      ]
    },
    {
      id: 'pressure',
      title: '压疮风险',
      scaleName: 'Braden 压疮评估',
      description: '结合活动、移动、感知与皮肤状况评估压疮风险',
      options: [
        { label: '低风险', score: 0, tone: 'normal' },
        { label: '中风险', score: 1, tone: 'warning' },
        { label: '高风险', score: 2, tone: 'danger' }
      ]
    },
    {
      id: 'mood',
      title: '情绪状态',
      scaleName: '老年抑郁量表（GDS）',
      description: '评估情绪低落、兴趣减退与睡眠等情绪表现',
      options: [
        { label: '情绪平稳', score: 0, tone: 'normal' },
        { label: '轻度低落', score: 1, tone: 'warning' },
        { label: '中重度低落', score: 2, tone: 'danger' }
      ]
    }
  ];

  private packages: AdmissionPackage[] = [
    {
      id: 'basic',
      name: '基础版',
      price: '20–40',
      priceUnit: '元 / 床 · 月',
      target: '适合自理及轻度依赖长者',
      tone: 'normal',
      features: [
        '长者电子档案与联系人管理',
        '日常养护任务与交接班',
        '基础告警与巡查记录',
        '护工端与管理端基础报表'
      ]
    },
    {
      id: 'pro',
      name: '专业版',
      price: '60–100',
      priceUnit: '元 / 床 · 月',
      target: '适合中重度依赖或多风险长者',
      tone: 'warning',
      features: [
        '包含基础版全部能力',
        '老年综合评估与个人养护计划',
        '用药安全与智能设备接入',
        '风险闭环、家属周报与 AI 养护助手'
      ]
    },
    {
      id: 'group',
      name: '集团版',
      price: '项目制',
      priceUnit: '按机构与床位报价',
      target: '适合连锁 / 多机构集团客户',
      tone: 'focus',
      features: [
        '包含专业版全部能力',
        '多机构管理与集团数据驾驶舱',
        '私有化部署与单点登录',
        '定制监管报表与知识库管理'
      ]
    }
  ];

  private toneColor(tone: string): ResourceColor {
    if (tone === 'danger') {
      return $r('app.color.doctor_workspace_danger');
    }
    if (tone === 'warning') {
      return $r('app.color.doctor_workspace_warning');
    }
    if (tone === 'normal') {
      return $r('app.color.doctor_workspace_success');
    }
    if (tone === 'focus') {
      return $r('app.color.doctor_workspace_focus');
    }
    return $r('app.color.doctor_workspace_text_secondary');
  }

  private mainPadding(): number {
    return this.compactWidth ? 20 : 24;
  }

  private activateWithKeyboard(event: KeyEvent, action: () => void): void {
    if (event.type === KeyType.Down &&
      (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_SPACE)) {
      action();
    }
  }

  /** 汇总评估中的风险计数 */
  private riskScore(): number {
    let total: number = 0;
    for (let i = 0; i < this.scales.length; i++) {
      const option: AdmissionScaleOption = this.scales[i].options[this.scaleChoice[i]];
      total += option.score;
    }
    return total;
  }

  /** 根据评估结果测算照护等级与推荐套餐 */
  private careLevelResult(): CareLevelResult {
    let dangerCount: number = 0;
    for (let i = 0; i < this.scales.length; i++) {
      if (this.scales[i].options[this.scaleChoice[i]].tone === 'danger') {
        dangerCount++;
      }
    }
    const score: number = this.riskScore();
    if (dangerCount >= 2 || score >= 9) {
      return {
        label: '专业照护 · 高关注',
        tone: 'danger',
        desc: '存在多项高风险，建议专业团队介入并加密巡查',
        recommendedPackageId: 'pro'
      };
    }
    if (dangerCount >= 1 || score >= 4) {
      return {
        label: '协助照护 · 中关注',
        tone: 'warning',
        desc: '存在中度依赖或单项高风险，建议专业版养护计划',
        recommendedPackageId: 'pro'
      };
    }
    return {
      label: '基础照护 · 低关注',
      tone: 'normal',
      desc: '总体自理程度较好，基础版即可覆盖日常养护',
      recommendedPackageId: 'basic'
    };
  }

  private effectivePackageId(): string {
    return this.selectedPackageId.length > 0 ?
      this.selectedPackageId : this.careLevelResult().recommendedPackageId;
  }

  private packageById(id: string): AdmissionPackage {
    return this.packages.find((item: AdmissionPackage) => item.id === id) ?? this.packages[0];
  }

  private basicInfoReady(): boolean {
    return this.residentName.trim().length > 0 &&
      this.age.trim().length > 0 &&
      this.room.trim().length > 0 &&
      this.bed.trim().length > 0 &&
      this.guardianPhone.trim().length > 0;
  }

  private canProceed(): boolean {
    if (this.currentStep === 0) {
      return this.basicInfoReady();
    }
    return true;
  }

  private goNext(): void {
    if (this.currentStep < this.steps.length - 1 && this.canProceed()) {
      this.currentStep += 1;
      return;
    }
    if (this.currentStep === this.steps.length - 1) {
      this.submitted = true;
    }
  }

  private goPrev(): void {
    if (this.submitted) {
      this.submitted = false;
      return;
    }
    if (this.currentStep > 0) {
      this.currentStep -= 1;
    }
  }

  private resetFlow(): void {
    this.submitted = false;
    this.currentStep = 0;
    this.residentName = '';
    this.genderIndex = 0;
    this.age = '';
    this.idNumber = '';
    this.room = '';
    this.bed = '';
    this.guardianName = '';
    this.guardianPhone = '';
    this.diagnosis = '';
    this.allergies = '';
    this.sourceIndex = 0;
    this.scaleChoice = [0, 0, 0, 0, 0, 0];
    this.selectedPackageId = '';
  }

  // ==================== 头部与步骤条 ====================

  @Builder
  private header() {
    Row() {
      Column({ space: 4 }) {
        Text('新长者入住办理')
          .fontSize(this.compactWidth ? 24 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text('核验资料、完成老年综合评估并匹配照护套餐，生成入住档案草稿')
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(13)
          .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
        Text('本地演示数据 · 建档结果需医师确认')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(10)
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private stepRail() {
    Column({ space: 6 }) {
      ForEach(this.steps, (step: AdmissionStep, index: number) => {
        Row({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(34)
              .height(34)
              .borderRadius(17)
              .backgroundColor(index <= this.currentStep ?
                $r('app.color.doctor_workspace_text_primary') :
                $r('app.color.doctor_workspace_surface_raised'))
              .border({
                width: 0.5,
                color: index <= this.currentStep ?
                  $r('app.color.doctor_workspace_text_primary') :
                  $r('app.color.doctor_workspace_border')
              })
            if (index < this.currentStep) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(15)
                .fontColor([$r('app.color.doctor_workspace_background')])
            } else {
              Text(`${index + 1}`)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(index === this.currentStep ?
                  $r('app.color.doctor_workspace_background') :
                  $r('app.color.doctor_workspace_text_tertiary'))
            }
          }
          Column({ space: 2 }) {
            Text(step.label)
              .fontSize(13)
              .fontWeight(index === this.currentStep ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(index === this.currentStep ?
                $r('app.color.doctor_workspace_text_primary') :
                $r('app.color.doctor_workspace_text_secondary'))
              .maxLines(1)
            Text(step.desc)
              .fontSize(10)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(56)
        .padding({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor(index === this.currentStep ?
          $r('app.color.doctor_workspace_surface_raised') : Color.Transparent)
        .alignItems(VerticalAlign.Center)
      }, (step: AdmissionStep) => step.id)
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 通用输入控件 ====================

  @Builder
  private fieldLabel(label: string, required: boolean) {
    Row({ space: 3 }) {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
      if (required) {
        Text('*')
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_danger'))
      }
    }
    .margin({ bottom: 6 })
  }

  @Builder
  private textField(placeholder: string, value: string, onChange: (v: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .width('100%')
      .height(42)
      .fontSize(13)
      .fontColor($r('app.color.doctor_workspace_text_primary'))
      .placeholderColor($r('app.color.doctor_workspace_text_tertiary'))
      .placeholderFont({ size: 13 })
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      .borderRadius(10)
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .padding({ left: 12, right: 12 })
      .onChange(onChange)
  }

  @Builder
  private capsuleGroup(options: string[], selected: number, onSelect: (index: number) => void) {
    Row({ space: 6 }) {
      ForEach(options, (option: string, index: number) => {
        Text(option)
          .fontSize(12)
          .fontWeight(selected === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(selected === index ?
            $r('app.color.doctor_workspace_background') :
            $r('app.color.doctor_workspace_text_secondary'))
          .height(38)
          .padding({ left: 16, right: 16 })
          .textAlign(TextAlign.Center)
          .borderRadius(10)
          .backgroundColor(selected === index ?
            $r('app.color.doctor_workspace_text_primary') :
            $r('app.color.doctor_workspace_surface_raised'))
          .border({
            width: 0.5,
            color: selected === index ?
              $r('app.color.doctor_workspace_text_primary') :
              $r('app.color.doctor_workspace_border')
          })
          .focusable(true)
          .focusOnTouch(true)
          .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => onSelect(index)))
          .onClick(() => onSelect(index))
      }, (option: string, index: number) => `${option}-${index}`)
    }
  }

  @Builder
  private sectionCard(title: string, subtitle: string) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(subtitle)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 14 })
  }

  // ==================== 第 1 步：基础资料 ====================

  @Builder
  private stepBasicInfo() {
    Column() {
      this.sectionCard('核验基础资料', '确认身份、床位安排、联系人与病史过敏信息')
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('长者姓名', true)
            this.textField('请输入姓名', this.residentName, (v: string) => this.residentName = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('性别', false)
            this.capsuleGroup(this.genderOptions, this.genderIndex, (index: number) => this.genderIndex = index)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 6 : 3 }) {
          Column() {
            this.fieldLabel('年龄', true)
            this.textField('岁', this.age, (v: string) => this.age = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 6 : 3 }) {
          Column() {
            this.fieldLabel('证件号', false)
            this.textField('身份证号', this.idNumber, (v: string) => this.idNumber = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 6 : 3 }) {
          Column() {
            this.fieldLabel('房间', true)
            this.textField('如 3A', this.room, (v: string) => this.room = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 6 : 3 }) {
          Column() {
            this.fieldLabel('床位', true)
            this.textField('如 12', this.bed, (v: string) => this.bed = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('紧急联系人', false)
            this.textField('联系人姓名与关系', this.guardianName, (v: string) => this.guardianName = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('联系电话', true)
            this.textField('联系人手机号', this.guardianPhone, (v: string) => this.guardianPhone = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: 12 }) {
          Column() {
            this.fieldLabel('入住来源', false)
            this.capsuleGroup(this.sourceOptions, this.sourceIndex, (index: number) => this.sourceIndex = index)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('主要诊断', false)
            this.textField('如 高血压、2 型糖尿病', this.diagnosis, (v: string) => this.diagnosis = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('过敏史', false)
            this.textField('如青霉素，无则留空', this.allergies, (v: string) => this.allergies = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      if (!this.basicInfoReady()) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(12)
            .fontColor([$r('app.color.doctor_workspace_warning')])
          Text('姓名、年龄、房间、床位与联系电话为必填项')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_warning'))
        }
        .width('100%')
        .margin({ top: 14 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 第 2 步：综合评估 ====================

  @Builder
  private assessmentCard(scale: AdmissionScale, scaleIndex: number) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(scale.title)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Text(scale.scaleName)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(scale.options[this.scaleChoice[scaleIndex]].label)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.toneColor(scale.options[this.scaleChoice[scaleIndex]].tone))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: this.toneColor(scale.options[this.scaleChoice[scaleIndex]].tone) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(scale.description)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
        .lineHeight(17)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(scale.options, (option: AdmissionScaleOption, optionIndex: number) => {
          Text(option.label)
            .fontSize(12)
            .fontWeight(this.scaleChoice[scaleIndex] === optionIndex ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.scaleChoice[scaleIndex] === optionIndex ?
              $r('app.color.doctor_workspace_background') :
              $r('app.color.doctor_workspace_text_secondary'))
            .height(36)
            .padding({ left: 14, right: 14 })
            .margin({ right: 8, bottom: 8 })
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.scaleChoice[scaleIndex] === optionIndex ?
              this.toneColor(option.tone) :
              $r('app.color.doctor_workspace_surface_raised'))
            .border({
              width: 0.5,
              color: this.scaleChoice[scaleIndex] === optionIndex ?
                this.toneColor(option.tone) :
                $r('app.color.doctor_workspace_border')
            })
            .focusable(true)
            .focusOnTouch(true)
            .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
              const next: number[] = this.scaleChoice.slice();
              next[scaleIndex] = optionIndex;
              this.scaleChoice = next;
            }))
            .onClick(() => {
              const next: number[] = this.scaleChoice.slice();
              next[scaleIndex] = optionIndex;
              this.scaleChoice = next;
            })
        }, (option: AdmissionScaleOption, optionIndex: number) => `${scale.id}-${optionIndex}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(14)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private careLevelBanner() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.waveform_path_ecg_magnifyingglass'))
          .fontSize(18)
          .fontColor([this.toneColor(this.careLevelResult().tone)])
        Text('照护等级测算')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
          .layoutWeight(1)
        Text(this.careLevelResult().label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.toneColor(this.careLevelResult().tone))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(9)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: this.toneColor(this.careLevelResult().tone) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.careLevelResult().desc)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
        .lineHeight(18)
      Text('测算依据本地评估选项汇总，仅供参考，最终等级由养老医师确认。')
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(14)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: this.toneColor(this.careLevelResult().tone) })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepAssessment() {
    Column() {
      this.sectionCard('老年综合评估', '逐项选择评估结果，系统实时测算照护等级')
      this.careLevelBanner()
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        ForEach(this.scales, (scale: AdmissionScale, index: number) => {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.assessmentCard(scale, index)
          }
        }, (scale: AdmissionScale) => scale.id)
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 第 3 步：套餐选择 ====================

  @Builder
  private packageCard(item: AdmissionPackage) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(item.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            if (this.careLevelResult().recommendedPackageId === item.id) {
              Text('推荐')
                .fontSize(9)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.doctor_workspace_background'))
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .borderRadius(7)
                .backgroundColor(this.toneColor('focus'))
            }
          }
          Text(item.target)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(22)
            .height(22)
            .borderRadius(11)
            .border({
              width: this.effectivePackageId() === item.id ? 7 : 1.5,
              color: this.effectivePackageId() === item.id ?
                this.toneColor('focus') : $r('app.color.doctor_workspace_border')
            })
        }
        .width(22)
        .height(22)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      Row({ space: 4 }) {
        Text(item.price)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text(item.priceUnit)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .margin({ bottom: 4 })
      }
      .alignItems(VerticalAlign.Bottom)
      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.doctor_workspace_border_soft'))
      Column({ space: 8 }) {
        ForEach(item.features, (feature: string) => {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(12)
              .fontColor([this.toneColor('normal')])
            Text(feature)
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
              .layoutWeight(1)
              .lineHeight(17)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (feature: string) => feature)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({
      width: this.effectivePackageId() === item.id ? 1.5 : 0.5,
      color: this.effectivePackageId() === item.id ?
        this.toneColor('focus') : $r('app.color.doctor_workspace_border')
    })
    .alignItems(HorizontalAlign.Start)
    .focusable(true)
    .focusOnTouch(true)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => this.selectedPackageId = item.id))
    .onClick(() => this.selectedPackageId = item.id)
  }

  @Builder
  private stepPackage() {
    Column() {
      this.sectionCard('选择照护套餐', '系统按测算等级推荐套餐，可按机构策略调整')
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        ForEach(this.packages, (item: AdmissionPackage) => {
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.packageCard(item)
          }
        }, (item: AdmissionPackage) => item.id)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 第 4 步：确认 ====================

  @Builder
  private summaryRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width(96)
      Text(value.length > 0 ? value : '—')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .border({
      width: { bottom: 0.5 },
      color: { bottom: $r('app.color.doctor_workspace_border_soft') }
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private assessmentSummary() {
    Column({ space: 0 }) {
      ForEach(this.scales, (scale: AdmissionScale, index: number) => {
        Row({ space: 12 }) {
          Text(scale.title)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .layoutWeight(1)
          Text(scale.options[this.scaleChoice[index]].label)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.toneColor(scale.options[this.scaleChoice[index]].tone))
        }
        .width('100%')
        .padding({ top: 7, bottom: 7 })
        .border({
          width: { bottom: 0.5 },
          color: { bottom: $r('app.color.doctor_workspace_border_soft') }
        })
      }, (scale: AdmissionScale) => `sum-${scale.id}`)
    }
    .width('100%')
  }

  @Builder
  private stepConfirm() {
    Column() {
      this.sectionCard('确认并建档', '核对全部信息后生成入住档案草稿')
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column({ space: 12 }) {
            Text('基础资料')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width('100%')
            this.summaryRow('姓名', this.residentName)
            this.summaryRow('性别 / 年龄',
              `${this.genderOptions[this.genderIndex]} · ${this.age.length > 0 ? this.age + ' 岁' : '—'}`)
            this.summaryRow('房间 / 床位', `${this.room}-${this.bed}`)
            this.summaryRow('联系人', this.guardianName)
            this.summaryRow('联系电话', this.guardianPhone)
            this.summaryRow('入住来源', this.sourceOptions[this.sourceIndex])
            this.summaryRow('主要诊断', this.diagnosis)
            this.summaryRow('过敏史', this.allergies)
          }
          .width('100%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor($r('app.color.doctor_workspace_surface'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column({ space: 16 }) {
            Column({ space: 12 }) {
              Row() {
                Text('综合评估结论')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                  .layoutWeight(1)
                Text(this.careLevelResult().label)
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.toneColor(this.careLevelResult().tone))
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
                  .border({ width: 0.5, color: this.toneColor(this.careLevelResult().tone) })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              this.assessmentSummary()
            }
            .width('100%')
            .padding(18)
            .borderRadius(16)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            .alignItems(HorizontalAlign.Start)
            Column({ space: 10 }) {
              Text('照护套餐')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
                .width('100%')
              Row({ space: 8 }) {
                Text(this.packageById(this.effectivePackageId()).name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                Text(`${this.packageById(this.effectivePackageId()).price} ${this.packageById(this.effectivePackageId()).priceUnit}`)
                  .fontSize(11)
                  .fontColor($r('app.color.doctor_workspace_text_secondary'))
                Blank()
                  .layoutWeight(1)
                if (this.selectedPackageId.length === 0) {
                  Text('系统推荐')
                    .fontSize(9)
                    .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(18)
            .borderRadius(16)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 提交成功态 ====================

  @Builder
  private submittedView() {
    Column({ space: 16 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(40)
          .fontColor([this.toneColor('normal')])
      }
      Text('入住档案草稿已生成')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(`${this.residentName.length > 0 ? this.residentName : '新长者'} · ${this.room}-${this.bed} · ${this.careLevelResult().label}`)
        .fontSize(12)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
      Text('草稿已进入待确认列表，需养老医师复核评估并正式建档后生效。')
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 420 })
      Row({ space: 12 }) {
        Button('再办理一位')
          .height(42)
          .padding({ left: 20, right: 20 })
          .borderRadius(12)
          .fontSize(13)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .onClick(() => this.resetFlow())
        Button('返回工作台')
          .height(42)
          .padding({ left: 20, right: 20 })
          .borderRadius(12)
          .fontSize(13)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .onClick(() => {
            this.resetFlow();
            this.onExit();
          })
      }
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(this.mainPadding())
  }

  // ==================== 底部操作栏 ====================

  @Builder
  private footerBar() {
    Row({ space: 12 }) {
      Text(`第 ${this.currentStep + 1} / ${this.steps.length} 步 · ${this.steps[this.currentStep].label}`)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .layoutWeight(1)
      if (this.currentStep > 0) {
        Button('上一步')
          .height(40)
          .padding({ left: 18, right: 18 })
          .borderRadius(11)
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .onClick(() => this.goPrev())
      }
      Button(this.currentStep === this.steps.length - 1 ? '确认建档' : '下一步')
        .height(40)
        .padding({ left: 22, right: 22 })
        .borderRadius(11)
        .fontSize(12)
        .fontColor($r('app.color.doctor_workspace_background'))
        .backgroundColor($r('app.color.doctor_workspace_text_primary'))
        .enabled(this.canProceed())
        .opacity(this.canProceed() ? 1 : 0.42)
        .onClick(() => this.goNext())
    }
    .width('100%')
    .constraintSize({ maxWidth: 1200 })
    .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private stepContent() {
    if (this.currentStep === 0) {
      this.stepBasicInfo()
    } else if (this.currentStep === 1) {
      this.stepAssessment()
    } else if (this.currentStep === 2) {
      this.stepPackage()
    } else {
      this.stepConfirm()
    }
  }

  build() {
    Column() {
      if (this.submitted) {
        this.submittedView()
      } else {
        Scroll() {
          Column({ space: 18 }) {
            this.header()
            GridRow({ columns: 12, gutter: { x: 18, y: 18 } }) {
              GridCol({ span: this.compactWidth ? 12 : 3 }) {
                this.stepRail()
              }
              GridCol({ span: this.compactWidth ? 12 : 9 }) {
                this.stepContent()
              }
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxWidth: 1200 })
          .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 24, bottom: 24 })
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        Column() {
          this.footerBar()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.doctor_workspace_background'))
        .border({
          width: { top: 0.5 },
          color: { top: $r('app.color.doctor_workspace_border_soft') }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.doctor_workspace_background'))
  }
}
