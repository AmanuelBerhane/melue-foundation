import { Stack, useRouter, useSegments } from 'expo-router';
import { useEffect } from 'react';

import { useAuthStore } from '@/stores/auth-store';

export function RootNavigator() {
  const router = useRouter();
  const segments = useSegments();
  const token = useAuthStore((state) => state.token);
  const hydrated = useAuthStore((state) => state.hydrated);

  useEffect(() => {
    if (!hydrated) return;
    const isAuthRoute = segments[0] === 'login';
    if (!token && !isAuthRoute) {
      router.replace('/login');
    } else if (token && isAuthRoute) {
      router.replace('/(tabs)');
    }
  }, [token, hydrated, segments, router]);

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="login" />
    </Stack>
  );
}