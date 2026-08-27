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
  name: string;
  id_card?: string;
  gender: string;
  birth_date?: string;
  contact_phone?: string;
  care_level: number;
  status: number;
  bed_id?: number;
  emergency_contacts?: ElderContact[];
  image?: string;
  remark?: string;
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
}

/** 护理任务。 */
export interface CareTask {
  id: number;
  elder_id: number;
  title: string;
  kind?: string;
  assignee?: string;
  due_at?: string;
  status: string;
  remark?: string;
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
  source: string;
  record_time: string;
  is_abnormal: boolean;
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