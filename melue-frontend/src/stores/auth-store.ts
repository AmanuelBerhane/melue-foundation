import { create } from 'zustand';

import { authApi } from '@/api/resources/auth';
import { ApiError } from '@/api/http/errors';
import { getAccessToken, loadToken, setAccessToken } from '@/api/token';
import { env } from '@/config/env';

type SignInStatus = 'idle' | 'signing-in';

interface AuthState {
  token: string | null;
  hydrated: boolean;
  status: SignInStatus;
  error: string | null;
  signIn: (input: { email: string; password: string; remember: boolean }) => Promise<boolean>;
  signOut: () => Promise<void>;
  restore: () => Promise<void>;
}

function errorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  return 'Unable to sign in. Please check your connection and try again.';
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: null,
  hydrated: false,
  status: 'idle',
  error: null,

  async signIn(input) {
    set({ status: 'signing-in', error: null });
    try {
      if (env.authMock) {
        await setAccessToken(`mock-${input.email}`, input.remember);
      } else {
        await authApi.login(
          { email: input.email, password: input.password },
          { remember: input.remember },
        );
      }
      set({ status: 'idle', token: getAccessToken() });
      return true;
    } catch (error) {
      set({ status: 'idle', error: errorMessage(error) });
      return false;
    }
  },

  async signOut() {
    try {
      await authApi.logout();
    } finally {
      set({ token: null, error: null });
    }
  },

  async restore() {
    if (get().hydrated) return;
    const stored = await loadToken();
    set({ token: stored, hydrated: true });
  },
}));