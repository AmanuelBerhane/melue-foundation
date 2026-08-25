import type { ISODateString, UUID } from './common';

export type FormPurpose =
  | 'enrollment'
  | 'iup'
  | 'ablls'
  | 'social_skills_questionnaire';

export type FormStatus = 'draft' | 'submitted' | 'complete' | 'reviewed';

export type FormFieldType =
  | 'text'
  | 'textarea'
  | 'number'
  | 'date'
  | 'select'
  | 'radio'
  | 'checkbox'
  | 'signature'
  | 'file';

export interface FormDefinition {
  id: UUID;
  purpose: FormPurpose;
  name: string;
}

export interface FormMetadata {
  form_id: UUID;
  form_name: string;
  revision_number: string;
  revision_date: ISODateString;
  organization_name?: string;
}

export interface FormRevision {
  id: UUID;
  form_definition_id: UUID;
  revision_number: string;
  revision_date: ISODateString;
  metadata: FormMetadata;
  is_active: boolean;
}

export interface FormFieldDefinition {
  id: UUID;
  field_key: string;
  label: string;
  field_type: FormFieldType;
  required: boolean;
  visible: boolean;
  display_order: number;
  validation_rules: string[] | null;
}

export interface FormSubmission {
  id: UUID;
  form_revision_id: UUID;
  status: FormStatus;
  values: Record<string, unknown>;
}