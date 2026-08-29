/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import {
  AdmissionAnswer,
  AdmissionAssessmentPayload,
  AdmissionAssessmentOption,
  AdmissionAssessmentQuestion,
  AdmissionAssessmentRecord,
  AdmissionBootstrap,
  AdmissionCareService,
  AdmissionCarePlanTemplate,
  AdmissionDictionaryOption,
  AdmissionGroupScore,
  AdmissionLevelRule,
  AdmissionMedication,
  AdmissionPreviewResult,
  AdmissionRiskEvent,
  AdmissionSubmitResult
} from '../../network/AdmissionApi';
import AdmissionRepository, { AdmissionFailureKind, AdmissionResult } from '../../network/AdmissionRepository';
import { Bed, Paged } from '../../network/Dto';
import { AdmissionScreeningPanel } from './AdmissionScreeningPanel';

type AdmissionView = 'loading' | 'drafts' | 'form' | 'submitted' | 'error';

interface AdmissionHealthCategory {
  code: string;
  label: string;
}

@ComponentV2
export struct WideDoctorAdmission {
  @Param compactWidth: boolean = false;
  @Param standaloneMode: boolean = false;
  @Param contentTopInset: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onExit: () => void = () => {};
  @Event onDirtyChange: (dirty: boolean) => void = (_dirty: boolean) => {};

  @Local view: AdmissionView = 'loading';
  @Local operation: string = '';
  @Local errorKind: AdmissionFailureKind = 'none';
  @Local errorMessage: string = '';
  @Local bootstrap: AdmissionBootstrap | null = null;
  @Local drafts: AdmissionAssessmentRecord[] = [];
  @Local beds: Bed[] = [];
  @Local draftId: number = 0;
  @Local assessmentNo: string = '';
  @Local currentStep: number = 0;
  @Local dirty: boolean = false;
  @Local preview: AdmissionPreviewResult | null = null;
  @Local submitResult: AdmissionSubmitResult | null = null;

  @Local assessmentReason: string = '';
  @Local baselineDate: string = '';
  @Local residentName: string = '';
  @Local gender: string = '';
  @Local birthDate: string = '';
  @Local idCard: string = '';
  @Local heightText: string = '';
  @Local weightText: string = '';
  @Local ethnicity: string = '';
  @Local religion: string = '';
  @Local education: string = '';
  @Local livingSituations: string[] = [];
  @Local maritalStatus: string = '';
  @Local medicalPayments: string[] = [];
  @Local incomeSources: string[] = [];
  @Local riskEvents: AdmissionRiskEvent[] = [];
  @Local diagnoses: string[] = [];
  @Local dementiaOrMentalDisorder: boolean = false;
  @Local coma: boolean = false;
  @Local medicationsText: string = '';
  @Local healthIssues: string[] = [];
  @Local infoProviderName: string = '';
  @Local infoProviderRelation: string = '';
  @Local contactName: string = '';
  @Local contactPhone: string = '';
  @Local assessmentLocation: string = '';
  @Local targetBedId: number = 0;

  @Local answers: AdmissionAnswer[] = [];
  @Local selectedCarePlanCode: string = '';
  @Local selectedOptionalServices: string[] = [];
  @Local doctorConfirmed: boolean = false;
  @Local planConsentConfirmed: boolean = false;
  @Local serviceFeeInformed: boolean = false;
  @Local infoProviderSigned: boolean = false;

  private contentScroller: Scroller = new Scroller();
  private readonly steps: string[] = ['基本信息（A）', '能力评估（B）', '结果与计划（C）', '入住确认'];

  aboutToAppear(): void {
    this.loadWorkspace();
  }

