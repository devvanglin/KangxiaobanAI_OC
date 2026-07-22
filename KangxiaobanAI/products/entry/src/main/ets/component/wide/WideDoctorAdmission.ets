// Copyright (c) 2026 Huawei Device Co., Ltd.
// Licensed under the Apache License, Version 2.0.

import { LengthMetrics } from '@kit.ArkUI';
import { KeyCode } from '@kit.InputKit';

/** 入住办理步骤 */
interface AdmissionStep {
  id: string;
  label: string;
  desc: string;
  symbol: Resource;
}

/** 入住初筛单项选项 */
interface AdmissionAssessmentOption {
  label: string;
  score: number;
  tone: string;
}

/** 入住初筛维度 */
interface AdmissionAssessmentDimension {
  id: string;
  title: string;
  basis: string;
  description: string;
  options: AdmissionAssessmentOption[];
}

/** 入住服务安全风险 */
interface AdmissionSafetyRisk {
  id: string;
  title: string;
  description: string;
}

/** 入住照护计划 */
interface AdmissionCarePlan {
  id: string;
  name: string;
  target: string;
  baseServices: string[];
  optionalServices: string[];
  tone: string;
}

/** 入住初筛生成的照护计划建议 */
interface CarePlanSuggestion {
  label: string;
  tone: string;
  desc: string;
  recommendedPlanId: string;
}

@ComponentV2
export struct WideDoctorAdmission {
  @Param compactWidth: boolean = false;
  @Param naviIndicatorHeight: number = 0;
  @Event onExit: () => void = () => {};
  @Event onDirtyChange: (dirty: boolean) => void = (_dirty: boolean) => {};

  // 流程状态
  @Local currentStep: number = 0;
  @Local submitted: boolean = false;
  @Local dirty: boolean = false;

  // 第 1 步：基础资料
  @Local residentName: string = '';
  @Local genderIndex: number = -1;
  @Local age: string = '';
  @Local idNumber: string = '';
  @Local room: string = '';
  @Local bed: string = '';
  @Local guardianName: string = '';
  @Local guardianPhone: string = '';
  @Local diagnosis: string = '';
  @Local allergies: string = '';
  @Local sourceIndex: number = -1;

  // 第 2 步：入住初筛（与维度、风险顺序对齐，-1 表示尚未评估）
  @Local assessmentChoice: number[] = [-1, -1, -1, -1, -1, -1];
  @Local safetyRiskChoice: number[] = [-1, -1, -1, -1, -1, -1, -1, -1, -1];
  @Local safetyRiskMeasures: string[] = ['', '', '', '', '', '', '', '', ''];
  @Local safetyRiskOwners: string[] = ['', '', '', '', '', '', '', '', ''];
  @Local safetyRiskReviewPoints: string[] = ['', '', '', '', '', '', '', '', ''];
  @Local safetyRiskEscalations: string[] = ['', '', '', '', '', '', '', '', ''];

  // 第 3 步：照护计划选择
  @Local selectedPlanId: string = '';

  // 第 4 步：人工确认与告知
  @Local doctorConfirmed: boolean = false;
  @Local planConsentConfirmed: boolean = false;
  @Local serviceFeeInformed: boolean = false;

  private contentScroller: Scroller = new Scroller();

  private genderOptions: string[] = ['男', '女'];
  private sourceOptions: string[] = ['家庭送养', '医院转介', '社区转介', '机构调床'];

  private steps: AdmissionStep[] = [
    { id: 'basic', label: '核验基础资料', desc: '身份、床位与联系人', symbol: $r('sys.symbol.person_crop_circle_fill') },
    { id: 'assess', label: '完成入住初筛', desc: '能力、健康与九类安全风险', symbol: $r('sys.symbol.waveform_path_ecg_magnifyingglass') },
    { id: 'plan', label: '选择照护计划', desc: '明确基础服务与可选项目', symbol: $r('sys.symbol.doc_text') },
    { id: 'confirm', label: '确认并生成草稿', desc: '完成复核、同意与费用告知', symbol: $r('sys.symbol.checkmark_circle_fill') }
  ];

  private assessments: AdmissionAssessmentDimension[] = [
    {
      id: 'self-care',
      title: '自理能力',
      basis: 'GB/T 42195 一级指标 · 入住初筛',
      description: '观察进食、修饰、穿衣、如厕、洗澡等日常生活活动表现',
      options: [
        { label: '能力完好表现', score: 0, tone: 'normal' },
        { label: '轻度受损表现', score: 1, tone: 'warning' },
        { label: '中度受损表现', score: 2, tone: 'warning' },
        { label: '重度受损表现', score: 3, tone: 'danger' },
        { label: '完全丧失表现', score: 4, tone: 'danger' }
      ]
    },
    {
      id: 'mobility',
      title: '基础运动能力',
      basis: 'GB/T 42195 一级指标 · 入住初筛',
      description: '观察翻身、坐位、站立、床椅转移、步行与上下楼梯表现',
      options: [
        { label: '能力完好表现', score: 0, tone: 'normal' },
        { label: '轻度受损表现', score: 1, tone: 'warning' },
        { label: '中度受损表现', score: 2, tone: 'warning' },
        { label: '重度受损表现', score: 3, tone: 'danger' },
        { label: '完全丧失表现', score: 4, tone: 'danger' }
      ]
    },
    {
      id: 'mental',
      title: '精神状态',
      basis: 'GB/T 42195 一级指标 · 入住初筛',
      description: '观察认知、行为、情绪以及近期明显变化，由专业人员继续核验',
      options: [
        { label: '能力完好表现', score: 0, tone: 'normal' },
        { label: '轻度受损表现', score: 1, tone: 'warning' },
        { label: '中度受损表现', score: 2, tone: 'warning' },
        { label: '重度受损表现', score: 3, tone: 'danger' },
        { label: '完全丧失表现', score: 4, tone: 'danger' }
      ]
    },
    {
      id: 'perception-social',
      title: '感知觉与社会参与',
      basis: 'GB/T 42195 一级指标 · 入住初筛',
      description: '观察视听觉、沟通、定向、社会交往及参与活动的表现',
      options: [
        { label: '能力完好表现', score: 0, tone: 'normal' },
        { label: '轻度受损表现', score: 1, tone: 'warning' },
        { label: '中度受损表现', score: 2, tone: 'warning' },
        { label: '重度受损表现', score: 3, tone: 'danger' },
        { label: '完全丧失表现', score: 4, tone: 'danger' }
      ]
    },
    {
      id: 'nutrition-swallowing',
      title: '营养与吞咽支持',
      basis: '入住健康初筛 · 不替代营养或吞咽专科评估',
      description: '核对近期体重和进食变化、食物性状、饮水与吞咽异常表现',
      options: [
        { label: '暂未见异常', score: 0, tone: 'normal' },
        { label: '需要持续观察', score: 1, tone: 'warning' },
        { label: '需要专业评估', score: 2, tone: 'danger' }
      ]
    },
    {
      id: 'health-medication',
      title: '慢病与用药支持',
      basis: '入住健康初筛 · 需结合病历与医嘱复核',
      description: '核对慢病稳定性、近期就医、用药种类、服药能力与不良反应',
      options: [
        { label: '稳定且可自管', score: 0, tone: 'normal' },
        { label: '需要用药协助', score: 1, tone: 'warning' },
        { label: '需要重点管理', score: 2, tone: 'danger' }
      ]
    }
  ];

