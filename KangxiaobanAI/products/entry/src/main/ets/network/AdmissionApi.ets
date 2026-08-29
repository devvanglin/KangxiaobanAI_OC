/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import ApiClient from './ApiClient';
import { ApiResp, Bed, Paged } from './Dto';

export interface AdmissionAssessmentOption {
  id: number;
  code: string;
  label: string;
  score: number;
  sort_order: number;
}

export interface AdmissionAssessmentQuestion {
  id: number;
  code: string;
  group_code: string;
  group_name: string;
  title: string;
  guidance: string;
  required: boolean;
  max_score: number;
  sort_order: number;
  options: AdmissionAssessmentOption[];
}

export interface AdmissionAssessmentTemplate {
  code: string;
  name: string;
  version: string;
  description?: string;
  max_score: number;
  questions: AdmissionAssessmentQuestion[];
}

export interface AdmissionScreeningTemplate {
  id: number;
  code: string;
  name: string;
  version: string;
  description: string;
  category: string;
  max_score: number;
  required: boolean;
  enabled: boolean;
  sort_order: number;
  level_rules: AdmissionLevelRule[];
  scoring_notes: string[];
  questions: AdmissionAssessmentQuestion[];
}

export interface AdmissionDictionaryOption {
  id?: number;
  template_id?: number;
  category: string;
  code: string;
  label: string;
  sort_order: number;
}

export interface AdmissionCareService {
  code: string;
  title: string;
  kind: string;
  frequency: string;
  instructions: string;
  risk_level: string;
}

export interface AdmissionCarePlanTemplate {
  code: string;
  name: string;
  target_level: string;
  target: string;
  base_services: AdmissionCareService[];
  optional_services: AdmissionCareService[];
}

export interface AdmissionLevelRule {
  code: string;
  label: string;
  min_score: number;
  max_score: number;
  care_level: number;
  sort_order: number;
}

export interface AdmissionBootstrap {
  template: AdmissionAssessmentTemplate;
  dictionaries: AdmissionDictionaryOption[];
  care_plan_templates: AdmissionCarePlanTemplate[];
  level_rules: AdmissionLevelRule[];
  scoring_notes: string[];
}

export interface AdmissionRiskEvent {
  code: string;
  count: number;
}

export interface AdmissionMedication {
  name: string;
  method: string;
  dose: string;
  frequency: string;
}

export interface AdmissionAnswer {
  question_id: number;
  option_id?: number;
  answer_text: string;
}

export interface AdmissionAssessmentPayload {
  elder_id?: number;
  current_step: number;
  assessment_reason: string;
  baseline_date: string;
  resident_name: string;
  gender: string;
  birth_date: string;
  id_card: string;
  height_cm: number;
  weight_kg: number;
  ethnicity: string;
  religion: string;
  education: string;
  living_situations: string[];
  marital_status: string;
  spouse_satisfaction: string;
  children_count: number;
  children_satisfaction: string;
  hobbies: string[];
  social_participation: string[];
  exercise: string[];
  worries: string[];
  life_changes: string[];
  medical_payments: string[];
  income_sources: string[];
  risk_events: AdmissionRiskEvent[];
  diagnoses: string[];
  dementia_or_mental_disorder: boolean;
  medications: AdmissionMedication[];
  health_issues: string[];
  coma: boolean;
  info_provider_name: string;
  info_provider_relation: string;
  contact_name: string;
  contact_phone: string;
  target_bed_id?: number;
  selected_care_plan_code: string;
  selected_optional_services: string[];
  assessment_location: string;
  doctor_confirmed: boolean;
  plan_consent_confirmed: boolean;
  service_fee_informed: boolean;
  info_provider_signed: boolean;
  answers: AdmissionAnswer[];
}

export interface AdmissionStoredAnswer {
  id?: number;
  question_id: number;
  option_id?: number;
  question_code?: string;
  option_code?: string;
  answer_text: string;
  score?: number;
}

export interface AdmissionScreeningAnswerInput {
  question_id: number;
  option_id: number;
  answer_text: string;
}

export interface AdmissionScreeningStoredAnswer {
  id?: number;
  question_id: number;
  option_id?: number | null;
  question_code: string;
  option_code: string;
  answer_text: string;
  score: number;
}

export interface AdmissionScreening {
  id: number;
  admission_id: number;
  template_id: number;
  template_code: string;
  template_version: string;
  assessor_id: number;
  status: string;
  raw_score: number;
  adjusted_score: number;
  result_code: string;
  result_label: string;
  education_years?: number | null;
  notes: string;
  completed_at?: string | null;
  updated_at?: string;
  answers: AdmissionScreeningStoredAnswer[];
}

export interface AdmissionScreeningPayload {
  completed: boolean;
  education_years?: number;
  notes: string;
  answers: AdmissionScreeningAnswerInput[];
}

export interface AdmissionScreeningSaveResult {
  screening: AdmissionScreening;
  answered_count: number;
  required_count: number;
  complete: boolean;
}

