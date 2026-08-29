/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import {
  AdmissionAssessmentOption,
  AdmissionAssessmentQuestion,
  AdmissionScreening,
  AdmissionScreeningAnswerInput,
  AdmissionScreeningPayload,
  AdmissionScreeningSaveResult,
  AdmissionScreeningStoredAnswer,
  AdmissionScreeningTemplate
} from '../../network/AdmissionApi';
import AdmissionRepository, { AdmissionFailureKind, AdmissionResult } from '../../network/AdmissionRepository';

/**
 * 入住评估附加筛查。量表、题目、选项和评分均来自服务器；这些筛查是可选的，
 * 不参与附录 B/C 能力等级计算，也不会改变入住主流程的步骤状态。
 */
@ComponentV2
export struct AdmissionScreeningPanel {
  @Param @Require admissionId: number;
  @Param compactWidth: boolean = false;

  @Local templates: AdmissionScreeningTemplate[] = [];
  @Local screenings: AdmissionScreening[] = [];
  @Local selectedCode: string = '';
  @Local answers: AdmissionScreeningAnswerInput[] = [];
  @Local educationText: string = '';
  @Local notes: string = '';
  @Local loading: boolean = true;
  @Local operation: string = '';
  @Local errorKind: AdmissionFailureKind = 'none';
  @Local errorMessage: string = '';
  @Local dirty: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorKind = 'none';
    this.errorMessage = '';
    if (this.admissionId <= 0) {
      this.loading = false;
      this.errorKind = 'validation';
      this.errorMessage = '保存入住评估草稿后才能填写可选筛查。';
      return;
    }
    const templateResult: AdmissionResult<AdmissionScreeningTemplate[]> =
      await AdmissionRepository.screeningTemplates();
    if (!templateResult.ok || templateResult.data === undefined) {
      this.loading = false;
      this.setError(templateResult.kind, templateResult.message);
      return;
    }
    this.templates = templateResult.data;
    const screeningResult: AdmissionResult<AdmissionScreening[]> =
      await AdmissionRepository.listScreenings(this.admissionId);
    if (screeningResult.ok && screeningResult.data !== undefined) {
      this.screenings = screeningResult.data;
    } else {
      this.screenings = [];
      this.setError(screeningResult.kind, `已加载量表，但历史筛查记录读取失败：${screeningResult.message}`);
    }
    this.loading = false;
    if (this.templates.length > 0) {
      this.hydrate(this.selectedCode.length > 0 ? this.selectedCode : this.templates[0].code);
      if (!screeningResult.ok) {
        this.setError(screeningResult.kind, `已加载量表，但历史筛查记录读取失败：${screeningResult.message}`);
      }
    }
  }

  private setError(kind: AdmissionFailureKind, message: string): void {
    this.errorKind = kind;
    this.errorMessage = message.length > 0 ? message : '筛查操作失败';
  }

  private clearError(): void {
    this.errorKind = 'none';
    this.errorMessage = '';
  }

  private selectedTemplate(): AdmissionScreeningTemplate | undefined {
    for (let index: number = 0; index < this.templates.length; index++) {
      if (this.templates[index].code === this.selectedCode) {
        return this.templates[index];
      }
    }
    return undefined;
  }

  private screeningFor(code: string): AdmissionScreening | undefined {
    for (let index: number = 0; index < this.screenings.length; index++) {
      if (this.screenings[index].template_code === code) {
        return this.screenings[index];
      }
    }
    return undefined;
  }

  private selectedTemplateOrFirst(): AdmissionScreeningTemplate {
    const selected: AdmissionScreeningTemplate | undefined = this.selectedTemplate();
    return selected === undefined ? this.templates[0] : selected;
  }

  private hydrate(code: string): void {
    this.selectedCode = code;
    const screening: AdmissionScreening | undefined = this.screeningFor(code);
    const restored: AdmissionScreeningAnswerInput[] = [];
    if (screening !== undefined) {
      const storedAnswers: AdmissionScreeningStoredAnswer[] = screening.answers ?? [];
      for (let index: number = 0; index < storedAnswers.length; index++) {
        const stored = storedAnswers[index];
        if (stored.option_id !== undefined && stored.option_id !== null) {
          restored.push({
            question_id: stored.question_id,
            option_id: stored.option_id,
            answer_text: stored.answer_text ?? ''
          });
        }
      }
      this.educationText = screening.education_years === undefined || screening.education_years === null ?
        '' : `${screening.education_years}`;
      this.notes = screening.notes ?? '';
    } else {
      this.educationText = '';
      this.notes = '';
    }
    this.answers = restored;
    this.dirty = false;
  }

  private statusFor(code: string): string {
    const screening: AdmissionScreening | undefined = this.screeningFor(code);
    if (screening === undefined) {
      return '未开始';
    }
    return screening.status === 'completed' ? '已完成' : '草稿';
  }

  private statusColor(code: string): ResourceColor {
    const screening: AdmissionScreening | undefined = this.screeningFor(code);
    if (screening !== undefined && screening.status === 'completed') {
      return $r('app.color.doctor_workspace_success');
    }
    if (screening !== undefined) {
      return $r('app.color.doctor_workspace_warning');
    }
    return $r('app.color.doctor_workspace_text_tertiary');
  }

  private answerOptionId(questionId: number): number {
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].question_id === questionId) {
        return this.answers[index].option_id;
      }
    }
    return 0;
  }

  private answerText(questionId: number): string {
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].question_id === questionId) {
        return this.answers[index].answer_text;
      }
    }
    return '';
  }

  private answerCount(template: AdmissionScreeningTemplate): number {
    let count: number = 0;
    for (let index: number = 0; index < template.questions.length; index++) {
      if (this.answerOptionId(template.questions[index].id) > 0) {
        count++;
      }
    }
    return count;
  }

  private requiredComplete(template: AdmissionScreeningTemplate): boolean {
    for (let index: number = 0; index < template.questions.length; index++) {
      const question: AdmissionAssessmentQuestion = template.questions[index];
      if (question.required && this.answerOptionId(question.id) <= 0) {
        return false;
      }
    }
    return true;
  }

  private needsEducation(template: AdmissionScreeningTemplate): boolean {
    for (let index: number = 0; index < template.scoring_notes.length; index++) {
      if (template.scoring_notes[index].indexOf('教育') >= 0) {
        return true;
      }
    }
    return false;
  }

  private selectOption(questionId: number, optionId: number): void {
    const next: AdmissionScreeningAnswerInput[] = [];
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].question_id !== questionId) {
        next.push(this.answers[index]);
      }
    }
    next.push({ question_id: questionId, option_id: optionId, answer_text: this.answerText(questionId) });
    this.answers = next;
    this.dirty = true;
    this.clearError();
  }

  private changeAnswerText(questionId: number, value: string): void {
    const next: AdmissionScreeningAnswerInput[] = [];
    let found: boolean = false;
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].question_id === questionId) {
        next.push({
          question_id: questionId,
          option_id: this.answers[index].option_id,
          answer_text: value
        });
        found = true;
      } else {
        next.push(this.answers[index]);
      }
    }
    if (!found) {
      next.push({ question_id: questionId, option_id: 0, answer_text: value });
    }
    this.answers = next;
    this.dirty = true;
  }

  private parseEducation(): number | undefined {
    const value: string = this.educationText.trim();
    if (value.length === 0) {
      return undefined;
    }
    const parsed: number = Number(value);
    if (!Number.isFinite(parsed) || !Number.isInteger(parsed) || parsed < 0 || parsed > 30) {
      return undefined;
    }
    return parsed;
  }

  private buildPayload(completed: boolean): AdmissionScreeningPayload {
    const persistedAnswers: AdmissionScreeningAnswerInput[] = [];
    for (let index: number = 0; index < this.answers.length; index++) {
      if (this.answers[index].option_id > 0) {
        persistedAnswers.push(this.answers[index]);
      }
    }
    const payload: AdmissionScreeningPayload = {
      completed: completed,
      notes: this.notes.trim(),
      answers: persistedAnswers
    };
    const education: number | undefined = this.parseEducation();
    if (education !== undefined) {
      payload.education_years = education;
    }
    return payload;
  }

  private async selectTemplate(code: string): Promise<void> {
    if (code === this.selectedCode || this.operation.length > 0) {
      return;
    }
    if (this.dirty && !await this.saveCurrent(false, false)) {
      return;
    }
    this.hydrate(code);
    this.clearError();
  }

  private async saveCurrent(completed: boolean, notify: boolean): Promise<boolean> {
    const template: AdmissionScreeningTemplate | undefined = this.selectedTemplate();
    if (template === undefined || this.admissionId <= 0) {
      return false;
    }
    if (this.parseEducation() === undefined && this.educationText.trim().length > 0) {
      this.setError('validation', '受教育年限请输入 0 至 30 的整数。');
      return false;
    }
    if (completed && !this.requiredComplete(template)) {
      this.setError('validation', `请先完成 ${template.questions.length} 项中的全部必答题。`);
      return false;
    }
    this.operation = completed ? 'completing' : 'saving';
    this.clearError();
    const result: AdmissionResult<AdmissionScreeningSaveResult> =
      await AdmissionRepository.saveScreening(this.admissionId, template.code, this.buildPayload(completed));
    this.operation = '';
    if (!result.ok || result.data === undefined) {
      this.setError(result.kind, result.message);
      return false;
    }
    const saved: AdmissionScreening = result.data.screening;
    const next: AdmissionScreening[] = [];
    let replaced: boolean = false;
    for (let index: number = 0; index < this.screenings.length; index++) {
      if (this.screenings[index].template_code === saved.template_code) {
        next.push(saved);
        replaced = true;
      } else {
        next.push(this.screenings[index]);
      }
    }
    if (!replaced) {
      next.push(saved);
    }
    this.screenings = next;
    this.hydrate(saved.template_code);
    if (notify) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: completed ? '筛查已由服务器完成评分' : '筛查草稿已保存到服务器'
        });
      } catch (_error) {
        // The component can be detached while the request completes.
      }
    }
    return true;
  }

  private resultSummary(template: AdmissionScreeningTemplate): string {
    const screening: AdmissionScreening | undefined = this.screeningFor(template.code);
    if (screening === undefined) {
      return '尚未保存记录';
    }
    if (screening.status !== 'completed') {
      return `草稿 · 已回答 ${this.answerCount(template)} / ${template.questions.length} 项`;
    }
    if (screening.result_label.length > 0) {
      return `服务器结果 · ${screening.result_label}`;
    }
    return `服务器已记录 · ${screening.adjusted_score} / ${template.max_score}`;
  }

  private scoreCapacityLabel(template: AdmissionScreeningTemplate): string {
    return template.max_score > 0 ? `满分 ${template.max_score}` : '不设总分';
  }

  @Builder
  private screeningListItem(template: AdmissionScreeningTemplate) {
    Row({ space: 8 }) {
      SymbolGlyph(template.code === this.selectedCode ? $r('sys.symbol.circle_fill') :
        $r('sys.symbol.circle'))
        .fontSize(10)
        .fontColor([this.statusColor(template.code)])
      Column({ space: 3 }) {
        Text(template.name)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${this.statusFor(template.code)} · ${template.questions.length} 项`)
          .fontSize(9)
          .fontColor(this.statusColor(template.code))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 9, right: 9, top: 10, bottom: 10 })
    .borderRadius(9)
    .backgroundColor(template.code === this.selectedCode ?
      $r('app.color.doctor_workspace_accent_soft') : $r('app.color.doctor_workspace_surface_raised'))
    .border({ width: template.code === this.selectedCode ? 1 : 0.5,
      color: template.code === this.selectedCode ? $r('app.color.doctor_workspace_focus') :
        $r('app.color.doctor_workspace_border_soft') })
    .onClick(() => this.selectTemplate(template.code))
  }

  @Builder
  private sidebar() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('可选筛查')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Text('根据服务端量表选择填写')
            .fontSize(9)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }
        .layoutWeight(1)
        if (this.loading) {
          LoadingProgress()
            .width(16)
            .height(16)
        }
      }
      .width('100%')
      ForEach(this.templates, (template: AdmissionScreeningTemplate) => {
        this.screeningListItem(template)
      }, (template: AdmissionScreeningTemplate) => template.code)
      Text('六项筛查均为可选记录，不影响附录 B 能力分数和附录 C 入住等级。')
        .fontSize(9)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .lineHeight(14)
        .width('100%')
    }
    .width('100%')
    .padding(13)
    .borderRadius(11)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private question(question: AdmissionAssessmentQuestion, index: number) {
    Column({ space: 8 }) {
      Row({ space: 7 }) {
        Text(`${index + 1}. ${question.title}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .layoutWeight(1)
          .lineHeight(16)
        Text(question.required ? '必答' : '可选')
          .fontSize(9)
          .fontColor(question.required ? $r('app.color.doctor_workspace_warning') :
            $r('app.color.doctor_workspace_text_tertiary'))
      }
      .width('100%')
      if (question.guidance.length > 0) {
        Text(question.guidance)
          .fontSize(9)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
          .lineHeight(14)
          .width('100%')
      }
      ForEach(question.options, (option: AdmissionAssessmentOption) => {
        Row({ space: 8 }) {
          Row()
            .width(16)
            .height(16)
            .borderRadius(8)
            .border({ width: this.answerOptionId(question.id) === option.id ? 5 : 1,
              color: this.answerOptionId(question.id) === option.id ?
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
        .backgroundColor(this.answerOptionId(question.id) === option.id ?
          $r('app.color.doctor_workspace_accent_soft') : $r('app.color.doctor_workspace_surface_raised'))
        .border({ width: 0.5, color: $r('app.color.doctor_workspace_border_soft') })
        .onClick(() => this.selectOption(question.id, option.id))
      }, (option: AdmissionAssessmentOption) => `${question.id}-${option.id}`)
      if (this.answerOptionId(question.id) > 0) {
        TextInput({ text: this.answerText(question.id), placeholder: '本题补充记录（可选）' })
          .height(35)
          .fontSize(9)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .onChange((value: string) => this.changeAnswerText(question.id, value))
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: question.required && this.answerOptionId(question.id) === 0 ? 1 : 0.5,
      color: question.required && this.answerOptionId(question.id) === 0 ?
        $r('app.color.doctor_workspace_warning') : $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private resultCard(template: AdmissionScreeningTemplate, screening: AdmissionScreening | undefined) {
    Column({ space: 5 }) {
      Row() {
        Text('服务端记录')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
          .layoutWeight(1)
        Text(screening === undefined ? '未开始' : this.statusFor(template.code))
          .fontSize(9)
          .fontColor(this.statusColor(template.code))
      }
      .width('100%')
      if (screening !== undefined && screening.status === 'completed') {
        if (template.max_score > 0) {
          Text(`原始记录 ${screening.raw_score} 分 · 校正记录 ${screening.adjusted_score} 分 · 满分 ${template.max_score}`)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .width('100%')
        } else {
          Text('服务器已保存各题原始答案，本量表不设总分。')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
            .width('100%')
        }
        Text(screening.result_label.length > 0 ? screening.result_label : '服务器已保存筛查分数')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_focus'))
          .width('100%')
      } else {
        Text(this.resultSummary(template))
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .width('100%')
      }
      Text('筛查结果仅供医师记录与后续复核，不构成临床诊断。')
        .fontSize(9)
        .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        .width('100%')
    }
    .width('100%')
    .padding(11)
    .borderRadius(9)
    .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private editor(template: AdmissionScreeningTemplate) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(template.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Text(`${template.version} · ${template.questions.length} 项 · ${this.scoreCapacityLabel(template)}`)
            .fontSize(9)
            .fontColor($r('app.color.doctor_workspace_text_tertiary'))
        }
        .layoutWeight(1)
        Text(`已回答 ${this.answerCount(template)} / ${template.questions.length}`)
          .fontSize(10)
          .fontColor(this.requiredComplete(template) ? $r('app.color.doctor_workspace_success') :
            $r('app.color.doctor_workspace_warning'))
      }
      .width('100%')
      Text(template.description)
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .lineHeight(15)
        .width('100%')
      this.resultCard(template, this.screeningFor(template.code))
      if (this.needsEducation(template)) {
        Column({ space: 5 }) {
          Text('受教育年限（服务器评分需要时填写）')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
            .width('100%')
          TextInput({ text: this.educationText, placeholder: '0 - 30 年，可留空' })
            .height(38)
            .fontSize(10)
            .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
            .onChange((value: string) => {
              this.educationText = value;
              this.dirty = true;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      ForEach(template.questions, (item: AdmissionAssessmentQuestion, index: number) => {
        this.question(item, index)
      }, (item: AdmissionAssessmentQuestion) => `${template.code}-${item.id}`)
      Column({ space: 5 }) {
        Text('医师备注（可选）')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
          .width('100%')
        TextArea({ text: this.notes, placeholder: '记录需要后续复核的现场观察或补充说明' })
          .height(76)
          .fontSize(10)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .onChange((value: string) => {
            this.notes = value;
            this.dirty = true;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      if (template.scoring_notes.length > 0) {
        Column({ space: 3 }) {
          ForEach(template.scoring_notes, (note: string) => {
            Text(`· ${note}`)
              .fontSize(9)
              .fontColor($r('app.color.doctor_workspace_text_tertiary'))
              .width('100%')
          }, (note: string) => note)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      Row({ space: 8 }) {
        Button(this.operation === 'saving' ? '正在保存' : '保存草稿')
          .height(36)
          .fontSize(10)
          .borderRadius(9)
          .backgroundColor($r('app.color.doctor_workspace_surface_raised'))
          .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
          .enabled(this.operation.length === 0)
          .onClick(() => this.saveCurrent(false, true))
        Button(this.operation === 'completing' ? '正在评分' : '完成并评分')
          .height(36)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_background'))
          .backgroundColor($r('app.color.doctor_workspace_text_primary'))
          .enabled(this.operation.length === 0 && this.requiredComplete(template))
          .opacity(this.operation.length === 0 && this.requiredComplete(template) ? 1 : 0.42)
          .onClick(() => this.saveCurrent(true, true))
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(15)
    .borderRadius(11)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private errorBanner() {
    if (this.errorMessage.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
          .fontSize(14)
          .fontColor([$r('app.color.doctor_workspace_warning')])
        Text(this.errorMessage)
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_warning'))
          .layoutWeight(1)
          .lineHeight(15)
      }
      .width('100%')
      .padding(10)
      .borderRadius(9)
      .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
    }
  }

  @Builder
  private body() {
    if (this.loading) {
      Row({ space: 8 }) {
        LoadingProgress()
          .width(18)
          .height(18)
        Text('正在读取服务器筛查量表…')
          .fontSize(10)
          .fontColor($r('app.color.doctor_workspace_text_secondary'))
      }
      .width('100%')
      .padding(18)
      .justifyContent(FlexAlign.Center)
    } else if (this.templates.length === 0) {
      Text('服务器尚未配置可选筛查量表。')
        .fontSize(10)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
        .width('100%')
        .padding(18)
        .textAlign(TextAlign.Center)
    } else {
      GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
        GridCol({ span: this.compactWidth ? 12 : 4 }) {
          this.sidebar()
        }
        GridCol({ span: this.compactWidth ? 12 : 8 }) {
          this.editor(this.selectedTemplateOrFirst())
        }
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('附加筛查（可选）')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.doctor_workspace_text_primary'))
          Text('筛查记录单独保存到服务器，不改变附录 B/C 等级与入住确认条件')
            .fontSize(10)
            .fontColor($r('app.color.doctor_workspace_text_secondary'))
        }
        .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(16)
          .fontColor([$r('app.color.doctor_workspace_focus')])
      }
      .width('100%')
      this.errorBanner()
      this.body()
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(HorizontalAlign.Start)
  }
}
