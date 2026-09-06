import { AdmissionApi, AdmissionAssessmentRecord, AdmissionMedication } from '../../network/AdmissionApi';

interface CaseLevelStyle {
  label: string;
  color: ResourceColor;
  background: ResourceColor;
}

/**
 * 医师端「病例」页：机构已提交的入院评估病历目录与详情。
 * 数据全部来自 /admission-assessments 只读接口，页面内不做任何本地编造。
 */
@ComponentV2
export struct WideDoctorCasesPage {
  @Param compactWidth: boolean = false;
  @Param topBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Local cases: AdmissionAssessmentRecord[] = [];
  @Local casesLoading: boolean = false;
  @Local caseSearch: string = '';
  @Local selectedCaseId: number = 0;
  @Local caseDetail: AdmissionAssessmentRecord | undefined = undefined;
  @Local detailLoading: boolean = false;

  aboutToAppear(): void {
    this.loadCases();
  }

  /** 页级提示统一走系统 Toast：白底、短暂显示后自动消失。 */
  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (_error) {
      // Toast 展示失败时静默，不打断页面。
    }
  }

  private async loadCases(): Promise<void> {
    this.casesLoading = true;
    try {
      const response = await AdmissionApi.listCases();
      if (response.code !== 0 || response.data === undefined) {
        this.showToast(response.msg.length > 0 ? response.msg : '病例列表获取失败');
        this.cases = [];
      } else {
        this.cases = response.data.list ?? [];
      }
    } catch (error) {
      this.showToast(error instanceof Error && error.message.length > 0 ? error.message : '病例列表获取失败');
      this.cases = [];
    }
    this.casesLoading = false;
  }

  private async openCase(id: number): Promise<void> {
    this.selectedCaseId = id;
    this.detailLoading = true;
    try {
      const response = await AdmissionApi.getAssessment(id);
      if (response.code !== 0 || response.data === undefined) {
        this.showToast(response.msg.length > 0 ? response.msg : '病例详情获取失败');
      } else {
        this.caseDetail = response.data;
      }
    } catch (_error) {
      this.showToast('病例详情获取失败，请检查网络');
    }
    this.detailLoading = false;
  }

  private visibleCases(): AdmissionAssessmentRecord[] {
    const query: string = this.caseSearch.trim().toLowerCase();
    if (query.length === 0) {
      return this.cases;
    }
    return this.cases.filter((item: AdmissionAssessmentRecord): boolean =>
      item.resident_name.toLowerCase().indexOf(query) >= 0 ||
      item.assessment_no.toLowerCase().indexOf(query) >= 0);
  }

  private selectedCase(): AdmissionAssessmentRecord | undefined {
    return this.caseDetail !== undefined && this.caseDetail.id === this.selectedCaseId ?
      this.caseDetail : undefined;
  }

  private ageFromBirthDate(birthDate: string): string {
    if (birthDate.trim().length < 4) {
      return '--';
    }
    const birthYear: number = Number(birthDate.slice(0, 4));
    if (!Number.isFinite(birthYear) || birthYear <= 1900) {
      return '--';
    }
    return `${new Date().getFullYear() - birthYear} 岁`;
  }

  private submittedDate(value?: string): string {
    if (value === undefined || value.length === 0) {
      return '--';
    }
    const date: Date = new Date(value);
    if (isNaN(date.getTime())) {
      return value;
    }
    const pad = (v: number): string => v.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
  }

  private levelStyle(code: string): CaseLevelStyle {
    switch (code) {
      case 'intact':
        return { label: '能力完好', color: '#15803D', background: '#E8F5EE' };
      case 'mild':
        return { label: '轻度失能', color: '#B45309', background: '#FDF3E7' };
      case 'moderate':
        return { label: '中度失能', color: '#C2410C', background: '#FDEBDD' };
      case 'severe':
        return { label: '重度失能', color: $r('app.color.doctor_workspace_danger'), background: '#FDEBEC' };
      case 'complete':
        return { label: '完全失能', color: Color.White, background: '#B91C1C' };
      default:
        return { label: code.length > 0 ? code : '--', color: $r('sys.color.font_secondary'),
          background: $r('sys.color.comp_background_secondary') };
    }
  }

  @Builder
  private levelBadge(code: string) {
    Text(this.levelStyle(code).label)
      .fontSize(11)
      .fontColor(this.levelStyle(code).color)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
      .backgroundColor(this.levelStyle(code).background)
  }

  private compactBackVisible(): boolean {
    return this.compactWidth && this.selectedCaseId !== 0;
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(12.5)
        .fontColor($r('sys.color.font_secondary'))
        .constraintSize({ minWidth: 88 })
      Text(value.trim().length > 0 ? value : '--')
        .fontSize(13)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private tagList(tags: string[], emptyText: string) {
    if (tags.length === 0) {
      Text(emptyText).fontSize(12.5).fontColor($r('sys.color.font_tertiary')).width('100%')
    } else {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(tags, (tag: string) => {
          Text(tag)
            .fontSize(12)
            .fontColor($r('sys.color.font_primary'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(8)
            .backgroundColor($r('sys.color.comp_background_secondary'))
            .margin({ right: 8, bottom: 8 })
        }, (tag: string) => tag)
      }.width('100%')
    }
  }

  @Builder
  private masterPane() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('病例')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(`${this.cases.length} 份`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        Text('刷新')
          .fontSize(13)
          .fontColor($r('app.color.brand_blue'))
          .onClick(() => this.loadCases())
      }.width('100%').alignItems(VerticalAlign.Center)

      Search({ value: this.caseSearch, placeholder: '搜索姓名或评估编号' })
        .height(38)
        .onChange((value: string) => this.caseSearch = value)

      if (this.casesLoading) {
        Text('正在获取病例…').fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
      } else if (this.visibleCases().length === 0) {
        Text('暂无已提交的病例')
          .fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 32, bottom: 32 }).textAlign(TextAlign.Center)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.visibleCases(), (item: AdmissionAssessmentRecord) => {
              this.caseRow(item)
            }, (item: AdmissionAssessmentRecord) => `case-${item.id}`)
          }.width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width(this.compactWidth ? '100%' : 400)
    .height('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private caseRow(item: AdmissionAssessmentRecord) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(item.resident_name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        this.levelBadge(item.final_level)
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 8 }) {
        Text(item.assessment_no)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`提交于 ${this.submittedDate(item.submitted_at)}`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }.width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .border({ width: 0.5, color: this.selectedCaseId === item.id ?
      $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
    .backgroundColor(this.selectedCaseId === item.id ? '#F0F5FF' : $r('sys.color.comp_background_secondary'))
    .onClick(() => this.openCase(item.id))
  }

  @Builder
  private detailPane() {
    Column({ space: 12 }) {
      if (this.compactBackVisible()) {
        Row({ space: 6 }) {
          Text('‹ 返回病例列表')
            .fontSize(14)
            .fontColor($r('app.color.brand_blue'))
            .onClick(() => { this.selectedCaseId = 0; this.caseDetail = undefined; })
        }.width('100%')
      }
      if (this.selectedCaseId === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(42)
            .fontColor([$r('sys.color.font_tertiary')])
          Text('选择左侧病例查看详情')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.detailLoading) {
        Text('正在加载病例详情…').fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').layoutWeight(1).textAlign(TextAlign.Center)
      } else if (this.selectedCase() === undefined) {
        Text('病例详情不可用').fontSize(13).fontColor($r('sys.color.font_secondary'))
          .width('100%').layoutWeight(1).textAlign(TextAlign.Center)
      } else {
        this.caseDetailContent(this.selectedCase()!)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private caseDetailContent(item: AdmissionAssessmentRecord) {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Text(item.resident_name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(`${item.gender || '--'} · ${this.ageFromBirthDate(item.birth_date)}`)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
          Blank()
          this.levelBadge(item.final_level)
        }.width('100%').alignItems(VerticalAlign.Center)
        Text(`评估编号 ${item.assessment_no} · 提交于 ${this.submittedDate(item.submitted_at)}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')

        this.caseConclusionCard(item)
        this.caseBasicInfoCard(item)
        this.caseDiagnosisCard(item)
        this.caseCarePlanCard(item)
        this.caseConfirmationsCard(item)
      }
      .width('100%')
      .padding({ bottom: 16 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  private caseConclusionCard(item: AdmissionAssessmentRecord) {
    Column({ space: 10 }) {
      this.sectionTitle('评估结论')
      Row({ space: 16 }) {
        Column({ space: 2 }) {
          Text(`${item.ability_score}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('能力总分')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
        }.alignItems(HorizontalAlign.Start)
        Divider().vertical(true).height(40).strokeWidth(0.5).color($r('sys.color.comp_divider'))
        Column({ space: 4 }) {
          this.levelBadge(item.final_level)
          Text(`初步等级 ${this.levelStyle(item.initial_level).label}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }.alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
      if (item.level_change_reasons.length > 0) {
        Text(`等级变更依据：${item.level_change_reasons.join('；')}`)
          .fontSize(12.5)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private caseBasicInfoCard(item: AdmissionAssessmentRecord) {
    Column({ space: 8 }) {
      this.sectionTitle('基本信息')
      this.infoRow('评估原因', item.assessment_reason)
      this.infoRow('评估地点', item.assessment_location)
      this.infoRow('基准日期', item.baseline_date)
      this.infoRow('身高体重', `${item.height_cm > 0 ? `${item.height_cm} cm` : '--'} / ${item.weight_kg > 0 ? `${item.weight_kg} kg` : '--'}`)
      this.infoRow('教育程度', item.education)
      this.infoRow('信息提供者', `${item.info_provider_name || '--'}（${item.info_provider_relation || '--'}）`)
      this.infoRow('联系人', `${item.contact_name || '--'} ${item.contact_phone || ''}`)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private caseDiagnosisCard(item: AdmissionAssessmentRecord) {
    Column({ space: 8 }) {
      this.sectionTitle('诊断与健康问题')
      this.infoRow('医疗诊断', item.diagnoses.join('、'))
      this.tagList(item.health_issues, '暂无健康问题记录')
      if (item.dementia_or_mental_disorder) {
        Text('存在痴呆或精神障碍')
          .fontSize(12.5)
          .fontColor($r('app.color.doctor_workspace_danger'))
          .width('100%')
      }
      if (item.medications.length > 0) {
        Text('长期用药').fontSize(12.5).fontColor($r('sys.color.font_secondary')).width('100%')
        ForEach(item.medications, (med: AdmissionMedication) => {
          Row({ space: 8 }) {
            Text(med.name).fontSize(13).fontColor($r('sys.color.font_primary'))
              .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text([med.method, med.dose, med.frequency].filter((v: string) => v.trim().length > 0).join(' · ') || '--')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
          }.width('100%').alignItems(VerticalAlign.Center)
        }, (med: AdmissionMedication) => `${med.name}-${med.dose}`)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private caseCarePlanCard(item: AdmissionAssessmentRecord) {
    Column({ space: 8 }) {
      this.sectionTitle('照护安排')
      this.infoRow('照护方案', item.selected_care_plan_code)
      this.infoRow('可选服务', item.selected_optional_services.join('、'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private caseConfirmationsCard(item: AdmissionAssessmentRecord) {
    Column({ space: 8 }) {
      this.sectionTitle('四项确认')
      this.confirmRow('医师复核确认', item.doctor_confirmed)
      this.confirmRow('照护计划知情同意', item.plan_consent_confirmed)
      this.confirmRow('服务费用告知', item.service_fee_informed)
      this.confirmRow('信息提供者签名', item.info_provider_signed)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private confirmRow(label: string, confirmed: boolean) {
    Row({ space: 8 }) {
      SymbolGlyph($r(confirmed ? 'sys.symbol.checkmark_circle_fill' : 'sys.symbol.circle'))
        .fontSize(16)
        .fontColor([confirmed ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary')])
      Text(label).fontSize(13).fontColor($r('sys.color.font_primary')).layoutWeight(1)
      Text(confirmed ? '已确认' : '未确认')
        .fontSize(12)
        .fontColor(confirmed ? $r('app.color.doctor_workspace_success') : $r('sys.color.font_tertiary'))
    }.width('100%').alignItems(VerticalAlign.Center)
  }

  build() {
    if (this.compactWidth) {
      Column() {
        if (this.compactBackVisible()) {
          this.detailPane()
        } else {
          this.masterPane()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: this.topBarHeight + 8, bottom: 16 + this.naviIndicatorHeight })
      .backgroundColor($r('sys.color.background_secondary'))
    } else {
      Row({ space: 20 }) {
        this.masterPane()
        this.detailPane()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: this.topBarHeight + 12, bottom: 24 + this.naviIndicatorHeight })
      .backgroundColor($r('sys.color.background_secondary'))
      .alignItems(VerticalAlign.Top)
    }
  }
}
