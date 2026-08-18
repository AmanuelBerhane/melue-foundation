import type { ISODateString, TimeString, UUID } from './common';

export interface TherapyStation {
  id: UUID;
  name: string;
  rooms?: TherapyRoom[];
}

export interface TherapyRoom {
  id: UUID;
  station_id: UUID;
  name: string;
}

export type SessionRound = 'morning' | 'afternoon' | 'whole_day' | string;

export interface SessionBlockDefinition {
  id: UUID;
  name: string;
  start_time: TimeString;
  end_time: TimeString;
  round?: SessionRound;
  is_active: boolean;
}

export interface SchedulingPolicy {
  staff_student_capacity: number;
  draft_expiry_days: number;
  pre_therapy_duration_minutes: number;
  station1_duration_minutes: number;
  station2_duration_minutes: number;
}

export interface TrialLoggingConfiguration {
  layout: 'horizontal' | 'vertical' | 'card_grid';
  stream_count: number;
}

export interface MasteryPolicy {
  consecutive_trials_required: number;
  percentage_threshold: number;
  automatic_suggestion_enabled: boolean;
  final_approver_role: UUID;
}

export interface PromptLevel {
  id: UUID;
  label: string;
  color: string;
  display_order: number;
  is_active: boolean;
}

export interface ConfigurationOption {
  id: UUID;
  label: string;
  display_order: number;
  is_active: boolean;
  is_other: boolean;
}

export interface BehaviorDefinitionOption extends ConfigurationOption {
  definition: string;
}

export type AbcOptionKind =
  | 'antecedent'
  | 'consequence'
  | 'location'
  | 'frequency'
  | 'intensity'
  | 'behavior_category';