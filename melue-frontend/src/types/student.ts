import type { ISODateString, ISODateTimeString, UUID } from './common';
import type { Guardian } from './identity';

export type ProgramType = 'regular' | 'pulled_out';

export type TherapyGroup = 'basic' | 'functional_living';

export type StudentStatus =
  | 'in_assessment'
  | 'assessment_complete'
  | 'ready_for_iup'
  | 'active_therapy'
  | 'withdrawn'
  | 'discharged';

export type GuardianRelationship =
  | 'parent'
  | 'legal_guardian'
  | 'relative'
  | 'other';

export type EnrollmentStatus = 'draft' | 'confirmed' | 'purged';

export type AttachmentKind =
  | 'birth_certificate'
  | 'medical_diagnosis'
  | 'agreement'
  | 'headshot'
  | 'baseline_video';

export type ConsentScope =
  | 'child_data'
  | 'medical_records'
  | 'photos'
  | 'video'
  | 'audio_recording';

export type DataRequestType = 'access' | 'erasure';

export type DataRequestStatus = 'pending' | 'approved' | 'completed' | 'rejected';

export interface Student {
  id: UUID;
  full_name: string;
  date_of_birth: ISODateString;
  diagnosis: string | null;
  program_type: ProgramType;
  therapy_group: TherapyGroup;
  status: StudentStatus;
  created_at: ISODateTimeString;
  updated_at: ISODateTimeString;
}

export interface StudentGuardian {
  id: UUID;
  student_id: UUID;
  guardian_id: UUID;
  relationship: GuardianRelationship;
  is_primary_contact: boolean;
  guardian?: Guardian;
}

export interface Enrollment {
  id: UUID;
  student_id: UUID;
  form_submission_id: UUID;
  status: EnrollmentStatus;
  enrollment_date: ISODateString;
}

export interface StudentAttachment {
  id: UUID;
  student_id: UUID;
  kind: AttachmentKind;
  media_type: string;
  secure_uri: string;
  captured_at: ISODateTimeString;
  is_required: boolean;
}

export interface ConsentRecord {
  id: UUID;
  student_id: UUID;
  guardian_id: UUID;
  scope: ConsentScope;
  granted_at: ISODateTimeString;
  withdrawn_at: ISODateTimeString | null;
}

export interface DataSubjectRequest {
  id: UUID;
  student_id: UUID;
  requested_by_guardian_id: UUID;
  type: DataRequestType;
  status: DataRequestStatus;
  approved_by_user_id: UUID | null;
}

export interface InternalStudentNote {
  id: UUID;
  student_id: UUID;
  author_id: UUID;
  content: string;
  recorded_at: ISODateTimeString;
}