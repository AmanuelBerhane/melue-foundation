import type { ISODateString, ISODateTimeString, TimeString, UUID } from './common';
import type { FormStatus } from './forms';

export type AssessmentCycleStatus = 'in_progress' | 'complete' | 'reviewed';

export type AbllsScoreValue = '0' | '1' | '2' | 'not_applicable';

export type FunctionAnalysisStatus = 'in_progress' | 'complete';

export type FrequencyUnit = 'year' | 'month' | 'week' | 'day' | 'hour';

export type InformantRelationship =
  | 'parent'
  | 'teacher_instructor'
  | 'residential_staff'
  | 'other';

export type PreferenceContext = 'sensory_time' | 'circle_time' | 'play_time';

export type PreferenceTier = 'highest' | 'moderate' | 'low';

export interface AssessmentCycle {
  id: UUID;
  student_id: UUID;
  status: AssessmentCycleStatus;
  started_on: ISODateString;
  completed_on: ISODateString | null;
}

export interface SkillsAssessment {
  id: UUID;
  form_submission_id: UUID;
  need_analysis_summary: string | null;
  status: FormStatus;
}

export interface AbllsSkillDefinition {
  id: UUID;
  code: string;
  domain: string;
  description: string;
  is_active: boolean;
}

export interface AbllsScore {
  id: UUID;
  skills_assessment_id: UUID;
  skill_definition_id: UUID;
  value: AbllsScoreValue;
  notes: string | null;
}

export interface BehaviorAssessment {
  id: UUID;
  assessment_cycle_id: UUID;
  status: FormStatus;
}

export interface BehaviorFunctionAnalysis {
  id: UUID;
  behavior_assessment_id: UUID;
  behavior_definition_id: UUID;
  operational_definition: string;
  status: FunctionAnalysisStatus;
}

export interface SubscaleScore {
  name: string;
  total: number;
  mean: number;
  rank: number;
}

export interface MotivationAssessmentScale {
  id: UUID;
  behavior_function_analysis_id: UUID;
  rater_name: string | null;
  setting_description: string | null;
  frequency_unit: FrequencyUnit | null;
  subscale_scores: SubscaleScore[];
}

export interface MassResponse {
  id: UUID;
  motivation_assessment_scale_id: UUID;
  question_number: number;
  likert_score: number;
}

export interface FastScreening {
  id: UUID;
  behavior_function_analysis_id: UUID;
  informant_name: string;
  informant_relationship: InformantRelationship;
  interviewer_name: string;
  years_known: number;
  months_known: number;
  daily_interaction: boolean;
  hours_per_day: number;
  hours_per_week: number;
  observation_contexts: string[];
  maintaining_variable_scores: Record<string, number>;
}

export interface FastResponse {
  id: UUID;
  fast_screening_id: UUID;
  question_number: number;
  answer: boolean;
}

export interface AssessmentAbcObservation {
  id: UUID;
  behavior_function_analysis_id: UUID;
  occurred_on: ISODateString;
  occurred_at: TimeString;
  location: string;
  antecedent: string;
  consequence: string;
  notes: string | null;
  recorded_by_user_id: UUID;
}

export interface PreferenceInventoryItem {
  id: UUID;
  name: string;
  category: string;
  is_active: boolean;
}

export interface PreferenceObservation {
  id: UUID;
  context: PreferenceContext;
  approached: boolean;
  duration_seconds: number | null;
  frequency_count: number | null;
  combined_score: number | null;
  tier: PreferenceTier | null;
  rank: number | null;
  notes: string | null;
}

export interface SensoryActivityDefinition {
  id: UUID;
  code: string;
  name: string;
  description: string;
  is_active: boolean;
}

export interface SensoryActivityResult {
  id: UUID;
  sensory_time_assessment_id: UUID;
  activity_definition_id: UUID;
  engagement_level: string;
  reaction: string;
  remark: string | null;
}