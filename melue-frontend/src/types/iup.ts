import type { ISODateString, ISODateTimeString, UUID } from './common';
import type { TherapyGroup } from './student';
import type { TherapyStation } from './facilities';

export type GoalType = 'standard' | 'task_analysis';

export type IupStatus = 'draft' | 'active' | 'archived';

export type SignatureRole = 'program_director' | 'guardian';

export type StudentGoalStatus = 'active' | 'in_progress' | 'mastered' | 'archived';

export type GoalMasteryCheckStatus =
  | 'draft'
  | 'awaiting_verification'
  | 'pending_approval'
  | 'approved'
  | 'rejected';

export type MasteryVerificationOutcome = 'success' | 'fail';

export type GoalStepStatus = 'in_progress' | 'mastered';

export interface Iup {
  id: UUID;
  student_id: UUID;
  assessment_cycle_id: UUID;
  form_submission_id: UUID;
  status: IupStatus;
  finalized_on: ISODateString | null;
}

export interface IupSignature {
  id: UUID;
  iup_id: UUID;
  signer_user_id: UUID;
  signer_role: SignatureRole;
  signed_at: ISODateTimeString;
  signature_evidence: string;
}

export interface GoalDomain {
  id: UUID;
  name: string;
  description: string | null;
  display_order: number;
  is_active: boolean;
}

export interface Goal {
  id: UUID;
  goal_domain_id: UUID;
  name: string;
  type: GoalType;
  description: string | null;
  mastery_criteria_template: string;
  suggested_age_range: { min: number; max: number } | null;
  applicable_therapy_groups: TherapyGroup[];
  is_active: boolean;
}

export interface TaskAnalysisStepTemplate {
  id: UUID;
  goal_id: UUID;
  step_number: number;
  description: string;
  mastery_criteria: string;
}

export interface StudentGoal {
  id: UUID;
  iup_id: UUID;
  student_id: UUID;
  goal_id: UUID;
  station_id: UUID;
  status: StudentGoalStatus;
  progress_percent: number;
  clinical_note: string | null;
  goal?: Goal;
  station?: TherapyStation;
}

export interface StudentGoalStep {
  id: UUID;
  student_goal_id: UUID;
  task_analysis_step_template_id: UUID;
  step_number: number;
  independence_percent: number;
  status: GoalStepStatus;
}

export interface GoalMasteryCheck {
  id: UUID;
  student_goal_id: UUID;
  primary_teacher_id: UUID;
  status: GoalMasteryCheckStatus;
  primary_independence_percent: number;
  submitted_at: ISODateTimeString | null;
  rejection_reason: string | null;
}

export interface MasteryVerification {
  id: UUID;
  mastery_check_id: UUID;
  verifier_id: UUID;
  outcome: MasteryVerificationOutcome;
  prompt_level_id: UUID | null;
  notes: string | null;
  verified_at: ISODateTimeString;
}