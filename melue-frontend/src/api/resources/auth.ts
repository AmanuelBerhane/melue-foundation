import { http } from '@/api/http/client';
import { setAccessToken } from '@/api/token';
import type {
  CreateAccountRequest,
  CreateAccountResponse,
  LoginRequest,
  LoginResponse,
  ResetPasswordRequest,
  ResetPasswordResponse,
} from '@/types/auth';

function extractBearer(header: string | undefined): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? match[1] : null;
}

export interface LoginOptions {
  remember?: boolean;
}

export const authApi = {
  async login(payload: LoginRequest, options: LoginOptions = {}): Promise<LoginResponse> {
    const { data, headers } = await http.post<LoginResponse>('/auth/login', payload);
    const token = data.token ?? extractBearer(headers.authorization);
    if (token) await setAccessToken(token, options.remember ?? false);
    return data;
  },

  async logout(): Promise<void> {
    try {
      await http.post('/auth/logout');
    } finally {
      await setAccessToken(null);
    }
  },

  async createAccount(payload: CreateAccountRequest): Promise<CreateAccountResponse> {
    const { data } = await http.post<CreateAccountResponse>('/auth/create-account', payload);
    return data;
  },

  async resetPassword(payload: ResetPasswordRequest): Promise<ResetPasswordResponse> {
    const { data } = await http.post<ResetPasswordResponse>('/auth/reset-password', payload);
    return data;
  },
};