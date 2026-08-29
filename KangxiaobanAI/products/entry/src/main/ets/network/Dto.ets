/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

/** 后端统一响应结构 {code,msg,data}。 */
export interface ApiResp<T> {
  code: number;
  msg: string;
  data: T;
}

export interface RoleInfo {
  code: string;
  name: string;
}

export interface LoginUser {
  id: number;
  username: string;
  real_name: string;
  phone: string;
  status: number;
  roles: RoleInfo[];
}

export interface LoginResp {
  token: string;
  user: LoginUser;
}

export interface AiChatResponse {
  answer: string;
  model: string;
  note: string;
}

export interface AiChatRequest {
  question: string;
}

export interface AiConversation {
  id: number;
  tenant_id: number;
  created_at: string;
  updated_at: string;
  user_id: number;
  title: string;
  is_default: boolean;
  last_message_at?: string | null;
}

export interface AiConversationMessage {
  id: number;
  tenant_id: number;
  created_at: string;
  updated_at: string;
  conversation_id: number;
  user_id: number;
  role: string;
  content: string;
  model: string;
  sent_at: string;
}

export interface AiConversationListResponse {
  list: AiConversation[];
}

export interface AiConversationMessageListResponse {
  list: AiConversationMessage[];
}

export interface AiConversationCreateRequest {
  title: string;
}

export interface AiConversationSendRequest {
  content: string;
}

export interface AiConversationDeleteResponse {
  id: number;
  deleted: boolean;
}

export interface AiConversationExchangeResponse {
  conversation: AiConversation;
  user_message: AiConversationMessage;
  assistant_message: AiConversationMessage;
  answer: string;
  model: string;
  note: string;
}

export interface AiPromptSuggestion {
  id: number;
  code: string;
  group_index: number;
  title: string;
  prompt: string;
  sort_order: number;
  enabled: boolean;
}

export interface AiPromptSuggestionListResponse {
  list: AiPromptSuggestion[];
}

export interface TaskStatusRequest {
  status: string;
}

/** 可联系的正式用户。 */
export interface MessageContact {
  id: number;
  username: string;
  real_name: string;
  phone: string;
  status: number;
  roles: RoleInfo[];
}

/** 用户间消息。 */
export interface UserMessage {
  id: number;
  sender_id: number;
  receiver_id: number;
  elder_id?: number;
  content: string;
  type: string;
  sent_at: string;
  read_at?: string;
}

/** 分页响应。 */
export interface Paged<T> {
  list: T[];
  page: number;
  size: number;
  total: number;
}

/** 长者档案。 */
export interface Elder {
  id: number;
  created_at?: string;
  name: string;
  id_card?: string;
  gender: string;
  birth_date?: string;
  contact_phone?: string;
  care_level: number;
  status: number;
  bed_id?: number;
  emergency_contacts?: ElderContact[];
  allergies: string[];
  image?: string;
  remark?: string;
  bed?: Bed;
}

export interface ElderContact {
  name: string;
  relation: string;
  phone: string;
  is_emergency: boolean;
}

/** 房间。 */
export interface Room {
  id: number;
  building: string;
  floor: number;
  room_no: string;
  type: string;
  status: string;
  beds?: Bed[];
}

/** 床位。 */
export interface Bed {
  id: number;
  room_id: number;
  bed_no: string;
  status: string;
  elder_id?: number;
  room?: Room;
}

/** 护理任务。 */
export interface CareTaskPlanItem {
  id: number;
  instructions: string;
}

export interface CareTask {
  id: number;
  elder_id: number;
  plan_item_id?: number;
  title: string;
  kind?: string;
  priority?: string;
  category?: string;
  assignee?: string;
  due_at?: string;
  status: string;
  remark?: string;
  plan_item?: CareTaskPlanItem;
}

/** 健康体征。 */
export interface HealthRecord {
  id: number;
  elder_id: number;
  temperature?: number;
  systolic?: number;
  diastolic?: number;
  heart_rate?: number;
  spo2?: number;
  respiratory_rate?: number;
  steps?: number;
  sleep_hours?: number;
  source: string;
  record_time: string;
  is_abnormal: boolean;
  risk_level?: string;
  risk_summary?: string;
}

/** WebSocket 实时事件 {type,data}。 */
export interface WsEvent<T = Object> {
  type: string;
  data: T;
}

/** 月度账单。 */
export interface Bill {
  id: number;
  elder_id: number;
  bill_month: string;
  bed_fee: number;
  nursing_fee: number;
  meal_fee: number;
  other_fee: number;
  amount: number;
  paid: number;
  status: string;
}

/** 资金流水。 */
export interface FundFlow {
  id: number;
  elder_id: number;
  direction: string;
  related_month: string;
  reason: string;
  amount: number;
}

/** 排班。 */
export interface Schedule {
  id: number;
  staff: string;
  work_date: string;
  shift: string;
  room_scope?: string;
}

/** 交接班。 */
export interface ShiftHandover {
  id: number;
  from_staff: string;
  to_staff: string;
  work_date: string;
  summary?: string;
  issues?: string;
}

export interface IotDevice {
  id: number;
  device_id: string;
  product: string;
  building: string;
  room: string;
  bed: string;
  elder_id?: number;
  online: number;
  battery?: number;
  last_seen?: string;
  protocol: string;
}

export interface Alert {
  id: number;
  elder_id?: number;
  device_id: string;
  type: string;
  level: string;
  content: string;
  status: string;
  handled_by: string;
  create_time: string;
  close_time?: string;
}

export interface MedicationRecord {
  id: number;
  elder_id: number;
  medicine_name: string;
  dosage: string;
  frequency?: string;
  route?: string;
  plan_time?: string;
  taken_time?: string;
  today_total?: number;
  today_done?: number;
  status: string;
}

export interface NotificationRecord {
  id: number;
  user_id: number;
  role: string;
  channel: string;
  type: string;
  title: string;
  content: string;
  severity: string;
  read_at?: string;
  sent_at?: string;
}

export interface DiningOrder {
  id: number;
  elder_id: number;
  meal_time: string;
  items: string;
  qty: number;
  unit_price: number;
  total_amount: number;
  status: string;
}

export interface Assessment {
  id: number;
  elder_id: number;
  assessor_id: number;
  assessment_type: string;
  score?: number;
  risk_level: string;
  notes: string;
  assessed_at: string;
}

/** 机构运营与 IoT 规则，按登录租户从服务器读取。 */
export interface OperationPolicy {
  occupancy_warning_percent: number;
  device_online_warning_percent: number;
  alert_cooldown_seconds: number;
  device_offline_seconds: number;
  alert_escalation_seconds: number;
  medication_time_periods: MedicationTimePeriod[];
}

export interface MedicationTimePeriod {
  code: string;
  label: string;
  start_time: string;
  end_time: string;
  sort_order: number;
}
