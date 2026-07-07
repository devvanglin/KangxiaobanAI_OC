/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

export type StatusLevel = 'normal' | 'warning' | 'danger';

export type Gender = 'male' | 'female';

export type TaskState = 'todo' | 'doing' | 'done';

export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack';

/** 长者基础信息 */
export interface ResidentData {
  id: string;
  name: string;
  age: number;
  gender: Gender;
  room: string;
  bed: string;
  level: StatusLevel;
  status: string;
  emergencyContact: string;
  emergencyPhone: string;
  admissionDate: string;
  careLevel: string;
  diagnosis: string[];
  allergies: string[];
  deviceIds: string[];
  /** 头像首字母（用于占位） */
  avatarText?: string;
}

/** 健康记录时间线 */
export interface HealthRecord {
  time: string;
  type: string;
  operator: string;
  content: string;
}

/** 情绪记录 */
export interface MoodRecord {
  time: string;
  mood: string;
  level: StatusLevel;
  note: string;
}

/** 房间 IoT 设备 */
export interface RoomDeviceData {
  id: string;
  name: string;
  type: string;
  room: string;
  status: string;
  level: StatusLevel;
  battery?: number;
  lastUpdate: string;
}

/** 生命体征快照 */
export interface VitalSign {
  heartRate: number;
  systolic: number;
  diastolic: number;
  oxygen: number;
  temperature: number;
  respiratory: number;
  steps: number;
  sleepHours: number;
  measuredAt: string;
}

/** 体征历史趋势点 */
export interface VitalTrendPoint {
  time: string;
  heartRate: number;
  systolic: number;
  diastolic: number;
}

/** 用药记录 */
export interface Medication {
  id: string;
  name: string;
  dose: string;
  frequency: string;
  route: string;
  nextTime: string;
  todayTotal: number;
  todayDone: number;
  level: StatusLevel;
}

/** 护理任务 */
export interface CareTaskItem {
  id: string;
  time: string;
  project: string;
  state: TaskState;
  assignee: string;
  note?: string;
}

/** 足迹活动记录 */
export interface FootprintRecord {
  time: string;
  location: string;
  activity: string;
  duration: number;
  level: StatusLevel;
}

/** 监控摄像头快照 */
export interface MonitorSnapshot {
  id: string;
  name: string;
  room: string;
  status: 'online' | 'offline';
  lastEvent: string;
  lastUpdate: string;
}

/** 风险评估 */
export interface RiskAssessment {
  fallRisk: StatusLevel;
  pressureUlcerRisk: StatusLevel;
  wanderingRisk: StatusLevel;
  adlScore: number;
  cognitiveScore: number;
  nextReview: string;
}

/** 膳食记录 */
export interface MealRecord {
  type: MealType;
  label: string;
  state: TaskState;
  note?: string;
}

/** 报警事件 */
export interface AlertEvent {
  time: string;
  type: string;
  level: StatusLevel;
  status: 'open' | 'resolved';
  handler?: string;
  detail: string;
}

/** 首页健康状态行数据（保留兼容） */
export interface HealthRowData {
  id: string;
  name: string;
  age: number;
  room: string;
  bed: string;
  level: StatusLevel;
  status: string;
  mood: string;
  moodLevel: StatusLevel;
  lastUpdate: string;
}