  private safetyRisks: AdmissionSafetyRisk[] = [
    { id: 'choking', title: '噎食', description: '吞咽、进食速度、食物性状与进食照护' },
    { id: 'mistaken-intake', title: '食品药品误食', description: '认知、药品保管、饮食禁忌与物品标识' },
    { id: 'pressure-injury', title: '压疮', description: '皮肤、营养、活动和体位变换能力' },
    { id: 'scald', title: '烫伤', description: '温度感知、热源接触与洗浴饮水支持' },
    { id: 'bed-fall', title: '坠床', description: '睡眠行为、床上活动与防护设施适配' },
    { id: 'fall', title: '跌倒', description: '跌倒史、步态、辅助器具、环境与相关用药' },
    { id: 'harm', title: '他伤和自伤', description: '情绪行为、冲动风险、冲突与保护因素' },
    { id: 'wandering', title: '走失', description: '定向、记忆、外出行为与身份识别措施' },
    { id: 'activity-accident', title: '文娱活动意外', description: '活动能力、禁忌、器材环境与陪同需求' }
  ];

  private safetyRiskOptions: AdmissionAssessmentOption[] = [
    { label: '未见明显风险', score: 0, tone: 'normal' },
    { label: '需预防措施', score: 1, tone: 'warning' },
    { label: '高风险', score: 2, tone: 'danger' }
  ];

  private pendingOption: AdmissionAssessmentOption = {
    label: '未评估',
    score: 0,
    tone: 'pending'
  };

