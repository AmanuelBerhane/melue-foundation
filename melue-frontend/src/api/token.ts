import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const TOKEN_KEY = 'melue.auth.token';

let accessToken: string | null = null;

export function getAccessToken(): string | null {
  return accessToken;
}

function writeStored(value: string | null, persist: boolean): void {
  if (!persist) return;
  if (Platform.OS === 'web') {
    if (typeof localStorage === 'undefined') return;
    if (value) localStorage.setItem(TOKEN_KEY, value);
    else localStorage.removeItem(TOKEN_KEY);
    return;
  }
  if (value) void SecureStore.setItemAsync(TOKEN_KEY, value);
  else void SecureStore.deleteItemAsync(TOKEN_KEY);
}

export async function loadToken(): Promise<string | null> {
  if (Platform.OS === 'web') {
    if (typeof localStorage === 'undefined') return null;
    accessToken = localStorage.getItem(TOKEN_KEY);
    return accessToken;
  }
  accessToken = await SecureStore.getItemAsync(TOKEN_KEY);
  return accessToken;
}

export async function setAccessToken(token: string | null, persist = true): Promise<void> {
  accessToken = token;
  writeStored(token, persist);
}