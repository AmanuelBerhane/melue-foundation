import { AxiosError } from 'axios';

export interface ApiErrorBody {
  error: string | string[];
}

export class ApiError extends Error {
  readonly status: number | null;
  readonly fields: string[];

  constructor(message: string, status: number | null = null, fields: string[] = []) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.fields = fields;
  }
}

function readPayloadError(error: unknown): string | null {
  if (!(error instanceof AxiosError)) return null;
  const body = error.response?.data as Partial<ApiErrorBody> | undefined;
  if (!body || typeof body.error === 'undefined') return null;
  if (typeof body.error === 'string') return body.error;
  return body.error.join(', ');
}

function readPayloadFields(error: unknown): string[] {
  if (!(error instanceof AxiosError)) return [];
  const body = error.response?.data as Partial<ApiErrorBody> | undefined;
  if (Array.isArray(body?.error)) return body.error;
  return [];
}

export function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;

  if (error instanceof AxiosError) {
    const status = error.response?.status ?? null;
    const message =
      readPayloadError(error) ??
      (error.response ? error.message : 'Unable to reach the server. Please check your connection.');
    return new ApiError(message, status, readPayloadFields(error));
  }

  if (error instanceof Error) return new ApiError(error.message);

  return new ApiError('An unexpected error occurred');
}