  private plans: AdmissionCarePlan[] = [
    {
      id: 'self-support',
      name: '自理支持计划',
      target: '适合初筛显示生活能力较完整、以保持独立生活为目标的长者',
      tone: 'normal',
      baseServices: [
        '床位与住宿｜适老居室、床位及公共设施使用',
        '照料护理｜环境整理、日常巡查与必要生活提醒',
        '膳食｜机构基础适老膳食与饮水支持'
      ],
      optionalServices: [
        '康复训练｜基础体能和集体活动',
        '认知支持｜益智活动和社会参与',
        '营养管理｜营养筛查和膳食建议',
        '用药协助｜服药提醒与记录',
        '智能安全监测｜紧急呼叫、门磁等按需配置'
      ]
    },
    {
      id: 'assisted-care',
      name: '协助照护计划',
      target: '适合部分生活活动需要协助，或存在一项重点安全风险的长者',
      tone: 'warning',
      baseServices: [
        '床位与住宿｜按行动能力适配居室位置和辅助设施',
        '照料护理｜起居、清洁、如厕和转移等分项协助',
        '膳食｜适老膳食、进食观察与特殊需求登记'
      ],
      optionalServices: [
        '康复训练｜个体功能维持训练',
        '认知支持｜定向训练和结构化活动',
        '营养管理｜摄入追踪和个体膳食方案',
        '用药协助｜核对、提醒、观察与异常反馈',
        '智能安全监测｜离床、跌倒和定位等按风险配置'
      ]
    },
    {
      id: 'continuous-care',
      name: '全程照护计划',
      target: '适合多项能力明显受损、需要连续协助或多风险联合干预的长者',
      tone: 'danger',
      baseServices: [
        '床位与住宿｜优先适配照护动线、无障碍和安全防护',
        '照料护理｜进食、清洁、排泄、转移等全程分级支持',
        '膳食｜按吞咽、营养和疾病需求落实个体方案'
      ],
      optionalServices: [
        '康复训练｜床旁或个体功能维持训练',
        '认知支持｜失智友好照护和行为支持',
        '营养管理｜持续摄入、体重和营养风险跟踪',
        '用药协助｜全流程核对、执行记录与异常上报',
        '智能安全监测｜离床、生命体征和定位等联合监测'
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
      event.stopPropagation();
      action();
    }
  }

  private assessmentOption(dimensionIndex: number): AdmissionAssessmentOption {
    const optionIndex: number = this.assessmentChoice[dimensionIndex];
    if (optionIndex < 0 || optionIndex >= this.assessments[dimensionIndex].options.length) {
      return this.pendingOption;
    }
    return this.assessments[dimensionIndex].options[optionIndex];
  }

  private safetyOption(riskIndex: number): AdmissionAssessmentOption {
    const optionIndex: number = this.safetyRiskChoice[riskIndex];
    if (optionIndex < 0 || optionIndex >= this.safetyRiskOptions.length) {
      return this.pendingOption;
    }
    return this.safetyRiskOptions[optionIndex];
  }

  private assessmentReady(): boolean {
    for (let i: number = 0; i < this.assessmentChoice.length; i++) {
      if (this.assessmentChoice[i] < 0) {
        return false;
      }
    }
    for (let i: number = 0; i < this.safetyRiskChoice.length; i++) {
      if (!this.safetyRiskReady(i)) {
        return false;
      }
    }
    return true;
  }

  private completedAssessmentCount(): number {
    let completed: number = 0;
    for (let i: number = 0; i < this.assessmentChoice.length; i++) {
      if (this.assessmentChoice[i] >= 0) {
        completed++;
      }
    }
    for (let i: number = 0; i < this.safetyRiskChoice.length; i++) {
      if (this.safetyRiskReady(i)) {
        completed++;
      }
    }
    return completed;
  }

  private totalAssessmentCount(): number {
    return this.assessments.length + this.safetyRisks.length;
  }

  private safetyRiskReady(riskIndex: number): boolean {
    const choice: number = this.safetyRiskChoice[riskIndex];
    if (choice < 0 || choice >= this.safetyRiskOptions.length) {
      return false;
    }
    if (this.safetyRiskOptions[choice].score === 0) {
      return true;
    }
    const hasRequiredDetails: boolean = this.safetyRiskMeasures[riskIndex].trim().length > 0 &&
      this.safetyRiskOwners[riskIndex].trim().length > 0 &&
      this.safetyRiskReviewPoints[riskIndex].trim().length > 0;
    if (!hasRequiredDetails) {
      return false;
    }
    return this.safetyRiskOptions[choice].score < 2 ||
      this.safetyRiskEscalations[riskIndex].trim().length > 0;
  }

  private clearSafetyRiskDetails(riskIndex: number): void {
    const measures: string[] = this.safetyRiskMeasures.slice();
    const owners: string[] = this.safetyRiskOwners.slice();
    const reviewPoints: string[] = this.safetyRiskReviewPoints.slice();
    const escalations: string[] = this.safetyRiskEscalations.slice();
    measures[riskIndex] = '';
    owners[riskIndex] = '';
    reviewPoints[riskIndex] = '';
    escalations[riskIndex] = '';
    this.safetyRiskMeasures = measures;
    this.safetyRiskOwners = owners;
    this.safetyRiskReviewPoints = reviewPoints;
    this.safetyRiskEscalations = escalations;
  }

  private selectSafetyRisk(riskIndex: number, optionIndex: number): void {
    if (this.safetyRiskChoice[riskIndex] === optionIndex) {
      return;
    }
    const next: number[] = this.safetyRiskChoice.slice();
    next[riskIndex] = optionIndex;
    this.safetyRiskChoice = next;
    // A changed risk level invalidates the previous owner, deadline, and escalation details.
    this.clearSafetyRiskDetails(riskIndex);
  }

  private updateSafetyRiskMeasure(riskIndex: number, value: string): void {
    const next: string[] = this.safetyRiskMeasures.slice();
    next[riskIndex] = value;
    this.safetyRiskMeasures = next;
  }

  private updateSafetyRiskOwner(riskIndex: number, value: string): void {
    const next: string[] = this.safetyRiskOwners.slice();
    next[riskIndex] = value;
    this.safetyRiskOwners = next;
  }

  private updateSafetyRiskReviewPoint(riskIndex: number, value: string): void {
    const next: string[] = this.safetyRiskReviewPoints.slice();
    next[riskIndex] = value;
    this.safetyRiskReviewPoints = next;
  }

  private updateSafetyRiskEscalation(riskIndex: number, value: string): void {
    const next: string[] = this.safetyRiskEscalations.slice();
    next[riskIndex] = value;
    this.safetyRiskEscalations = next;
  }

  /** 仅用于匹配入住照护计划，不形成正式能力等级。 */
  private supportScore(): number {
    let total: number = 0;
    for (let i: number = 0; i < this.assessments.length; i++) {
      total += this.assessmentOption(i).score;
    }
    for (let i: number = 0; i < this.safetyRisks.length; i++) {
      total += this.safetyOption(i).score;
    }
    return total;
  }

  /** 根据完成的入住初筛给出计划建议，正式照料护理等级须另行评定并取得同意。 */
  private carePlanSuggestion(): CarePlanSuggestion {
    if (!this.assessmentReady()) {
      return {
        label: `待完成 ${this.totalAssessmentCount() - this.completedAssessmentCount()} 项`,
        tone: 'pending',
        desc: '完成全部能力、健康和安全风险初筛后，系统才会给出照护计划建议。',
        recommendedPlanId: 'self-support'
      };
    }
    let severeAbilityCount: number = 0;
    let moderateAbilityCount: number = 0;
    let highSafetyRiskCount: number = 0;
    for (let i: number = 0; i < this.assessments.length; i++) {
      if (this.assessmentOption(i).score >= 3) {
        severeAbilityCount++;
      }
      if (this.assessmentOption(i).score >= 2) {
        moderateAbilityCount++;
      }
    }
    for (let i: number = 0; i < this.safetyRisks.length; i++) {
      if (this.safetyOption(i).score >= 2) {
        highSafetyRiskCount++;
      }
    }
    const score: number = this.supportScore();
    if (severeAbilityCount >= 1 || highSafetyRiskCount >= 2 || score >= 16) {
      return {
        label: '全程照护建议 · 高关注',
        tone: 'danger',
        desc: '初筛显示连续协助或多风险联合干预需求，建议由多专业团队尽快完成正式评估。',
        recommendedPlanId: 'continuous-care'
      };
    }
    if (moderateAbilityCount >= 1 || highSafetyRiskCount >= 1 || score >= 6) {
      return {
        label: '协助照护建议 · 重点关注',
        tone: 'warning',
        desc: '初筛显示部分生活活动需要协助或存在重点风险，建议细化分项照护和预防措施。',
        recommendedPlanId: 'assisted-care'
      };
    }
    return {
      label: '自理支持建议 · 常规关注',
      tone: 'normal',
      desc: '初筛暂未发现明显连续协助需求，建议以保持能力和预防功能下降为重点。',
      recommendedPlanId: 'self-support'
    };
  }

  private planById(id: string): AdmissionCarePlan {
    return this.plans.find((item: AdmissionCarePlan) => item.id === id) ?? this.plans[0];
  }

  private selectedOptionLabel(options: string[], selectedIndex: number): string {
    if (selectedIndex < 0 || selectedIndex >= options.length) {
      return '未填写';
    }
    return options[selectedIndex];
  }

  private safetyRiskDetailSummary(riskIndex: number): string {
    let summary: string = `措施：${this.safetyRiskMeasures[riskIndex]}；` +
      `责任人：${this.safetyRiskOwners[riskIndex]}；复核：${this.safetyRiskReviewPoints[riskIndex]}`;
    if (this.safetyOption(riskIndex).score >= 2) {
      summary += `；升级/转介：${this.safetyRiskEscalations[riskIndex]}`;
    }
    return summary;
  }

  private markDirty(): void {
    if (!this.dirty) {
      this.dirty = true;
      this.onDirtyChange(true);
    }
  }

  private ageReady(): boolean {
    const ageText: string = this.age.trim();
    if (!/^[0-9]{1,3}$/.test(ageText)) {
      return false;
    }
    const ageValue: number = Number(ageText);
    return Number.isInteger(ageValue) && ageValue >= 1 && ageValue <= 120;
  }

  private phoneReady(): boolean {
    let normalized: string = this.guardianPhone.trim().replace(/\s/g, '').replace(/-/g, '');
    if (normalized.startsWith('+')) {
      normalized = normalized.substring(1);
    }
    if (normalized.length < 7 || normalized.length > 15) {
      return false;
    }
    for (let index: number = 0; index < normalized.length; index++) {
      const code: number = normalized.charCodeAt(index);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private basicInfoReady(): boolean {
    return this.residentName.trim().length > 0 &&
      this.ageReady() &&
      this.room.trim().length > 0 &&
      this.bed.trim().length > 0 &&
      this.guardianName.trim().length > 0 &&
      this.phoneReady();
  }

  private basicInfoHint(): ResourceStr {
    if (this.residentName.trim().length === 0) {
      return $r('app.string.doctor_admission_validation_name');
    }
    if (!this.ageReady()) {
      return $r('app.string.doctor_admission_validation_age');
    }
    if (this.room.trim().length === 0 || this.bed.trim().length === 0) {
      return $r('app.string.doctor_admission_validation_room_bed');
    }
    if (this.guardianName.trim().length === 0) {
      return $r('app.string.doctor_admission_validation_contact');
    }
    if (!this.phoneReady()) {
      return $r('app.string.doctor_admission_validation_phone');
    }
    return $r('app.string.doctor_admission_validation_required');
  }

  private confirmationReady(): boolean {
    return this.doctorConfirmed && this.planConsentConfirmed && this.serviceFeeInformed;
  }

  private clearConfirmations(): void {
    this.doctorConfirmed = false;
    this.planConsentConfirmed = false;
    this.serviceFeeInformed = false;
  }

  private canProceed(): boolean {
    if (this.currentStep === 0) {
      return this.basicInfoReady();
    }
    if (this.currentStep === 1) {
      return this.assessmentReady();
    }
    if (this.currentStep === 2) {
      return this.selectedPlanId.length > 0;
    }
    return this.confirmationReady();
  }

  private scrollContentToTop(): void {
    try {
      this.contentScroller.scrollEdge(Edge.Top);
    } catch (_error) {
      // The scroller may not be attached during the first state update.
    }
  }

  private goNext(): void {
    if (!this.canProceed()) {
      return;
    }
    if (this.currentStep < this.steps.length - 1) {
      this.currentStep += 1;
      this.scrollContentToTop();
      return;
    }
    this.submitted = true;
  }

  private goPrev(): void {
    if (this.submitted) {
      this.submitted = false;
      return;
    }
    if (this.currentStep > 0) {
      if (this.currentStep === this.steps.length - 1) {
        this.clearConfirmations();
      }
      this.currentStep -= 1;
      this.scrollContentToTop();
    }
  }

  private resetFlow(): void {
    this.submitted = false;
    this.currentStep = 0;
    this.residentName = '';
    this.genderIndex = -1;
    this.age = '';
    this.idNumber = '';
    this.room = '';
    this.bed = '';
    this.guardianName = '';
    this.guardianPhone = '';
    this.diagnosis = '';
    this.allergies = '';
    this.sourceIndex = -1;
    this.assessmentChoice = [-1, -1, -1, -1, -1, -1];
    this.safetyRiskChoice = [-1, -1, -1, -1, -1, -1, -1, -1, -1];
    this.safetyRiskMeasures = ['', '', '', '', '', '', '', '', ''];
    this.safetyRiskOwners = ['', '', '', '', '', '', '', '', ''];
    this.safetyRiskReviewPoints = ['', '', '', '', '', '', '', '', ''];
    this.safetyRiskEscalations = ['', '', '', '', '', '', '', '', ''];
    this.selectedPlanId = '';
    this.clearConfirmations();
    this.dirty = false;
    this.onDirtyChange(false);
    this.contentScroller = new Scroller();
  }

  // ==================== 头部与步骤条 ====================

  @Builder
  private header() {
    Flex({
      direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
      alignItems: this.compactWidth ? ItemAlign.Start : ItemAlign.Center
    }) {
      Column({ space: 4 }) {
        Text('新长者入住办理')
          .fontSize(this.compactWidth ? 24 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text('核验资料、完成入住初筛并匹配照护计划，生成本地档案草稿')
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
      }
      .layoutWeight(this.compactWidth ? 0 : 1)
      .width(this.compactWidth ? '100%' : undefined)
      .alignItems(HorizontalAlign.Start)
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(13)
          .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
        Text('本地演示数据 · 尚未连接后台')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(10)
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      .margin({ top: this.compactWidth ? 10 : 0 })
    }
    .width('100%')
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
  private fieldLabel(label: ResourceStr, required: boolean) {
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
  private textField(placeholder: ResourceStr, value: string, onChange: (v: string) => void,
    inputType: InputType = InputType.Normal) {
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
      .type(inputType)
      .onChange((nextValue: string) => {
        this.markDirty();
        onChange(nextValue);
      })
  }

  @Builder
  private fieldValidationHint(message: ResourceStr) {
    Text(message)
      .fontSize(9)
      .fontColor($r('app.color.doctor_workspace_warning'))
      .width('100%')
      .margin({ top: 5 })
  }

  @Builder
  private capsuleGroup(options: string[], selected: number, onSelect: (index: number) => void) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(options, (option: string, index: number) => {
        Text(option)
          .fontSize(12)
          .fontWeight(selected === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(selected === index ?
            $r('app.color.doctor_workspace_background') :
            $r('app.color.doctor_workspace_text_secondary'))
          .height(38)
          .padding({ left: 16, right: 16 })
          .margin({ right: 6, bottom: 6 })
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
          .accessibilityText(option)
          .accessibilityRole(AccessibilityRoleType.RADIO)
          .accessibilitySelected(selected === index)
          .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
            this.markDirty();
            onSelect(index);
          }))
          .onClick(() => {
            this.markDirty();
            onSelect(index);
          })
      }, (option: string, index: number) => `${option}-${index}`)
    }
    .width('100%')
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

  @Builder
  private riskDetailInput(label: ResourceStr, placeholder: ResourceStr, value: string,
    onChange: (value: string) => void) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(9)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(38)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .placeholderColor($r('app.color.doctor_workspace_text_tertiary'))
        .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
        .borderRadius(9)
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
        .padding({ left: 9, right: 9 })
        .onChange((nextValue: string) => {
          this.markDirty();
          onChange(nextValue);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
            this.textField('岁', this.age, (v: string) => this.age = v, InputType.Number)
            if (this.age.trim().length > 0 && !this.ageReady()) {
              this.fieldValidationHint($r('app.string.doctor_admission_validation_age'))
            }
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
            this.fieldLabel($r('app.string.doctor_admission_contact_label'), true)
            this.textField('联系人姓名与关系', this.guardianName, (v: string) => this.guardianName = v)
          }
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column() {
            this.fieldLabel('联系电话', true)
            this.textField($r('app.string.doctor_admission_phone_placeholder'), this.guardianPhone,
              (v: string) => this.guardianPhone = v, InputType.PhoneNumber)
            if (this.guardianPhone.trim().length > 0 && !this.phoneReady()) {
              this.fieldValidationHint($r('app.string.doctor_admission_validation_phone'))
            }
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
          Text(this.basicInfoHint())
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

  // ==================== 第 2 步：入住初筛 ====================

  @Builder
  private assessmentCard(dimension: AdmissionAssessmentDimension, dimensionIndex: number) {
    Column({ space: 12 }) {
      Flex({
        direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
        alignItems: this.compactWidth ? ItemAlign.Start : ItemAlign.Center
      }) {
        Column({ space: 3 }) {
          Text(dimension.title)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Text(dimension.basis)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }
        .layoutWeight(this.compactWidth ? 0 : 1)
        .width(this.compactWidth ? '100%' : undefined)
        .alignItems(HorizontalAlign.Start)
        Text(this.assessmentOption(dimensionIndex).label)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.toneColor(this.assessmentOption(dimensionIndex).tone))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: this.toneColor(this.assessmentOption(dimensionIndex).tone) })
          .margin({ top: this.compactWidth ? 8 : 0 })
      }
      .width('100%')
      Text(dimension.description)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
        .lineHeight(17)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(dimension.options, (option: AdmissionAssessmentOption, optionIndex: number) => {
          Text(option.label)
            .fontSize(12)
            .fontWeight(this.assessmentChoice[dimensionIndex] === optionIndex ?
              FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.assessmentChoice[dimensionIndex] === optionIndex ?
              $r('app.color.doctor_workspace_background') :
              $r('app.color.doctor_workspace_text_secondary'))
            .height(36)
            .padding({ left: 14, right: 14 })
            .margin({ right: 8, bottom: 8 })
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.assessmentChoice[dimensionIndex] === optionIndex ?
              this.toneColor(option.tone) :
              $r('app.color.doctor_workspace_surface_raised'))
            .border({
              width: 0.5,
              color: this.assessmentChoice[dimensionIndex] === optionIndex ?
                this.toneColor(option.tone) :
                $r('app.color.doctor_workspace_border')
            })
            .focusable(true)
            .focusOnTouch(true)
            .accessibilityText(`${dimension.title}：${option.label}`)
            .accessibilityRole(AccessibilityRoleType.RADIO)
            .accessibilitySelected(this.assessmentChoice[dimensionIndex] === optionIndex)
            .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
              this.markDirty();
              const next: number[] = this.assessmentChoice.slice();
              next[dimensionIndex] = optionIndex;
              this.assessmentChoice = next;
            }))
            .onClick(() => {
              this.markDirty();
              const next: number[] = this.assessmentChoice.slice();
              next[dimensionIndex] = optionIndex;
              this.assessmentChoice = next;
            })
        }, (option: AdmissionAssessmentOption, optionIndex: number) => `${dimension.id}-${optionIndex}`)
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
  private safetyRiskCard(risk: AdmissionSafetyRisk, riskIndex: number) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(risk.title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .layoutWeight(1)
        Text(this.safetyOption(riskIndex).label)
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.toneColor(this.safetyOption(riskIndex).tone))
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .borderRadius(7)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: this.toneColor(this.safetyOption(riskIndex).tone) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(risk.description)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
        .lineHeight(16)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.safetyRiskOptions, (option: AdmissionAssessmentOption, optionIndex: number) => {
          Text(option.label)
            .fontSize(10)
            .fontWeight(this.safetyRiskChoice[riskIndex] === optionIndex ?
              FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.safetyRiskChoice[riskIndex] === optionIndex ?
              $r('app.color.doctor_workspace_background') :
              $r('app.color.doctor_workspace_text_secondary'))
            .height(34)
            .padding({ left: 11, right: 11 })
            .margin({ right: 6, bottom: 6 })
            .textAlign(TextAlign.Center)
            .borderRadius(9)
            .backgroundColor(this.safetyRiskChoice[riskIndex] === optionIndex ?
              this.toneColor(option.tone) : $r('app.color.doctor_workspace_surface_raised'))
            .border({
              width: 0.5,
              color: this.safetyRiskChoice[riskIndex] === optionIndex ?
                this.toneColor(option.tone) : $r('app.color.doctor_workspace_border')
            })
            .focusable(true)
            .focusOnTouch(true)
            .accessibilityText(`${risk.title}风险：${option.label}`)
            .accessibilityRole(AccessibilityRoleType.RADIO)
            .accessibilitySelected(this.safetyRiskChoice[riskIndex] === optionIndex)
            .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
              this.markDirty();
              this.selectSafetyRisk(riskIndex, optionIndex);
            }))
            .onClick(() => {
              this.markDirty();
              this.selectSafetyRisk(riskIndex, optionIndex);
            })
        }, (option: AdmissionAssessmentOption, optionIndex: number) => `${risk.id}-${optionIndex}`)
      }
      .width('100%')
      if (this.safetyRiskChoice[riskIndex] >= 0 && this.safetyOption(riskIndex).score > 0) {
        Text('风险处置记录')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
        TextArea({
          text: this.safetyRiskMeasures[riskIndex],
          placeholder: $r('app.string.doctor_admission_risk_measure_placeholder')
        })
          .width('100%')
          .height(68)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .placeholderColor($r('app.color.doctor_workspace_text_tertiary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .padding(10)
          .onChange((value: string) => {
            this.markDirty();
            this.updateSafetyRiskMeasure(riskIndex, value);
          })
        GridRow({ columns: 12, gutter: { x: 8, y: 8 } }) {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.riskDetailInput($r('app.string.doctor_admission_risk_owner_label'),
              $r('app.string.doctor_admission_risk_owner_placeholder'),
              this.safetyRiskOwners[riskIndex], (value: string) => this.updateSafetyRiskOwner(riskIndex, value))
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.riskDetailInput($r('app.string.doctor_admission_risk_review_label'),
              $r('app.string.doctor_admission_risk_review_placeholder'),
              this.safetyRiskReviewPoints[riskIndex],
              (value: string) => this.updateSafetyRiskReviewPoint(riskIndex, value))
          }
        }
        .width('100%')
        if (this.safetyOption(riskIndex).score >= 2) {
          this.riskDetailInput($r('app.string.doctor_admission_risk_escalation_label'),
            $r('app.string.doctor_admission_risk_escalation_placeholder'),
            this.safetyRiskEscalations[riskIndex],
            (value: string) => this.updateSafetyRiskEscalation(riskIndex, value))
          Text($r('app.string.doctor_admission_risk_high_escalation'))
            .fontSize(9)
            .fontColor($r('app.color.doctor_workspace_danger'))
            .width('100%')
        }
        if (!this.safetyRiskReady(riskIndex)) {
          Text($r('app.string.doctor_admission_risk_measure_required'))
            .fontSize(9)
            .fontColor($r('app.color.doctor_workspace_warning'))
            .width('100%')
        }
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private carePlanSuggestionBanner() {
    Column({ space: 10 }) {
      Flex({
        direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
        alignItems: ItemAlign.Start
      }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.waveform_path_ecg_magnifyingglass'))
            .fontSize(18)
            .fontColor([this.toneColor(this.carePlanSuggestion().tone)])
          Text(this.assessmentReady() ? '入住初筛建议' : '入住初筛进度')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
        }
        .layoutWeight(this.compactWidth ? 0 : 1)
        .width(this.compactWidth ? '100%' : undefined)
        Text(this.carePlanSuggestion().label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.toneColor(this.carePlanSuggestion().tone))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(9)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: this.toneColor(this.carePlanSuggestion().tone) })
          .margin({ top: this.compactWidth ? 8 : 0 })
      }
      .width('100%')
      Text(this.carePlanSuggestion().desc)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
        .lineHeight(18)
      Text('能力四维初筛参考 GB/T 42195-2022 一级指标；正式能力评估仍需完成全部指标。安全风险覆盖 GB 38600-2019 九类风险。本页不替代正式量表和人工确认。')
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width('100%')
        .lineHeight(16)
    }
    .width('100%')
    .padding(16)
    .borderRadius(14)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: this.toneColor(this.carePlanSuggestion().tone) })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepAssessment() {
    Column() {
      this.sectionCard('入住综合初筛',
        `完成能力、健康与安全风险共 ${this.totalAssessmentCount()} 项初筛，再进入照护计划选择`)
      this.carePlanSuggestionBanner()
      Column() {
        this.sectionCard('能力与健康支持', '四个国家标准一级维度加两项入住健康支持观察')
      }
      .width('100%')
      .margin({ top: 18 })
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        ForEach(this.assessments, (dimension: AdmissionAssessmentDimension, index: number) => {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.assessmentCard(dimension, index)
          }
        }, (dimension: AdmissionAssessmentDimension) => dimension.id)
      }
      .width('100%')
      Column() {
        this.sectionCard('入住服务安全风险', '按 GB 38600-2019 逐项记录九类风险等级，后续由正式评估补充处置措施')
      }
      .width('100%')
      .margin({ top: 18 })
      GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
        ForEach(this.safetyRisks, (risk: AdmissionSafetyRisk, index: number) => {
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.safetyRiskCard(risk, index)
          }
        }, (risk: AdmissionSafetyRisk) => risk.id)
      }
      .width('100%')
      if (!this.assessmentReady()) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(12)
            .fontColor([$r('app.color.doctor_workspace_warning')])
          Text(`已完成 ${this.completedAssessmentCount()} / ${this.totalAssessmentCount()} 项，全部完成后可进入下一步`)
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

  // ==================== 第 3 步：照护计划选择 ====================

  @Builder
  private carePlanCard(item: AdmissionCarePlan) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(item.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            if (this.carePlanSuggestion().recommendedPlanId === item.id) {
              Text('初筛建议')
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
              width: this.selectedPlanId === item.id ? 7 : 1.5,
              color: this.selectedPlanId === item.id ?
                this.toneColor('focus') : $r('app.color.doctor_workspace_border')
            })
        }
        .width(22)
        .height(22)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      Row({ space: 6 }) {
        Text('费用按机构公示')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text('最终以服务协议为准')
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }
      .alignItems(VerticalAlign.Center)
      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.doctor_workspace_border_soft'))
      Column({ space: 8 }) {
        Text('基础服务')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
        ForEach(item.baseServices, (service: string) => {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(12)
              .fontColor([this.toneColor('normal')])
            Text(service)
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
              .layoutWeight(1)
              .lineHeight(17)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (service: string) => service)
        Text('可选项目 · 按需写入服务协议')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
          .margin({ top: 4 })
        ForEach(item.optionalServices, (service: string) => {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(11)
              .fontColor([this.toneColor(item.tone)])
            Text(service)
              .fontSize(11)
              .fontColor($r('app.color.doctor_workspace_text_secondary'))
              .layoutWeight(1)
              .lineHeight(17)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (service: string) => `optional-${item.id}-${service}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({
      width: this.selectedPlanId === item.id ? 1.5 : 0.5,
      color: this.selectedPlanId === item.id ?
        this.toneColor('focus') : $r('app.color.doctor_workspace_border')
    })
    .alignItems(HorizontalAlign.Start)
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText(`照护计划：${item.name}`)
    .accessibilityRole(AccessibilityRoleType.RADIO)
    .accessibilitySelected(this.selectedPlanId === item.id)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.markDirty();
      this.selectedPlanId = item.id;
    }))
    .onClick(() => {
      this.markDirty();
      this.selectedPlanId = item.id;
    })
  }

  @Builder
  private stepCarePlan() {
    Column() {
      this.sectionCard('选择入住照护计划', '初筛建议仅用于辅助选择，基础服务、可选项目与费用须写入服务协议')
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(13)
          .fontColor([this.toneColor(this.carePlanSuggestion().tone)])
        Column({ space: 3 }) {
          Text(`初筛建议：${this.planById(this.carePlanSuggestion().recommendedPlanId).name}`)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .width('100%')
          Text('请结合正式评估、机构服务能力与长者意愿人工选择')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(10)
      .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
      .margin({ bottom: 14 })
      .alignItems(VerticalAlign.Center)
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        ForEach(this.plans, (item: AdmissionCarePlan) => {
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.carePlanCard(item)
          }
        }, (item: AdmissionCarePlan) => item.id)
      }
      .width('100%')
      if (this.selectedPlanId.length === 0) {
        Text($r('app.string.doctor_admission_validation_plan'))
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .width('100%')
          .margin({ top: 12 })
      }
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
      ForEach(this.assessments, (dimension: AdmissionAssessmentDimension, index: number) => {
        Row({ space: 12 }) {
          Text(dimension.title)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .layoutWeight(1)
          Text(this.assessmentOption(index).label)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.toneColor(this.assessmentOption(index).tone))
        }
        .width('100%')
        .padding({ top: 7, bottom: 7 })
        .border({
          width: { bottom: 0.5 },
          color: { bottom: $r('app.color.doctor_workspace_border_soft') }
        })
      }, (dimension: AdmissionAssessmentDimension) => `sum-${dimension.id}`)
    }
    .width('100%')
  }

  @Builder
  private safetyRiskSummary() {
    GridRow({ columns: 12, gutter: { x: 12, y: 6 } }) {
      ForEach(this.safetyRisks, (risk: AdmissionSafetyRisk, index: number) => {
        GridCol({ span: this.compactWidth ? 12 : 6 }) {
          Column({ space: 3 }) {
            Row({ space: 8 }) {
              Text(risk.title)
                .fontSize(10)
                .fontColor($r('app.color.doctor_workspace_text_secondary'))
                .layoutWeight(1)
              Text(this.safetyOption(index).label)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.toneColor(this.safetyOption(index).tone))
            }
            if (this.safetyOption(index).score > 0 && this.safetyRiskReady(index)) {
              Text(this.safetyRiskDetailSummary(index))
                .fontSize(9)
                .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                .width('100%')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .border({
            width: { bottom: 0.5 },
            color: { bottom: $r('app.color.doctor_workspace_border_soft') }
          })
          .alignItems(HorizontalAlign.Center)
        }
      }, (risk: AdmissionSafetyRisk) => `risk-sum-${risk.id}`)
    }
    .width('100%')
  }

  @Builder
  private confirmationItem(id: string, title: string, description: string,
    checked: boolean, onChange: (value: boolean) => void) {
    Row({ space: 12 }) {
      Checkbox({ name: id })
        .select(checked)
        .selectedColor($r('app.color.doctor_workspace_focus'))
        .width(22)
        .height(22)
        .accessibilityLevel('no')
        .onTouch((event: TouchEvent) => event.stopPropagation())
        .onChange((value: boolean) => {
          this.markDirty();
          onChange(value);
        })
      Column({ space: 3 }) {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
        Text(description)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .width('100%')
          .lineHeight(16)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ top: 9, bottom: 9, left: 4, right: 4 })
    .alignItems(VerticalAlign.Top)
    .borderRadius(10)
    .focusable(true)
    .focusOnTouch(true)
    .accessibilityText(`${title}。${description}`)
    .accessibilityRole(AccessibilityRoleType.CHECKBOX)
    .accessibilityChecked(checked)
    .onKeyEvent((event: KeyEvent) => this.activateWithKeyboard(event, () => {
      this.markDirty();
      onChange(!checked);
    }))
    .onClick(() => {
      this.markDirty();
      onChange(!checked);
    })
  }

  @Builder
  private stepConfirm() {
    Column() {
      this.sectionCard('确认并生成草稿', '核对资料，完成医师复核、知情同意和服务费用告知')
      GridRow({ columns: 12, gutter: { x: 16, y: 16 } }) {
        GridCol({ span: this.compactWidth ? 12 : 5 }) {
          Column({ space: 12 }) {
            Text('基础资料')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width('100%')
            this.summaryRow('姓名', this.residentName)
            this.summaryRow('证件号', this.idNumber)
            this.summaryRow('性别 / 年龄',
              `${this.selectedOptionLabel(this.genderOptions, this.genderIndex)} · ${this.age.length > 0 ? this.age + ' 岁' : '—'}`)
            this.summaryRow('房间 / 床位', `${this.room}-${this.bed}`)
            this.summaryRow('联系人', this.guardianName)
            this.summaryRow('联系电话', this.guardianPhone)
            this.summaryRow('入住来源', this.selectedOptionLabel(this.sourceOptions, this.sourceIndex))
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
        GridCol({ span: this.compactWidth ? 12 : 7 }) {
          Column({ space: 16 }) {
            Column({ space: 12 }) {
              Row() {
                Text('入住初筛摘要')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                  .layoutWeight(1)
                Text(this.carePlanSuggestion().label)
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.toneColor(this.carePlanSuggestion().tone))
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
                  .border({ width: 0.5, color: this.toneColor(this.carePlanSuggestion().tone) })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              this.assessmentSummary()
              Text('九类服务安全风险')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
                .width('100%')
                .margin({ top: 4 })
              this.safetyRiskSummary()
              Text('以上为入住初筛记录，不等同于正式能力等级或诊断结论。')
                .fontSize(9)
                .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                .width('100%')
            }
            .width('100%')
            .padding(18)
            .borderRadius(16)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            .alignItems(HorizontalAlign.Start)
            Column({ space: 10 }) {
              Text('入住照护计划')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.doctor_workspace_text_primary'))
                .width('100%')
              Flex({
                direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
                alignItems: ItemAlign.Start
              }) {
                Text(this.planById(this.selectedPlanId).name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                  .layoutWeight(this.compactWidth ? 0 : 1)
                  .width(this.compactWidth ? '100%' : undefined)
                Text('费用按机构公示，最终以服务协议为准')
                  .fontSize(11)
                  .fontColor($r('app.color.doctor_workspace_text_secondary'))
                  .width(this.compactWidth ? '100%' : undefined)
                  .margin({ top: this.compactWidth ? 4 : 0 })
              }
              .width('100%')
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
      Column({ space: 2 }) {
        Text('建档前确认')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
        this.confirmationItem('doctor-confirmed', '医师已复核入住初筛结论',
          '确认信息完整，并已安排或完成所需的正式能力、健康及专项风险评估。',
          this.doctorConfirmed, (value: boolean) => this.doctorConfirmed = value)
        this.confirmationItem('plan-consent', '长者或代理人已知情并同意当前入住照护计划',
          '已说明所选计划、服务内容和初筛依据；正式照料护理等级仍须另行评定并取得同意。',
          this.planConsentConfirmed, (value: boolean) => this.planConsentConfirmed = value)
        this.confirmationItem('service-fee-informed', '服务内容和费用标准已完成告知',
          '已说明床位住宿、照料护理、膳食、可选项目、收费标准、期限和服务场所，并将写入服务协议。',
          this.serviceFeeInformed, (value: boolean) => this.serviceFeeInformed = value)
        if (!this.confirmationReady()) {
          Text($r('app.string.doctor_admission_validation_confirmations'))
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_warning'))
            .width('100%')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding(18)
      .margin({ top: 16 })
      .borderRadius(16)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 本地草稿生成态 ====================

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
      Text('本地入住档案草稿已生成')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(`${this.residentName.length > 0 ? this.residentName : '新长者'} · ${this.room}-${this.bed} · ${this.planById(this.selectedPlanId).name}`)
        .fontSize(12)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
      Text('当前仅生成本地演示草稿，尚未提交后台，也不会形成正式入住档案。')
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 420 })
      Flex({
        direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
        alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.Center,
        space: { main: LengthMetrics.vp(12) }
      }) {
        Button('再办理一位')
          .height(42)
          .width(this.compactWidth ? '100%' : undefined)
          .padding({ left: 20, right: 20 })
          .borderRadius(12)
          .fontSize(13)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .onClick(() => this.resetFlow())
        Button('返回工作台')
          .height(42)
          .width(this.compactWidth ? '100%' : undefined)
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
      .width(this.compactWidth ? '100%' : undefined)
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
    Flex({
      direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
      alignItems: this.compactWidth ? ItemAlign.Start : ItemAlign.Center,
      justifyContent: FlexAlign.Center
    }) {
      Text(`第 ${this.currentStep + 1} / ${this.steps.length} 步 · ${this.steps[this.currentStep].label}`)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .layoutWeight(this.compactWidth ? 0 : 1)
        .width(this.compactWidth ? '100%' : undefined)
      Row({ space: 12 }) {
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
        Button(this.currentStep === this.steps.length - 1 ? '生成本地草稿' : '下一步')
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
      .width(this.compactWidth ? '100%' : undefined)
      .justifyContent(FlexAlign.End)
      .margin({ top: this.compactWidth ? 10 : 0 })
    }
    .width('100%')
    .constraintSize({ maxWidth: 1200 })
    .padding({
      left: this.mainPadding(),
      right: this.mainPadding(),
      top: 12,
      bottom: 12 + this.naviIndicatorHeight
    })
  }

  @Builder
  private stepContent() {
    if (this.currentStep === 0) {
      this.stepBasicInfo()
    } else if (this.currentStep === 1) {
      this.stepAssessment()
    } else if (this.currentStep === 2) {
      this.stepCarePlan()
    } else {
      this.stepConfirm()
    }
  }

  build() {
    Column() {
      if (this.submitted) {
        this.submittedView()
      } else {
        Scroll(this.contentScroller) {
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