export interface AdmissionAssessmentRecord {
  id: number;
  assessment_no: string;
  status: string;
  current_step: number;
  template_code: string;
  resident_name: string;
  gender: string;
  birth_date: string;
  id_card: string;
  height_cm: number;
  weight_kg: number;
  ethnicity: string;
  religion: string;
  education: string;
  living_situations: string[];
  marital_status: string;
  spouse_satisfaction: string;
  children_count: number;
  children_satisfaction: string;
  hobbies: string[];
  social_participation: string[];
  exercise: string[];
  worries: string[];
  life_changes: string[];
  medical_payments: string[];
  income_sources: string[];
  assessment_reason: string;
  baseline_date: string;
  risk_events: AdmissionRiskEvent[];
  diagnoses: string[];
  dementia_or_mental_disorder: boolean;
  medications: AdmissionMedication[];
  health_issues: string[];
  coma: boolean;
  info_provider_name: string;
  info_provider_relation: string;
  contact_name: string;
  contact_phone: string;
  target_bed_id?: number;
  selected_care_plan_code: string;
  selected_optional_services: string[];
  assessment_location: string;
  doctor_confirmed: boolean;
  plan_consent_confirmed: boolean;
  service_fee_informed: boolean;
  info_provider_signed: boolean;
  ability_score: number;
  initial_level: string;
  final_level: string;
  level_change_reasons: string[];
  elder_id?: number;
  care_plan_id?: number;
  submitted_at?: string;
  created_at?: string;
  updated_at?: string;
  answers: AdmissionStoredAnswer[];
}

export interface AdmissionPreviewResult {
  ability_score: number;
  answered_count: number;
  required_count: number;
  complete: boolean;
  initial_level: string;
  initial_level_label: string;
  final_level: string;
  final_level_label: string;
  level_change_reasons: string[];
  group_scores: AdmissionGroupScore[];
  suggested_care_plan?: AdmissionCarePlanTemplate;
}

export interface AdmissionGroupScore {
  code: string;
  label: string;
  score: number;
  max_score: number;
}

export interface AdmissionSubmitResult {
  admission: AdmissionAssessmentRecord;
  idempotent: boolean;
}

interface AdmissionPreviewRequest {
  answers: AdmissionAnswer[];
}

/** 入住评估 REST 契约。业务状态解释由 repository 统一处理。 */
export class AdmissionApi {
  public static bootstrap(): Promise<ApiResp<AdmissionBootstrap>> {
    return ApiClient.get<AdmissionBootstrap>('/admission-assessments/templates/current');
  }

  public static listDrafts(): Promise<ApiResp<Paged<AdmissionAssessmentRecord>>> {
    return ApiClient.getAll<AdmissionAssessmentRecord>('/admission-assessments?status=draft&mine=true', 100);
  }

  public static screeningTemplates(): Promise<ApiResp<AdmissionScreeningTemplate[]>> {
    return ApiClient.get<AdmissionScreeningTemplate[]>('/admission-assessments/screening-templates');
  }

  public static getAssessment(id: number): Promise<ApiResp<AdmissionAssessmentRecord>> {
    return ApiClient.get<AdmissionAssessmentRecord>(`/admission-assessments/${id}`);
  }

  public static createDraft(payload: AdmissionAssessmentPayload): Promise<ApiResp<AdmissionAssessmentRecord>> {
    return ApiClient.post<AdmissionAssessmentRecord>('/admission-assessments', payload);
  }

  public static updateDraft(id: number,
    payload: AdmissionAssessmentPayload): Promise<ApiResp<AdmissionAssessmentRecord>> {
    return ApiClient.put<AdmissionAssessmentRecord>(`/admission-assessments/${id}`, payload);
  }

  public static preview(id: number, answers: AdmissionAnswer[]): Promise<ApiResp<AdmissionPreviewResult>> {
    const request: AdmissionPreviewRequest = { answers: answers };
    return ApiClient.post<AdmissionPreviewResult>(`/admission-assessments/${id}/preview`, request);
  }

  public static submit(id: number): Promise<ApiResp<AdmissionSubmitResult>> {
    return ApiClient.post<AdmissionSubmitResult>(`/admission-assessments/${id}/submit`);
  }

  public static listScreenings(id: number): Promise<ApiResp<AdmissionScreening[]>> {
    return ApiClient.get<AdmissionScreening[]>(`/admission-assessments/${id}/screenings`);
  }

  public static saveScreening(id: number, templateCode: string,
    payload: AdmissionScreeningPayload): Promise<ApiResp<AdmissionScreeningSaveResult>> {
    return ApiClient.put<AdmissionScreeningSaveResult>(
      `/admission-assessments/${id}/screenings/${encodeURIComponent(templateCode)}`, payload);
  }

  public static freeBeds(): Promise<ApiResp<Paged<Bed>>> {
    return ApiClient.getAll<Bed>('/beds?status=free', 200);
  }
}

export default AdmissionApi;
