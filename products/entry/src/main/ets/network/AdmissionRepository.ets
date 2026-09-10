/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import { ApiResp, Bed, Paged } from './Dto';
import AdmissionApi, {
  AdmissionAnswer,
  AdmissionAssessmentPayload,
  AdmissionAssessmentRecord,
  AdmissionBootstrap,
  AdmissionIntakePayload,
  AdmissionIntakeResult,
  AdmissionPhoto,
  AdmissionPhotoDeleteResult,
  AdmissionPreviewResult,
  AdmissionScreening,
  AdmissionScreeningPayload,
  AdmissionScreeningSaveResult,
  AdmissionScreeningTemplate,
  AdmissionSubmitResult
} from './AdmissionApi';

export type AdmissionFailureKind = 'none' | 'network' | 'session' | 'denied' | 'missing' | 'conflict' | 'validation' |
  'server';

export interface AdmissionResult<T> {
  ok: boolean;
  code: number;
  message: string;
  kind: AdmissionFailureKind;
  data?: T;
}

/** 将网络和业务错误映射为页面可恢复状态。 */
export class AdmissionRepository {
  private static success<T>(data: T): AdmissionResult<T> {
    return { ok: true, code: 0, message: '', kind: 'none', data: data };
  }

  private static failure<T>(code: number, message: string): AdmissionResult<T> {
    let kind: AdmissionFailureKind = 'server';
    if (code === 400) {
      kind = 'validation';
    } else if (code === 401) {
      kind = 'session';
    } else if (code === 403) {
      kind = 'denied';
    } else if (code === 404) {
      kind = 'missing';
    } else if (code === 409) {
      kind = 'conflict';
    }
    return { ok: false, code: code, message: message, kind: kind };
  }

  private static map<T>(response: ApiResp<T>): AdmissionResult<T> {
    if (response.code === 0 && response.data !== undefined && response.data !== null) {
      return AdmissionRepository.success<T>(response.data);
    }
    return AdmissionRepository.failure<T>(response.code, response.msg.length > 0 ? response.msg : '请求失败');
  }

  private static networkFailure<T>(): AdmissionResult<T> {
    return { ok: false, code: -1, message: '无法连接服务器，请检查网络后重试', kind: 'network' };
  }

  public static async bootstrap(): Promise<AdmissionResult<AdmissionBootstrap>> {
    try {
      return AdmissionRepository.map<AdmissionBootstrap>(await AdmissionApi.bootstrap());
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionBootstrap>();
    }
  }

  public static async listDrafts(): Promise<AdmissionResult<Paged<AdmissionAssessmentRecord>>> {
    try {
      return AdmissionRepository.map<Paged<AdmissionAssessmentRecord>>(await AdmissionApi.listDrafts());
    } catch (_error) {
      return AdmissionRepository.networkFailure<Paged<AdmissionAssessmentRecord>>();
    }
  }

  public static async screeningTemplates(): Promise<AdmissionResult<AdmissionScreeningTemplate[]>> {
    try {
      return AdmissionRepository.map<AdmissionScreeningTemplate[]>(await AdmissionApi.screeningTemplates());
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionScreeningTemplate[]>();
    }
  }

  public static async getAssessment(id: number): Promise<AdmissionResult<AdmissionAssessmentRecord>> {
    try {
      return AdmissionRepository.map<AdmissionAssessmentRecord>(await AdmissionApi.getAssessment(id));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionAssessmentRecord>();
    }
  }

  public static async save(id: number,
    payload: AdmissionAssessmentPayload): Promise<AdmissionResult<AdmissionAssessmentRecord>> {
    try {
      const response: ApiResp<AdmissionAssessmentRecord> = id > 0 ?
        await AdmissionApi.updateDraft(id, payload) : await AdmissionApi.createDraft(payload);
      return AdmissionRepository.map<AdmissionAssessmentRecord>(response);
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionAssessmentRecord>();
    }
  }

  public static async preview(id: number,
    answers: AdmissionAnswer[]): Promise<AdmissionResult<AdmissionPreviewResult>> {
    try {
      return AdmissionRepository.map<AdmissionPreviewResult>(await AdmissionApi.preview(id, answers));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionPreviewResult>();
    }
  }

  public static async submit(id: number): Promise<AdmissionResult<AdmissionSubmitResult>> {
    try {
      return AdmissionRepository.map<AdmissionSubmitResult>(await AdmissionApi.submit(id));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionSubmitResult>();
    }
  }

  public static async listScreenings(id: number): Promise<AdmissionResult<AdmissionScreening[]>> {
    try {
      return AdmissionRepository.map<AdmissionScreening[]>(await AdmissionApi.listScreenings(id));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionScreening[]>();
    }
  }

  public static async saveScreening(id: number, templateCode: string,
    payload: AdmissionScreeningPayload): Promise<AdmissionResult<AdmissionScreeningSaveResult>> {
    try {
      return AdmissionRepository.map<AdmissionScreeningSaveResult>(
        await AdmissionApi.saveScreening(id, templateCode, payload));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionScreeningSaveResult>();
    }
  }

  public static async freeBeds(): Promise<AdmissionResult<Paged<Bed>>> {
    try {
      return AdmissionRepository.map<Paged<Bed>>(await AdmissionApi.freeBeds());
    } catch (_error) {
      return AdmissionRepository.networkFailure<Paged<Bed>>();
    }
  }

  public static async createIntake(payload: AdmissionIntakePayload): Promise<AdmissionResult<AdmissionIntakeResult>> {
    try {
      return AdmissionRepository.map<AdmissionIntakeResult>(await AdmissionApi.createIntake(payload));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionIntakeResult>();
    }
  }

  public static async uploadPhoto(kind: string, uploadKey: string, contentType: string,
    data: ArrayBuffer): Promise<AdmissionResult<AdmissionPhoto>> {
    try {
      return AdmissionRepository.map<AdmissionPhoto>(
        await AdmissionApi.uploadPhoto(kind, uploadKey, contentType, data));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionPhoto>();
    }
  }

  public static async deletePendingPhoto(uploadKey: string,
    kind: string): Promise<AdmissionResult<AdmissionPhotoDeleteResult>> {
    try {
      return AdmissionRepository.map<AdmissionPhotoDeleteResult>(
        await AdmissionApi.deletePendingPhoto(uploadKey, kind));
    } catch (_error) {
      return AdmissionRepository.networkFailure<AdmissionPhotoDeleteResult>();
    }
  }
}

export default AdmissionRepository;
