import ApiClient from './ApiClient';
import { ApiResp } from './Dto';

export interface AssessmentAgentQuestion {
  id: string;
  topic: string;
  question: string;
}

export interface AssessmentAgentAnswer {
  id: string;
  topic: string;
  question: string;
  answer: string;
  skipped: boolean;
  no_response?: boolean;
}

export interface AssessmentAgentSession {
  session_key: string;
  intake_id: number;
  elder_id: number;
  assessor_id: number;
  question_bank_id: number;
  question_version: number;
  title: string;
  resident_name: string;
  gender: string;
  address: string;
  no_answer_timeout: number;
  questions: AssessmentAgentQuestion[];
  answers: AssessmentAgentAnswer[];
  status: string;
  current_index: number;
  external_record_id: string;
  report: string;
  assessment_id?: number;
  package_recommendation_status?: string;
  package_recommendation_template_id?: number;
  package_recommendation_error?: string;
  started_at?: string;
  completed_at?: string;
}

interface AssessmentAgentSessionCreateRequest {
  intake_id: number;
}

export class AssessmentAgentApi {
  public static createSession(intakeId: number): Promise<ApiResp<AssessmentAgentSession>> {
    const request: AssessmentAgentSessionCreateRequest = { intake_id: intakeId };
    return ApiClient.post<AssessmentAgentSession>('/assessment-agent/sessions', request);
  }

  public static getSession(sessionKey: string): Promise<ApiResp<AssessmentAgentSession>> {
    return ApiClient.get<AssessmentAgentSession>(
      `/assessment-agent/sessions/${encodeURIComponent(sessionKey)}`);
  }

  public static sessionForIntake(intakeId: number): Promise<ApiResp<AssessmentAgentSession>> {
    return ApiClient.get<AssessmentAgentSession>(`/assessment-agent/intakes/${intakeId}/session`);
  }
}