  private mainPadding(): number {
    return this.compactWidth ? 18 : 24;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // Async work may finish after the component is detached.
    }
  }

  private async loadWorkspace(): Promise<void> {
    this.view = 'loading';
    this.clearError();
    const bootstrapResult: AdmissionResult<AdmissionBootstrap> = await AdmissionRepository.bootstrap();
    if (!bootstrapResult.ok || bootstrapResult.data === undefined) {
      this.failInitial(bootstrapResult.kind, bootstrapResult.message);
      return;
    }
    if (bootstrapResult.data.template.questions.length === 0) {
      this.failInitial('missing', '服务器尚未配置入住评估题库');
      return;
    }
    this.bootstrap = bootstrapResult.data;
    const bedResult: AdmissionResult<Paged<Bed>> = await AdmissionRepository.freeBeds();
    if (bedResult.ok && bedResult.data !== undefined) {
      this.beds = bedResult.data.list;
    } else if (bedResult.kind === 'session') {
      this.failInitial(bedResult.kind, bedResult.message);
      return;
    } else {
      this.beds = [];
      this.setFailure(bedResult.kind, `空闲床位加载失败：${bedResult.message}`);
    }
    const draftResult: AdmissionResult<Paged<AdmissionAssessmentRecord>> = await AdmissionRepository.listDrafts();
    if (draftResult.ok && draftResult.data !== undefined) {
      this.drafts = draftResult.data.list;
    } else if (draftResult.kind === 'session') {
      this.failInitial(draftResult.kind, draftResult.message);
      return;
    } else {
      this.drafts = [];
      this.setFailure(draftResult.kind, `草稿加载失败：${draftResult.message}`);
    }
    this.view = 'drafts';
  }

  private failInitial(kind: AdmissionFailureKind, message: string): void {
    this.errorKind = kind;
    this.errorMessage = message.length > 0 ? message : '入住评估加载失败';
    this.view = 'error';
  }

  private setFailure(kind: AdmissionFailureKind, message: string): void {
    this.errorKind = kind;
    this.errorMessage = message.length > 0 ? message : '操作失败';
    if (kind === 'session') {
      this.view = 'error';
    }
  }

  private clearError(): void {
    this.errorKind = 'none';
    this.errorMessage = '';
  }

  private markDirty(invalidatePreview: boolean = false): void {
    if (invalidatePreview) {
      this.preview = null;
    }
    if (!this.dirty) {
      this.dirty = true;
      this.onDirtyChange(true);
    }
  }

  private markSaved(): void {
    this.dirty = false;
    this.onDirtyChange(false);
  }

  private dictionary(category: string): AdmissionDictionaryOption[] {
    const result: AdmissionDictionaryOption[] = [];
    if (this.bootstrap === null) {
      return result;
    }
    for (let index: number = 0; index < this.bootstrap.dictionaries.length; index++) {
      if (this.bootstrap.dictionaries[index].category === category) {
        result.push(this.bootstrap.dictionaries[index]);
      }
    }
    return result;
  }

  private healthCategories(): AdmissionHealthCategory[] {
    return this.dictionary('health_category').map((option: AdmissionDictionaryOption): AdmissionHealthCategory => {
      return { code: option.code, label: option.label };
    });
  }

  private questions(): AdmissionAssessmentQuestion[] {
    return this.bootstrap === null ? [] : this.bootstrap.template.questions;
  }

  private plans(): AdmissionCarePlanTemplate[] {
    return this.bootstrap === null ? [] : this.bootstrap.care_plan_templates;
  }

  private levels(): AdmissionLevelRule[] {
    if (this.bootstrap === null || this.bootstrap.level_rules === undefined) {
      return [];
    }
    return this.bootstrap.level_rules;
  }

  private scoringNotes(): string[] {
    return this.bootstrap === null ? [] : this.bootstrap.scoring_notes;
  }

  private templateLabel(): string {
    return this.bootstrap === null ? '等待服务器模板' :
      `${this.bootstrap.template.name} · ${this.bootstrap.template.version}`;
  }

  private groupCodes(): string[] {
    const result: string[] = [];
    const questions: AdmissionAssessmentQuestion[] = this.questions();
    for (let index: number = 0; index < questions.length; index++) {
      if (result.indexOf(questions[index].group_code) < 0) {
        result.push(questions[index].group_code);
      }
    }
    return result;
  }

  private questionsForGroup(code: string): AdmissionAssessmentQuestion[] {
    const result: AdmissionAssessmentQuestion[] = [];
    const questions: AdmissionAssessmentQuestion[] = this.questions();
    for (let index: number = 0; index < questions.length; index++) {
      if (questions[index].group_code === code) {
        result.push(questions[index]);
      }
    }
    return result;
  }

  private groupName(code: string): string {
    const questions: AdmissionAssessmentQuestion[] = this.questionsForGroup(code);
    return questions.length > 0 ? questions[0].group_name : code;
  }

  private resetForm(): void {
    this.draftId = 0;
    this.assessmentNo = '';
    this.currentStep = 0;
    this.preview = null;
    this.submitResult = null;
    this.assessmentReason = '';
    this.baselineDate = '';
    this.residentName = '';
    this.gender = '';
    this.birthDate = '';
    this.idCard = '';
    this.heightText = '';
    this.weightText = '';
    this.ethnicity = '';
    this.religion = '';
    this.education = '';
    this.livingSituations = [];
    this.maritalStatus = '';
    this.medicalPayments = [];
    this.incomeSources = [];
    this.riskEvents = [];
    this.diagnoses = [];
    this.dementiaOrMentalDisorder = false;
    this.coma = false;
    this.medicationsText = '';
    this.healthIssues = [];
    this.infoProviderName = '';
    this.infoProviderRelation = '';
    this.contactName = '';
    this.contactPhone = '';
    this.assessmentLocation = '';
    this.targetBedId = 0;
    this.answers = [];
    this.selectedCarePlanCode = '';
    this.selectedOptionalServices = [];
    this.doctorConfirmed = false;
    this.planConsentConfirmed = false;
    this.serviceFeeInformed = false;
    this.infoProviderSigned = false;
    this.clearError();
    this.markSaved();
    this.contentScroller = new Scroller();
  }

  private startNew(): void {
    this.resetForm();
    this.view = 'form';
  }

  private async refreshDrafts(): Promise<void> {
    const result: AdmissionResult<Paged<AdmissionAssessmentRecord>> = await AdmissionRepository.listDrafts();
    if (result.ok && result.data !== undefined) {
      this.drafts = result.data.list;
    }
  }

  private async returnToDrafts(): Promise<void> {
    if (this.operation.length > 0) {
      return;
    }
    if (this.dirty && !await this.saveDraft(this.currentStep, false)) {
      return;
    }
    this.view = 'drafts';
  }

  private async openDraft(id: number): Promise<void> {
    if (this.operation.length > 0) {
      return;
    }
    this.operation = 'loading';
    this.clearError();
    const result: AdmissionResult<AdmissionAssessmentRecord> = await AdmissionRepository.getAssessment(id);
    this.operation = '';
    if (!result.ok || result.data === undefined) {
      this.setFailure(result.kind, result.message);
      return;
    }
    if (result.data.status !== 'draft') {
      this.setFailure('conflict', '该评估已被提交或关闭，请刷新草稿列表');
      return;
    }
    this.applyRecord(result.data);
    this.view = 'form';
    if (this.currentStep >= 2 && this.assessmentReady()) {
      await this.requestPreview(false);
    }
  }

  private applyRecord(record: AdmissionAssessmentRecord): void {
    this.resetForm();
    this.draftId = record.id;
    this.assessmentNo = record.assessment_no;
    this.currentStep = Math.max(0, Math.min(record.current_step, this.steps.length - 1));
    this.assessmentReason = record.assessment_reason ?? '';
    this.baselineDate = record.baseline_date ?? '';
    this.residentName = record.resident_name ?? '';
    this.gender = record.gender ?? '';
    this.birthDate = record.birth_date ?? '';
    this.idCard = record.id_card ?? '';
    this.heightText = record.height_cm > 0 ? `${record.height_cm}` : '';
    this.weightText = record.weight_kg > 0 ? `${record.weight_kg}` : '';
    this.ethnicity = record.ethnicity ?? '';
    this.religion = record.religion ?? '';
    this.education = record.education ?? '';
    this.livingSituations = record.living_situations ?? [];
    this.maritalStatus = record.marital_status ?? '';
    this.medicalPayments = record.medical_payments ?? [];
    this.incomeSources = record.income_sources ?? [];
    this.riskEvents = record.risk_events ?? [];
    this.diagnoses = record.diagnoses ?? [];
    this.dementiaOrMentalDisorder = record.dementia_or_mental_disorder;
    this.coma = record.coma;
    this.medicationsText = this.medicationsToText(record.medications ?? []);
    this.healthIssues = record.health_issues ?? [];
    this.infoProviderName = record.info_provider_name ?? '';
    this.infoProviderRelation = record.info_provider_relation ?? '';
    this.contactName = record.contact_name ?? '';
    this.contactPhone = record.contact_phone ?? '';
    this.assessmentLocation = record.assessment_location ?? '';
    this.targetBedId = record.target_bed_id ?? 0;
    this.selectedCarePlanCode = record.selected_care_plan_code ?? '';
    this.selectedOptionalServices = record.selected_optional_services ?? [];
    this.doctorConfirmed = record.doctor_confirmed;
    this.planConsentConfirmed = record.plan_consent_confirmed;
    this.serviceFeeInformed = record.service_fee_informed;
    this.infoProviderSigned = record.info_provider_signed;
    const restored: AdmissionAnswer[] = [];
    const stored = record.answers ?? [];
    for (let index: number = 0; index < stored.length; index++) {
      const answer: AdmissionAnswer = { question_id: stored[index].question_id, answer_text: stored[index].answer_text ?? '' };
      if (stored[index].option_id !== undefined) {
        answer.option_id = stored[index].option_id;
      }
      restored.push(answer);
    }
    this.answers = restored;
    this.markSaved();
  }

  private parseMedications(): AdmissionMedication[] {
    const result: AdmissionMedication[] = [];
    const lines: string[] = this.medicationsText.split('\n');
    for (let index: number = 0; index < lines.length; index++) {
      const parts: string[] = lines[index].split('|');
      if (parts.length > 0 && parts[0].trim().length > 0) {
        result.push({
          name: parts[0].trim(),
          method: parts.length > 1 ? parts[1].trim() : '',
          dose: parts.length > 2 ? parts[2].trim() : '',
          frequency: parts.length > 3 ? parts[3].trim() : ''
        });
      }
    }
    return result;
  }

  private medicationsToText(items: AdmissionMedication[]): string {
    const lines: string[] = [];
    for (let index: number = 0; index < items.length; index++) {
      lines.push(`${items[index].name}|${items[index].method}|${items[index].dose}|${items[index].frequency}`);
    }
    return lines.join('\n');
  }

  private activeRiskEvents(): AdmissionRiskEvent[] {
    const result: AdmissionRiskEvent[] = [];
    for (let index: number = 0; index < this.riskEvents.length; index++) {
      if (this.riskEvents[index].count > 0) {
        result.push(this.riskEvents[index]);
      }
    }
    return result;
  }

  private buildPayload(step: number = this.currentStep): AdmissionAssessmentPayload {
    const height: number = Number(this.heightText.trim());
    const weight: number = Number(this.weightText.trim());
    const payload: AdmissionAssessmentPayload = {
      current_step: step,
      assessment_reason: this.assessmentReason,
      baseline_date: this.baselineDate.trim(),
      resident_name: this.residentName.trim(),
      gender: this.gender,
      birth_date: this.birthDate.trim(),
      id_card: this.idCard.trim(),
      height_cm: Number.isFinite(height) && height >= 0 ? height : 0,
      weight_kg: Number.isFinite(weight) && weight >= 0 ? weight : 0,
      ethnicity: this.ethnicity,
      religion: this.religion,
      education: this.education,
      living_situations: this.livingSituations,
      marital_status: this.maritalStatus,
      medical_payments: this.medicalPayments,
      income_sources: this.incomeSources,
      risk_events: this.activeRiskEvents(),
      diagnoses: this.diagnoses,
      dementia_or_mental_disorder: this.dementiaOrMentalDisorder,
      medications: this.parseMedications(),
      health_issues: this.healthIssues,
      coma: this.coma,
      info_provider_name: this.infoProviderName.trim(),
      info_provider_relation: this.infoProviderRelation,
      contact_name: this.contactName.trim(),
      contact_phone: this.contactPhone.trim(),
      selected_care_plan_code: this.selectedCarePlanCode,
      selected_optional_services: this.selectedOptionalServices,
      assessment_location: this.assessmentLocation.trim(),
      doctor_confirmed: this.doctorConfirmed,
      plan_consent_confirmed: this.planConsentConfirmed,
      service_fee_informed: this.serviceFeeInformed,
      info_provider_signed: this.infoProviderSigned,
      answers: this.answers
    };
    if (this.targetBedId > 0) {
      payload.target_bed_id = this.targetBedId;
    }
    return payload;
  }

  private async saveDraft(step: number = this.currentStep, notify: boolean = true): Promise<boolean> {
    if (this.operation.length > 0) {
      return false;
    }
    this.operation = 'saving';
    this.clearError();
    const result: AdmissionResult<AdmissionAssessmentRecord> =
      await AdmissionRepository.save(this.draftId, this.buildPayload(step));
    this.operation = '';
    if (!result.ok || result.data === undefined) {
      this.setFailure(result.kind, result.message);
      return false;
    }
    this.draftId = result.data.id;
    this.assessmentNo = result.data.assessment_no;
    this.markSaved();
    await this.refreshDrafts();
    if (notify) {
      this.showToast('草稿已保存到服务器');
    }
    return true;
  }

  private optionId(questionId: number): number {
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].question_id === questionId && this.answers[index].option_id !== undefined) {
        return this.answers[index].option_id as number;
      }
    }
    return 0;
  }

  private selectAnswer(questionId: number, optionId: number): void {
    const next: AdmissionAnswer[] = [];
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].question_id !== questionId) {
        next.push(this.answers[index]);
      }
    }
    next.push({ question_id: questionId, option_id: optionId, answer_text: '' });
    this.answers = next;
    this.markDirty(true);
  }

  private assessmentReady(): boolean {
    const questions: AdmissionAssessmentQuestion[] = this.questions();
    for (let index: number = 0; index < questions.length; index++) {
      if (questions[index].required && this.optionId(questions[index].id) === 0) {
        return false;
      }
    }
    return questions.length > 0;
  }

  private completedQuestions(): number {
    let count: number = 0;
    const questions: AdmissionAssessmentQuestion[] = this.questions();
    for (let index: number = 0; index < questions.length; index++) {
      if (this.optionId(questions[index].id) > 0) {
        count++;
      }
    }
    return count;
  }

  private basicReady(): boolean {
    const height: number = Number(this.heightText.trim());
    const weight: number = Number(this.weightText.trim());
    return this.assessmentReason.length > 0 && /^\d{4}-\d{2}-\d{2}$/.test(this.baselineDate.trim()) &&
      this.residentName.trim().length > 0 && this.gender.length > 0 &&
      /^\d{4}-\d{2}-\d{2}$/.test(this.birthDate.trim()) && this.idCard.trim().length > 0 &&
      Number.isFinite(height) && height > 0 && Number.isFinite(weight) && weight > 0 &&
      this.assessmentLocation.trim().length > 0 && this.infoProviderName.trim().length > 0 &&
      this.infoProviderRelation.length > 0 && this.contactName.trim().length > 0 &&
      this.contactPhone.trim().length >= 7;
  }

  private planReady(): boolean {
    return this.preview !== null && this.selectedCarePlanCode.length > 0 && this.targetBedId > 0;
  }

  private confirmationsReady(): boolean {
    return this.doctorConfirmed && this.planConsentConfirmed && this.serviceFeeInformed && this.infoProviderSigned;
  }

  private stepReady(): boolean {
    if (this.currentStep === 0) {
      return this.basicReady();
    }
    if (this.currentStep === 1) {
      return this.assessmentReady();
    }
    if (this.currentStep === 2) {
      return this.planReady();
    }
    return this.confirmationsReady();
  }

  private async requestPreview(notify: boolean = true): Promise<boolean> {
    if (!this.assessmentReady()) {
      this.setFailure('validation', '请先完成全部必答题');
      return false;
    }
    if (this.draftId === 0 && !await this.saveDraft(2, false)) {
      return false;
    }
    if (this.operation.length > 0) {
      return false;
    }
    this.operation = 'previewing';
    this.clearError();
    const result: AdmissionResult<AdmissionPreviewResult> =
      await AdmissionRepository.preview(this.draftId, this.answers);
    this.operation = '';
    if (!result.ok || result.data === undefined) {
      this.setFailure(result.kind, result.message);
      return false;
    }
    if (!result.data.complete) {
      this.setFailure('validation', `服务器确认已完成 ${result.data.answered_count} / ${result.data.required_count} 项`);
      return false;
    }
    this.preview = result.data;
    if (result.data.suggested_care_plan !== undefined &&
      this.selectedCarePlanCode !== result.data.suggested_care_plan.code) {
      this.selectedCarePlanCode = result.data.suggested_care_plan.code;
      this.selectedOptionalServices = [];
      this.markDirty();
    }
    if (notify) {
      this.showToast('服务端已重新计分');
    }
    return true;
  }

  private async next(): Promise<void> {
    if (!this.stepReady() || this.operation.length > 0) {
      return;
    }
    if (this.currentStep === this.steps.length - 1) {
      await this.submit();
      return;
    }
    const nextStep: number = this.currentStep + 1;
    if (!await this.saveDraft(nextStep, false)) {
      return;
    }
    if (this.currentStep === 1 && !await this.requestPreview(false)) {
      return;
    }
    this.currentStep = nextStep;
    this.scrollTop();
  }

  private previous(): void {
    if (this.currentStep > 0 && this.operation.length === 0) {
      this.currentStep--;
      this.markDirty();
      this.scrollTop();
    }
  }

  private scrollTop(): void {
    try {
      this.contentScroller.scrollEdge(Edge.Top);
    } catch (_error) {
      // The scroller is attached after the state update.
    }
  }

  private async submit(): Promise<void> {
    if (!this.confirmationsReady() || this.preview === null || this.operation.length > 0) {
      return;
    }
    if (!await this.saveDraft(this.currentStep, false)) {
      return;
    }
    this.operation = 'submitting';
    this.clearError();
    const result: AdmissionResult<AdmissionSubmitResult> =
      await AdmissionRepository.submit(this.draftId);
    this.operation = '';
    if (!result.ok || result.data === undefined) {
      this.setFailure(result.kind, result.message);
      return;
    }
    this.submitResult = result.data;
    this.markSaved();
    await this.refreshDrafts();
    this.view = 'submitted';
  }

  private contains(values: string[], value: string): boolean {
    return values.indexOf(value) >= 0;
  }

  private toggle(values: string[], value: string): string[] {
    const next: string[] = [];
    let removed: boolean = false;
    for (let index: number = 0; index < values.length; index++) {
      if (values[index] === value) {
        removed = true;
      } else {
        next.push(values[index]);
      }
    }
    if (!removed) {
      next.push(value);
    }
    return next;
  }

  private riskCount(code: string): number {
    for (let index: number = 0; index < this.riskEvents.length; index++) {
      if (this.riskEvents[index].code === code) {
        return this.riskEvents[index].count;
      }
    }
    return 0;
  }

  private changeRisk(code: string, delta: number): void {
    const next: AdmissionRiskEvent[] = [];
    let found: boolean = false;
    for (let index: number = 0; index < this.riskEvents.length; index++) {
      if (this.riskEvents[index].code === code) {
        found = true;
        next.push({ code: code, count: Math.max(0, this.riskEvents[index].count + delta) });
      } else {
        next.push(this.riskEvents[index]);
      }
    }
    if (!found && delta > 0) {
      next.push({ code: code, count: delta });
    }
    this.riskEvents = next;
    this.markDirty(true);
  }

  private bedLabel(bed: Bed): string {
    return bed.room === undefined ? `床位 ${bed.bed_no} · #${bed.id}` :
      `${bed.room.building} ${bed.room.room_no} · ${bed.bed_no}床`;
  }

  private selectedBedLabel(): string {
    for (let index: number = 0; index < this.beds.length; index++) {
      if (this.beds[index].id === this.targetBedId) {
        return this.bedLabel(this.beds[index]);
      }
    }
    return this.targetBedId > 0 ? `床位 #${this.targetBedId}` : '未选择';
  }

  private selectedPlanName(): string {
    const plans: AdmissionCarePlanTemplate[] = this.plans();
    for (let index: number = 0; index < plans.length; index++) {
      if (plans[index].code === this.selectedCarePlanCode) {
        return plans[index].name;
      }
    }
    return '未选择';
  }

  private levelLabel(code: string): string {
    const levels: AdmissionLevelRule[] = this.levels();
    for (let index: number = 0; index < levels.length; index++) {
      if (levels[index].code === code) {
        return levels[index].label;
      }
    }
    return code;
  }

  private optionalServices(): AdmissionCareService[] {
    const plans: AdmissionCarePlanTemplate[] = this.plans();
    for (let index: number = 0; index < plans.length; index++) {
      if (plans[index].code === this.selectedCarePlanCode) {
        return plans[index].optional_services;
      }
    }
    return [];
  }

  private healthValue(category: string, code: string): string {
    return `${category}:${code}`;
  }

  private healthCategoryIsSingle(category: string): boolean {
    return category === 'pressure_injury' || category === 'joint_mobility' || category === 'pain' ||
      category === 'malnutrition' || category === 'airway_clearance';
  }

  private selectHealthValue(category: string, code: string): void {
    const prefix: string = `${category}:`;
    const target: string = this.healthValue(category, code);
    const next: string[] = [];
    const single: boolean = this.healthCategoryIsSingle(category);
    const selectingNone: boolean = code === 'none' || code === 'normal';
    let alreadySelected: boolean = false;
    for (let index: number = 0; index < this.healthIssues.length; index++) {
      const current: string = this.healthIssues[index];
      if (current === target) {
        alreadySelected = true;
      }
      if (!current.startsWith(prefix)) {
        next.push(current);
      } else if (!single && !selectingNone && current !== this.healthValue(category, 'none') && current !== target) {
        next.push(current);
      }
    }
    if (!alreadySelected || single) {
      next.push(target);
    }
    this.healthIssues = next;
    this.markDirty(true);
  }

  @Builder
  private stateView(symbol: Resource, title: string, description: string, action: string, onAction: () => void) {
    Column({ space: 12 }) {
      SymbolGlyph(symbol)
        .fontSize(34)
        .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
      Text(description)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 420 })
      if (action.length > 0) {
        Button(action)
          .height(38)
          .borderRadius(10)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .onClick(onAction)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private errorBanner() {
    if (this.errorMessage.length > 0) {
      Row({ space: 9 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
          .fontSize(15)
          .fontColor([$r('app.color.doctor_workspace_warning')])
        Column({ space: 2 }) {
          Text(this.errorKind === 'conflict' ? '数据状态已变化' :
            this.errorKind === 'missing' ? '草稿或配置已失效' : '操作未完成')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .width('100%')
          Text(this.errorMessage)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.errorKind === 'conflict' && this.draftId > 0) {
          Button('重新载入')
            .height(30)
            .fontSize(9)
            .borderRadius(8)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .onClick(() => this.openDraft(this.draftId))
        } else if (this.errorKind === 'missing') {
          Button('返回列表')
            .height(30)
            .fontSize(9)
            .borderRadius(8)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .onClick(() => {
              this.resetForm();
              this.view = 'drafts';
            })
        }
      }
      .width('100%')
      .padding(12)
      .borderRadius(10)
      .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_warning') })
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private draftsView() {
    Scroll() {
      Column({ space: 18 }) {
        Flex({ direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
          alignItems: this.compactWidth ? ItemAlign.Start : ItemAlign.Center }) {
          Column({ space: 4 }) {
            Text('入住评估')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width('100%')
            Text(`${this.templateLabel()} · 评估模板、草稿和结果均来自服务器`)
              .fontSize(10)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button('新建评估')
            .height(38)
            .borderRadius(10)
            .fontSize(11)
            .fontColor($r('app.color.doctor_workspace_background'))
            .backgroundColor($r('app.color.doctor_workspace_text_primary'))
            .margin({ top: this.compactWidth ? 10 : 0 })
            .onClick(() => this.startNew())
        }
        .width('100%')
        this.errorBanner()
        if (this.drafts.length === 0) {
          Column({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.person_badge_plus'))
              .fontSize(32)
              .fontColor([$r('app.color.doctor_workspace_text_tertiary')])
            Text('暂无未完成的入住评估')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text('新建后会使用服务器当前生效的评估模板。')
              .fontSize(10)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            Button('开始入住评估')
              .height(36)
              .borderRadius(9)
              .fontSize(10)
              .fontColor($r('app.color.doctor_workspace_background'))
              .backgroundColor($r('app.color.doctor_workspace_text_primary'))
              .onClick(() => this.startNew())
          }
          .width('100%')
          .constraintSize({ minHeight: 340 })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          ForEach(this.drafts, (draft: AdmissionAssessmentRecord) => {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.cross_case_fill'))
                .fontSize(22)
                .fontColor([$r('app.color.doctor_workspace_accent')])
              Column({ space: 3 }) {
                Text(draft.resident_name.length > 0 ? draft.resident_name : '未命名入住对象')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                  .width('100%')
                Text(`${draft.assessment_no} · 第 ${Math.min(draft.current_step + 1, this.steps.length)} 步`)
                  .fontSize(10)
                  .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text(this.operation === 'loading' ? '正在恢复' : '继续填写')
                .fontSize(10)
                .fontColor($r('app.color.doctor_workspace_focus'))
            }
            .width('100%')
            .padding(15)
            .borderRadius(11)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.openDraft(draft.id))
          }, (draft: AdmissionAssessmentRecord) => `${draft.id}`)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 1088 })
      .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 24 + this.contentTopInset,
        bottom: 32 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private formHeader() {
    Column({ space: 13 }) {
      Row({ space: 11 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(16)
            .fontColor([$r('app.color.doctor_workspace_text_primary')])
        }
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.doctor_workspace_surface'))
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
        .onClick(() => this.returnToDrafts())
        Column({ space: 3 }) {
          Text(this.residentName.length > 0 ? `${this.residentName} · 入住评估` : '新入住评估')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .width('100%')
          Text(this.assessmentNo.length > 0 ? `${this.assessmentNo} · ${this.templateLabel()}` : this.templateLabel())
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.operation.length > 0) {
          Text(this.operation === 'saving' ? '正在保存' : this.operation === 'previewing' ? '正在计分' : '正在提交')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_focus'))
        }
      }
      .width('100%')
      Scroll() {
        Row({ space: 7 }) {
          ForEach(this.steps, (step: string, index: number) => {
            Row({ space: 6 }) {
              Text(`${index + 1}`)
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(index <= this.currentStep ?
                  $r('app.color.doctor_workspace_background') : $r('app.color.doctor_workspace_text_tertiary'))
                .width(22)
                .height(22)
                .textAlign(TextAlign.Center)
                .borderRadius(11)
                .backgroundColor(index <= this.currentStep ?
                  $r('app.color.doctor_workspace_text_primary') : $r('app.color.doctor_workspace_surface_raised'))
              Text(step)
                .fontSize(10)
                .fontWeight(index === this.currentStep ? FontWeight.Bold : FontWeight.Regular)
                .fontColor(index === this.currentStep ?
                  $r('app.color.doctor_workspace_text_primary') : $r('app.color.doctor_workspace_text_tertiary'))
            }
            .padding({ left: 8, right: 10, top: 6, bottom: 6 })
            .borderRadius(17)
            .backgroundColor(index === this.currentStep ? $r('app.color.doctor_workspace_surface') : Color.Transparent)
          }, (step: string, index: number) => `${step}-${index}`)
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private heading(title: string, subtitle: string) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .width('100%')
      Text(subtitle)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 11 })
  }

  @Builder
  private input(label: string, value: string, placeholder: string, required: boolean,
    onChange: (value: string) => void, inputType: InputType = InputType.Normal) {
    Column({ space: 5 }) {
      Text(required ? `${label} *` : label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(required ? $r('app.color.doctor_workspace_text_primary') :
          $r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(39)
        .fontSize(11)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
        .borderRadius(8)
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
        .type(inputType)
        .onChange((next: string) => {
          onChange(next);
          this.markDirty();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private single(label: string, category: string, selected: string, required: boolean,
    onSelect: (code: string) => void) {
    Column({ space: 6 }) {
      Text(required ? `${label} *` : label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.dictionary(category), (option: AdmissionDictionaryOption) => {
          Text(option.label)
            .fontSize(10)
            .fontColor(selected === option.code ?
              $r('app.color.doctor_workspace_background') : $r('app.color.doctor_workspace_text_secondary'))
            .padding({ left: 11, right: 11, top: 7, bottom: 7 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor(selected === option.code ?
              $r('app.color.doctor_workspace_text_primary') : $r('app.color.doctor_workspace_surface_raised'))
            .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            .onClick(() => {
              onSelect(option.code);
              this.markDirty();
            })
        }, (option: AdmissionDictionaryOption) => `${category}-${option.code}`)
      }
      .width('100%')
      if (this.dictionary(category).length === 0) {
        Text('服务器未配置此项可选值')
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_warning'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private multiple(label: string, category: string, selected: string[], onChange: (values: string[]) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.dictionary(category), (option: AdmissionDictionaryOption) => {
          Text(option.label)
            .fontSize(10)
            .fontColor(this.contains(selected, option.code) ?
              $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_text_secondary'))
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
            .border({ width: this.contains(selected, option.code) ? 1.2 : 0.5,
              color: this.contains(selected, option.code) ?
                $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
            .onClick(() => {
              onChange(this.toggle(selected, option.code));
              this.markDirty();
            })
        }, (option: AdmissionDictionaryOption) => `${category}-${option.code}`)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private healthChoice(category: AdmissionHealthCategory) {
    Column({ space: 6 }) {
      Text(category.label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.dictionary(category.code), (option: AdmissionDictionaryOption) => {
          Text(option.label)
            .fontSize(10)
            .fontColor(this.contains(this.healthIssues, this.healthValue(category.code, option.code)) ?
              $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_text_secondary'))
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
            .border({ width: this.contains(this.healthIssues, this.healthValue(category.code, option.code)) ? 1.2 : 0.5,
              color: this.contains(this.healthIssues, this.healthValue(category.code, option.code)) ?
                $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
            .onClick(() => {
              this.selectHealthValue(category.code, option.code);
            })
        }, (option: AdmissionDictionaryOption) => `${category.code}-${option.code}`)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private basicStep() {
    Column({ space: 14 }) {
      this.heading('附录 A · 老年人能力评估基本信息表', '评估原因、基础资料、联系人、疾病用药、健康问题及近 30 天风险事件')
      Column() {
        this.heading('评估与身份资料', '带 * 的信息用于推进流程，未完成时仍可保存服务器草稿')
        GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.single('评估原因', 'assessment_reason', this.assessmentReason, true,
              (code: string) => this.assessmentReason = code)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('资料基准日期', this.baselineDate, 'YYYY-MM-DD', true,
              (value: string) => this.baselineDate = value)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('姓名', this.residentName, '长者姓名', true, (value: string) => this.residentName = value)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.single('性别', 'gender', this.gender, true, (code: string) => this.gender = code)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('出生日期', this.birthDate, 'YYYY-MM-DD', true, (value: string) => this.birthDate = value)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('证件号码', this.idCard, '身份证或其他证件号', true, (value: string) => this.idCard = value)
          }
          GridCol({ span: this.compactWidth ? 6 : 3 }) {
            this.input('身高（cm）', this.heightText, '0', true,
              (value: string) => this.heightText = value, InputType.Number)
          }
          GridCol({ span: this.compactWidth ? 6 : 3 }) {
            this.input('体重（kg）', this.weightText, '0', true,
              (value: string) => this.weightText = value)
          }
          GridCol({ span: this.compactWidth ? 6 : 3 }) {
            this.single('民族', 'ethnicity', this.ethnicity, false, (code: string) => this.ethnicity = code)
          }
          GridCol({ span: this.compactWidth ? 6 : 3 }) {
            this.single('宗教信仰', 'religion', this.religion, false, (code: string) => this.religion = code)
          }
          GridCol({ span: 12 }) {
            this.input('评估地点', this.assessmentLocation, '机构、房间或其他地点', true,
              (value: string) => this.assessmentLocation = value)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.heading('社会与保障资料', '多选项目可按实际情况同时勾选')
        GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.single('文化程度', 'education', this.education, false, (code: string) => this.education = code)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.single('婚姻状况', 'marital_status', this.maritalStatus, false,
              (code: string) => this.maritalStatus = code)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.multiple('居住情况', 'living_situation', this.livingSituations,
              (values: string[]) => this.livingSituations = values)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.multiple('医疗费用支付方式', 'medical_payment', this.medicalPayments,
              (values: string[]) => this.medicalPayments = values)
          }
          GridCol({ span: 12 }) {
            this.multiple('经济来源', 'income_source', this.incomeSources,
              (values: string[]) => this.incomeSources = values)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 11 }) {
        this.heading('疾病、用药与健康问题', '疾病用逗号分隔；每行用药按“药名|用法|剂量|频次”填写')
        this.multiple('现患疾病', 'diagnosis', this.diagnoses,
          (values: string[]) => {
            this.diagnoses = values;
            this.dementiaOrMentalDisorder = values.indexOf('F00-F03') >= 0 || values.indexOf('F04-F99') >= 0;
            this.markDirty(true);
          })
        Row({ space: 10 }) {
          Toggle({ type: ToggleType.Switch, isOn: this.dementiaOrMentalDisorder })
            .selectedColor($r('app.color.doctor_workspace_focus'))
            .onChange((value: boolean) => {
              this.dementiaOrMentalDisorder = value;
              this.markDirty(true);
            })
          Column({ space: 2 }) {
            Text('存在痴呆或精神行为障碍')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
            Text('服务器会按正式规则判断是否调整最终等级')
              .fontSize(9)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        this.single('昏迷状态', 'coma_status', this.coma ? 'present' : 'none', false,
          (code: string) => {
            this.coma = code === 'present';
            this.markDirty(true);
          })
        GridRow({ columns: 12, gutter: { x: 10, y: 10 } }) {
          ForEach(this.healthCategories(), (category: AdmissionHealthCategory) => {
            GridCol({ span: this.compactWidth ? 12 : 6 }) {
              this.healthChoice(category)
            }
          }, (category: AdmissionHealthCategory) => category.code)
        }
        .width('100%')
        TextArea({ text: this.medicationsText, placeholder: '阿司匹林|口服|100mg|每日一次' })
          .width('100%')
          .height(92)
          .fontSize(10)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .borderRadius(8)
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .onChange((value: string) => {
            this.medicationsText = value;
            this.markDirty();
          })
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.heading('近 30 天风险事件', '按实际发生次数记录；服务器结合次数执行等级调整规则')
        GridRow({ columns: 12, gutter: { x: 9, y: 9 } }) {
          ForEach(this.dictionary('risk_event'), (option: AdmissionDictionaryOption) => {
            GridCol({ span: this.compactWidth ? 12 : 6 }) {
              Row({ space: 8 }) {
                Text(option.label)
                  .fontSize(10)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                  .layoutWeight(1)
                Button('-')
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .fontSize(13)
                  .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
                  .enabled(this.riskCount(option.code) > 0)
                  .onClick(() => this.changeRisk(option.code, -1))
                Text(`${this.riskCount(option.code)}`)
                  .width(24)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center)
                Button('+')
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .fontSize(13)
                  .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
                  .onClick(() => this.changeRisk(option.code, 1))
              }
              .width('100%')
              .padding(9)
              .borderRadius(9)
              .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
              .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
            }
          }, (option: AdmissionDictionaryOption) => `risk-${option.code}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.heading('信息提供人与联系人', '信息提供人需在最终确认时完成签字确认')
        GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('信息提供人', this.infoProviderName, '姓名', true,
              (value: string) => this.infoProviderName = value)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.single('与长者关系', 'info_provider_relation', this.infoProviderRelation, true,
              (code: string) => this.infoProviderRelation = code)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('主要联系人', this.contactName, '姓名', true, (value: string) => this.contactName = value)
          }
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            this.input('联系电话', this.contactPhone, '手机号或固定电话', true,
              (value: string) => this.contactPhone = value, InputType.PhoneNumber)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)
      if (!this.basicReady()) {
        Text('请补全带 * 的项目，日期使用 YYYY-MM-DD。草稿仍可随时保存。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private question(question: AdmissionAssessmentQuestion) {
    Column({ space: 9 }) {
      Row({ space: 7 }) {
        Text(question.code)
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_focus'))
        Text(question.title)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      if (question.guidance.length > 0) {
        Text(question.guidance)
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .width('100%')
          .lineHeight(14)
      }
      ForEach(question.options, (option: AdmissionAssessmentOption) => {
        Row({ space: 8 }) {
          Row()
            .width(17)
            .height(17)
            .borderRadius(9)
            .border({ width: this.optionId(question.id) === option.id ? 5 : 1,
              color: this.optionId(question.id) === option.id ?
                $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
          Text(option.label)
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .layoutWeight(1)
            .lineHeight(15)
        }
        .width('100%')
        .padding(8)
        .borderRadius(8)
        .backgroundColor(this.optionId(question.id) === option.id ?
          $r('app.color.doctor_workspace_accent_soft') : $r('app.color.doctor_workspace_surface_raised'))
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border_soft') })
        .onClick(() => this.selectAnswer(question.id, option.id))
      }, (option: AdmissionAssessmentOption) => `${question.id}-${option.id}`)
    }
    .width('100%')
    .padding(14)
    .borderRadius(11)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: this.optionId(question.id) > 0 ? 0.5 : 1,
      color: this.optionId(question.id) > 0 ?
        $r('app.color.doctor_workspace_border') : $r('app.color.doctor_workspace_warning') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private assessmentStep() {
    Column({ space: 16 }) {
      this.heading('附录 B · 老年人能力评估表',
        `服务器题库 ${this.questions().length} 项、${this.groupCodes().length} 个维度；已完成 ${this.completedQuestions()} 项`)
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.shield_checkered'))
          .fontSize(15)
          .fontColor([$r('app.color.doctor_workspace_focus')])
        Text('客户端只提交题目与选项 ID，不计算或提交可信分数。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(11)
      .borderRadius(9)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      ForEach(this.groupCodes(), (groupCode: string) => {
        Column({ space: 10 }) {
          Row() {
            Text(this.groupName(groupCode))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .layoutWeight(1)
            Text(`${this.questionsForGroup(groupCode).length} 项`)
              .fontSize(10)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          }
          .width('100%')
          GridRow({ columns: 12, gutter: { x: 11, y: 11 } }) {
            ForEach(this.questionsForGroup(groupCode), (item: AdmissionAssessmentQuestion) => {
              GridCol({ span: this.compactWidth ? 12 : 6 }) {
                this.question(item)
              }
            }, (item: AdmissionAssessmentQuestion) => `${item.id}`)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (groupCode: string) => groupCode)
      if (!this.assessmentReady()) {
        Text(`还有 ${this.questions().length - this.completedQuestions()} 项未完成。`)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private levelStrip() {
    if (this.levels().length === 0) {
      Text('服务器未返回五档等级规则，请检查当前模板配置。')
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_warning'))
        .width('100%')
        .padding(11)
        .borderRadius(9)
        .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
    } else {
      GridRow({ columns: 10, gutter: { x: 7, y: 7 } }) {
        ForEach(this.levels(), (level: AdmissionLevelRule) => {
          GridCol({ span: this.compactWidth ? 5 : 2 }) {
            Column({ space: 3 }) {
              Text(level.label)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.preview !== null && this.preview.final_level === level.code ?
                  $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_text_primary'))
              Text(level.min_score === level.max_score ? `${level.min_score} 分` :
                `${level.min_score}-${level.max_score} 分`)
                .fontSize(9)
                .fontColor($r('app.color.doctor_workspace_text_tertiary'))
            }
            .width('100%')
            .height(58)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(9)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: this.preview !== null && this.preview.final_level === level.code ? 1.2 : 0.5,
              color: this.preview !== null && this.preview.final_level === level.code ?
                $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
          }
        }, (level: AdmissionLevelRule) => level.code)
      }
      .width('100%')
    }
  }

  @Builder
  private resultStep() {
    Column({ space: 16 }) {
      this.heading('附录 C · 老年人能力评估报告', '总分、初始等级、最终等级和调整原因只显示服务端计算结果')
      if (this.preview === null) {
        Column({ space: 9 }) {
          Text('尚未取得服务端评估结果')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Button(this.operation === 'previewing' ? '正在计分' : '请求服务端计分')
            .height(36)
            .fontSize(10)
            .borderRadius(9)
            .fontColor($r('app.color.doctor_workspace_background'))
            .backgroundColor($r('app.color.doctor_workspace_text_primary'))
            .enabled(this.operation.length === 0)
            .onClick(() => this.requestPreview())
        }
        .width('100%')
        .padding(22)
        .borderRadius(12)
        .backgroundColor($r('app.color.doctor_workspace_surface'))
        .alignItems(HorizontalAlign.Center)
      } else {
        GridRow({ columns: 12, gutter: { x: 10, y: 10 } }) {
          GridCol({ span: this.compactWidth ? 12 : 4 }) {
            this.metric('能力总分', `${this.preview.ability_score} / ${this.bootstrap?.template.max_score ?? 0}`, false)
          }
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.metric('初始等级', this.preview.initial_level_label, false)
          }
          GridCol({ span: this.compactWidth ? 6 : 4 }) {
            this.metric('最终等级', this.preview.final_level_label, true)
          }
        }
        .width('100%')
        GridRow({ columns: 12, gutter: { x: 8, y: 8 } }) {
          ForEach(this.preview.group_scores, (group: AdmissionGroupScore) => {
            GridCol({ span: this.compactWidth ? 6 : 3 }) {
              Column({ space: 3 }) {
                Text(group.label)
                  .fontSize(9)
                  .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${group.score} / ${group.max_score}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
              }
              .width('100%')
              .padding(9)
              .borderRadius(8)
              .backgroundColor($r('app.color.doctor_workspace_surface'))
              .alignItems(HorizontalAlign.Center)
            }
          }, (group: AdmissionGroupScore) => group.code)
        }
        .width('100%')
        if (this.preview.level_change_reasons.length > 0) {
          Column({ space: 4 }) {
            Text('等级调整依据')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width('100%')
            ForEach(this.preview.level_change_reasons, (reason: string) => {
              Text(`· ${reason}`)
                .fontSize(10)
                .fontColor($r('app.color.doctor_workspace_text_secondary'))
                .width('100%')
            }, (reason: string) => reason)
          }
          .width('100%')
          .padding(11)
          .borderRadius(9)
          .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
          .alignItems(HorizontalAlign.Start)
        }
      }
      this.levelStrip()
      if (this.scoringNotes().length > 0) {
        Column({ space: 4 }) {
          ForEach(this.scoringNotes(), (note: string) => {
            Text(`· ${note}`)
              .fontSize(9)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
              .width('100%')
          }, (note: string) => note)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      if (this.draftId > 0) {
        AdmissionScreeningPanel({
          admissionId: this.draftId,
          compactWidth: this.compactWidth
        })
      }
      this.heading('护理计划', '选择服务器配置的计划；提交后由服务器生成正式关联记录')
      GridRow({ columns: 12, gutter: { x: 10, y: 10 } }) {
        ForEach(this.plans(), (plan: AdmissionCarePlanTemplate) => {
          GridCol({ span: this.compactWidth ? 12 : 6 }) {
            Column({ space: 7 }) {
              Row() {
                Text(plan.name)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.doctor_workspace_text_primary'))
                  .layoutWeight(1)
                Row()
                  .width(19)
                  .height(19)
                  .borderRadius(10)
                  .border({ width: this.selectedCarePlanCode === plan.code ? 6 : 1,
                    color: this.selectedCarePlanCode === plan.code ?
                      $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
              }
              .width('100%')
              Text(plan.target)
                .fontSize(9)
                .fontColor($r('app.color.doctor_workspace_text_tertiary'))
                .width('100%')
              Text(`基础服务 ${plan.base_services.length} 项 · 可选服务 ${plan.optional_services.length} 项`)
                .fontSize(9)
                .fontColor($r('app.color.doctor_workspace_text_secondary'))
                .width('100%')
            }
            .width('100%')
            .padding(13)
            .borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
            .border({ width: this.selectedCarePlanCode === plan.code ? 1.2 : 0.5,
              color: this.selectedCarePlanCode === plan.code ?
                $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
            .alignItems(HorizontalAlign.Start)
            .enabled(this.preview !== null && plan.target_level === this.preview.final_level)
            .opacity(this.preview !== null && plan.target_level === this.preview.final_level ? 1 : 0.48)
            .onClick(() => {
              if (this.preview !== null && plan.target_level === this.preview.final_level) {
                if (this.selectedCarePlanCode !== plan.code) {
                  this.selectedOptionalServices = [];
                }
                this.selectedCarePlanCode = plan.code;
                this.markDirty();
              }
            })
          }
        }, (plan: AdmissionCarePlanTemplate) => plan.code)
      }
      .width('100%')
      if (this.optionalServices().length > 0) {
        Column({ space: 7 }) {
          Text('可选服务')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.optionalServices(), (service: AdmissionCareService) => {
              Text(`${service.title} · ${service.frequency}`)
                .fontSize(10)
                .fontColor(this.contains(this.selectedOptionalServices, service.code) ?
                  $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_text_secondary'))
                .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .margin({ right: 7, bottom: 7 })
                .borderRadius(8)
                .backgroundColor($r('app.color.doctor_workspace_surface'))
                .border({ width: this.contains(this.selectedOptionalServices, service.code) ? 1.2 : 0.5,
                  color: this.contains(this.selectedOptionalServices, service.code) ?
                    $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
                .onClick(() => {
                  this.selectedOptionalServices = this.toggle(this.selectedOptionalServices, service.code);
                  this.markDirty();
                })
            }, (service: AdmissionCareService) => service.code)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      this.heading('入住床位', '只显示服务器当前空闲床位，提交时会再次检查占用冲突')
      if (this.beds.length === 0) {
        Text('当前没有可分配床位，或床位数据加载失败。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .width('100%')
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.beds, (bed: Bed) => {
            Text(this.bedLabel(bed))
              .fontSize(10)
              .fontColor(this.targetBedId === bed.id ?
                $r('app.color.doctor_workspace_background') : $r('app.color.doctor_workspace_text_secondary'))
              .padding({ left: 11, right: 11, top: 8, bottom: 8 })
              .margin({ right: 7, bottom: 7 })
              .borderRadius(8)
              .backgroundColor(this.targetBedId === bed.id ?
                $r('app.color.doctor_workspace_text_primary') : $r('app.color.doctor_workspace_surface'))
              .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
              .onClick(() => {
                this.targetBedId = bed.id;
                this.markDirty();
              })
          }, (bed: Bed) => `${bed.id}`)
        }
        .width('100%')
      }
      if (!this.planReady()) {
        Text('取得服务端结果并选择护理计划、空闲床位后才能继续。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private metric(label: string, value: string, focused: boolean) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(focused ? $r('app.color.doctor_workspace_focus') :
          $r('app.color.doctor_workspace_text_primary'))
    }
    .width('100%')
    .height(96)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(11)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: focused ? 1.2 : 0.5,
      color: focused ? $r('app.color.doctor_workspace_focus') : $r('app.color.doctor_workspace_border') })
  }

  @Builder
  private confirmation(label: string, description: string, checked: boolean, onChange: (value: boolean) => void) {
    Row({ space: 11 }) {
      Checkbox()
        .select(checked)
        .selectedColor($r('app.color.doctor_workspace_focus'))
        .onChange((value: boolean) => {
          onChange(value);
          this.markDirty();
        })
      Column({ space: 3 }) {
        Text(label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .width('100%')
        Text(description)
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private summary(label: string, value: string) {
    Row({ space: 9 }) {
      Text(label)
        .width(72)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      Text(value.length > 0 ? value : '未填写')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.doctor_workspace_text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .border({ width: { bottom: 0.5 }, color: { bottom: $r('app.color.doctor_workspace_border_soft') } })
  }

  @Builder
  private confirmStep() {
    Column({ space: 15 }) {
      this.heading('入住确认', '正式提交将创建长者档案、占用床位并生成护理计划，请再次核对')
      GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
        GridCol({ span: this.compactWidth ? 12 : 5 }) {
          Column({ space: 3 }) {
            Text('提交摘要')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width('100%')
            this.summary('长者', this.residentName)
            this.summary('资料日期', this.baselineDate)
            this.summary('能力总分', this.preview === null ? '未取得' : `${this.preview.ability_score} 分`)
            this.summary('最终等级', this.preview === null ? '未取得' : this.preview.final_level_label)
            this.summary('护理计划', this.selectedPlanName())
            this.summary('床位', this.selectedBedLabel())
          }
          .width('100%')
          .padding(15)
          .borderRadius(11)
          .backgroundColor($r('app.color.doctor_workspace_surface'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .alignItems(HorizontalAlign.Start)
        }
        GridCol({ span: this.compactWidth ? 12 : 7 }) {
          Column() {
            Text('建档前确认')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.doctor_workspace_text_primary'))
              .width('100%')
            this.confirmation('医师已复核评估资料与服务端结果', '资料完整、答案与现场情况一致。',
              this.doctorConfirmed, (value: boolean) => this.doctorConfirmed = value)
            this.confirmation('长者或代理人已知情并同意护理计划', '已说明评估结论、护理计划及复评安排。',
              this.planConsentConfirmed, (value: boolean) => this.planConsentConfirmed = value)
            this.confirmation('服务内容和费用标准已完成告知', '最终内容与费用以双方服务协议为准。',
              this.serviceFeeInformed, (value: boolean) => this.serviceFeeInformed = value)
            this.confirmation('信息提供人已核对并签字确认', '确认基础资料、疾病用药和风险事件准确。',
              this.infoProviderSigned, (value: boolean) => this.infoProviderSigned = value)
          }
          .width('100%')
          .padding(15)
          .borderRadius(11)
          .backgroundColor($r('app.color.doctor_workspace_surface'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
          .fontSize(15)
          .fontColor([$r('app.color.doctor_workspace_warning')])
        Text('服务器会重新校验题库、身份、床位和草稿状态，冲突不会覆盖其他人员的数据。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(11)
      .borderRadius(9)
      .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
      if (!this.confirmationsReady()) {
        Text('请完成四项确认后正式提交。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stepContent() {
    if (this.currentStep === 0) {
      this.basicStep()
    } else if (this.currentStep === 1) {
      this.assessmentStep()
    } else if (this.currentStep === 2) {
      this.resultStep()
    } else {
      this.confirmStep()
    }
  }

  @Builder
  private footer() {
    Flex({ direction: this.compactWidth ? FlexDirection.Column : FlexDirection.Row,
      alignItems: this.compactWidth ? ItemAlign.Start : ItemAlign.Center }) {
      Text(`第 ${this.currentStep + 1} / ${this.steps.length} 步 · ${this.steps[this.currentStep]}`)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .layoutWeight(this.compactWidth ? 0 : 1)
        .width(this.compactWidth ? '100%' : undefined)
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
        if (this.currentStep > 0) {
          Button('上一步')
            .height(37)
            .fontSize(10)
            .borderRadius(9)
            .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
            .margin({ right: 9, bottom: this.compactWidth ? 6 : 0 })
            .enabled(this.operation.length === 0)
            .onClick(() => this.previous())
        }
        Button(this.operation === 'saving' ? '正在保存' : '保存草稿')
          .height(37)
          .fontSize(10)
          .borderRadius(9)
          .backgroundColor($r('app.color.doctor_workspace_surface'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .margin({ right: 9, bottom: this.compactWidth ? 6 : 0 })
          .enabled(this.operation.length === 0)
          .onClick(() => this.saveDraft())
        Button(this.currentStep === this.steps.length - 1 ?
          (this.operation === 'submitting' ? '正在提交' : '正式提交入住') : '下一步')
          .height(37)
          .fontSize(10)
          .borderRadius(9)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .enabled(this.stepReady() && this.operation.length === 0)
          .opacity(this.stepReady() && this.operation.length === 0 ? 1 : 0.42)
          .onClick(() => this.next())
      }
      .width(this.compactWidth ? '100%' : undefined)
      .justifyContent(FlexAlign.End)
      .margin({ top: this.compactWidth ? 8 : 0 })
    }
    .width('100%')
    .constraintSize({ maxWidth: 1136 })
    .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 10, bottom: 10 + this.naviIndicatorHeight })
  }

  @Builder
  private formView() {
    Column() {
      Scroll(this.contentScroller) {
        Column({ space: 17 }) {
          this.formHeader()
          this.errorBanner()
          this.stepContent()
        }
        .width('100%')
        .constraintSize({ maxWidth: 1088 })
        .padding({ left: this.mainPadding(), right: this.mainPadding(), top: 20 + this.contentTopInset, bottom: 24 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      Column() {
        this.footer()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .border({ width: { top: 0.5 }, color: { top: $r('app.color.doctor_workspace_border_soft') } })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private submittedView() {
    if (this.submitResult === null) {
      this.stateView($r('sys.symbol.exclamationmark_triangle'), '提交结果缺失', '请返回草稿列表刷新状态。', '返回列表', () => {
        this.resetForm();
        this.view = 'drafts';
      })
    } else {
      Column({ space: 13 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(54)
          .fontColor([$r('app.color.doctor_workspace_success')])
        Text('入住评估已正式提交')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Text(`${this.residentName} · ${this.submitResult.admission.assessment_no}`)
          .fontSize(11)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
        Text(`能力总分 ${this.submitResult.admission.ability_score} · ${this.levelLabel(this.submitResult.admission.final_level)} · 长者档案 #${this.submitResult.admission.elder_id ?? 0}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_focus'))
        Text('服务器已在同一事务中完成评估、长者档案、床位和护理计划关联。')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .textAlign(TextAlign.Center)
        Row({ space: 10 }) {
          Button('再评估一位')
            .height(37)
            .fontSize(10)
            .borderRadius(9)
            .backgroundColor($r('app.color.doctor_workspace_surface'))
              .onClick(() => this.startNew())
          Button('返回工作台')
            .height(37)
            .fontSize(10)
            .borderRadius(9)
            .fontColor($r('app.color.doctor_workspace_background'))
            .backgroundColor($r('app.color.doctor_workspace_text_primary'))
            .onClick(() => {
              this.resetForm();
              if (this.standaloneMode) {
                this.view = 'drafts';
                this.refreshDrafts();
              } else {
                this.onExit();
              }
            })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    Column() {
      if (this.view === 'loading') {
        this.stateView($r('sys.symbol.arrow_clockwise'), '正在读取入住评估',
          '正在加载服务器题库、草稿和空闲床位。', '', () => this.loadWorkspace())
      } else if (this.view === 'error') {
        this.stateView(this.errorKind === 'session' ? $r('sys.symbol.lock_fill') :
          $r('sys.symbol.exclamationmark_triangle'), this.errorKind === 'session' ? '登录会话已过期' : '入住评估暂不可用',
          this.errorKind === 'session' ? '请退出后重新登录，再继续评估。' : this.errorMessage,
          this.errorKind === 'session' ? '返回工作台' : '重试',
          this.errorKind === 'session' ? () => this.onExit() : () => this.loadWorkspace())
      } else if (this.view === 'drafts') {
        this.draftsView()
      } else if (this.view === 'submitted') {
        this.submittedView()
      } else {
        this.formView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.doctor_workspace_background'))
  }
}
