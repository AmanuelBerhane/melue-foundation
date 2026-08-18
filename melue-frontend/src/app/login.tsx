import { Image } from 'expo-image';
import { SymbolView } from 'expo-symbols';
import { useEffect, useState } from 'react';

import '@/global.css';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import Toast from 'react-native-toast-message';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useAuthStore } from '@/stores/auth-store';

const PALETTE = {
  background: '#F1F3F5',
  card: '#FFFFFF',
  textPrimary: '#1F2937',
  textSecondary: '#6B7280',
  accent: '#3B82F6',
  brand: '#FBBF24',
  border: '#E5E7EB',
  borderStrong: '#D1D5DB',
  icon: '#9CA3AF',
} as const;

const DEMO_ACCOUNTS = [
  { role: 'Teacher 1', email: 'teacher1@melue.foundation' },
  { role: 'Teacher 2', email: 'teacher2@melue.foundation' },
] as const;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

interface FieldProps {
  label: string;
  placeholder: string;
  value: string;
  onChangeText: (value: string) => void;
  icon: 'mail' | 'lock';
  secureTextEntry?: boolean;
  autoComplete?: 'email' | 'current-password';
  returnKeyType?: 'next' | 'done';
  onSubmitEditing?: () => void;
}

function Field({
  label,
  placeholder,
  value,
  onChangeText,
  icon,
  secureTextEntry,
  autoComplete,
  returnKeyType,
  onSubmitEditing,
}: FieldProps) {
  const [focused, setFocused] = useState(false);

  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <View style={[styles.inputRow, focused && styles.inputRowFocused]}>
        <SymbolView
          name={{ ios: icon === 'mail' ? 'envelope' : 'lock.fill', android: icon, web: icon }}
          tintColor={PALETTE.icon}
          size={20}
          style={styles.inputIcon}
        />
        <TextInput
          style={styles.input}
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={PALETTE.icon}
          autoCapitalize="none"
          autoCorrect={false}
          secureTextEntry={secureTextEntry}
          autoComplete={autoComplete}
          returnKeyType={returnKeyType}
          onSubmitEditing={onSubmitEditing}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
        />
      </View>
    </View>
  );
}

export default function LoginScreen() {
  const signIn = useAuthStore((state) => state.signIn);
  const status = useAuthStore((state) => state.status);
  const error = useAuthStore((state) => state.error);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(false);
  const [pending, setPending] = useState(false);

  const signingIn = status === 'signing-in' || pending;

  useEffect(() => {
    if (error) Toast.show({ type: 'error', text1: error });
  }, [error]);

  function handleSubmit() {
    if (!EMAIL_PATTERN.test(email)) {
      Toast.show({ type: 'error', text1: 'Enter a valid email address.' });
      return;
    }
    if (!password) {
      Toast.show({ type: 'error', text1: 'Enter your password.' });
      return;
    }
    setPending(true);
    Promise.all([
      signIn({ email: email.trim(), password, remember }),
      new Promise((resolve) => setTimeout(resolve, 600)),
    ]).finally(() => setPending(false));
  }

  function handleDemoSelect(demoEmail: string) {
    setEmail(demoEmail);
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled">
          <View style={styles.card}>
            <View style={styles.header}>
              <Image
                source={require('@/assets/images/Logo1.png')}
                style={styles.brandLogo}
                contentFit="contain"
              />
            </View>

            <Text style={styles.title}>Sign In to Your Account</Text>
            <Text style={styles.subtitle}>Melu&apos;e Foundation Therapy Portal</Text>

            <View style={styles.form}>
              <Field
                label="Email Address"
                placeholder="you@melue.org"
                value={email}
                onChangeText={setEmail}
                icon="mail"
                autoComplete="email"
                returnKeyType="next"
              />
              <Field
                label="Password"
                placeholder="Enter your password"
                value={password}
                onChangeText={setPassword}
                icon="lock"
                secureTextEntry
                autoComplete="current-password"
                returnKeyType="done"
                onSubmitEditing={handleSubmit}
              />

              <View style={styles.optionsRow}>
                <Pressable
                  style={styles.rememberRow}
                  hitSlop={8}
                  onPress={() => setRemember((value) => !value)}>
                  <View style={[styles.checkbox, remember && styles.checkboxChecked]}>
                    {remember && (
                      <SymbolView
                        name={{ ios: 'checkmark', android: 'check', web: 'check' }}
                        tintColor="#FFFFFF"
                        size={12}
                      />
                    )}
                  </View>
                  <Text style={styles.rememberLabel}>Remember this device</Text>
                </Pressable>
                <Pressable hitSlop={8} onPress={() => undefined}>
                  <Text style={styles.forgotLink}>Forgot Password?</Text>
                </Pressable>
              </View>

              <Pressable
                accessibilityRole="button"
                style={({ pressed }) => [
                  styles.submitButton,
                  pressed && styles.submitButtonPressed,
                  signingIn && styles.submitButtonDisabled,
                ]}
                disabled={signingIn}
                onPress={handleSubmit}>
                {signingIn ? (
                  <View style={styles.submitLoading}>
                    <ActivityIndicator color={PALETTE.textPrimary} />
                    <Text style={styles.submitLabel}>Signing In…</Text>
                  </View>
                ) : (
                  <Text style={styles.submitLabel}>Sign In</Text>
                )}
              </Pressable>

              <View style={styles.divider} />

              <View style={styles.demoSection}>
                <Text style={styles.demoHeading}>Demo Accounts — password: Password123!</Text>
                {DEMO_ACCOUNTS.map((account) => (
                  <Pressable
                    key={account.email}
                    style={({ pressed }) => [styles.demoRow, pressed && styles.demoRowPressed]}
                    onPress={() => handleDemoSelect(account.email)}>
                    <Text style={styles.demoRole}>{account.role}</Text>
                    <Text style={styles.demoEmail}>{account.email}</Text>
                  </Pressable>
                ))}
              </View>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: PALETTE.background,
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 24,
  },
  card: {
    width: '100%',
    maxWidth: 480,
    backgroundColor: PALETTE.card,
    borderRadius: 18,
    paddingHorizontal: 40,
    paddingVertical: 48,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 24,
    elevation: 8,
  },
  header: {
    alignItems: 'center',
  },
  brandLogo: {
    width: 240,
    maxWidth: '80%',
    aspectRatio: 500 / 131,
  },
  title: {
    marginTop: 28,
    fontSize: 24,
    fontWeight: '700',
    color: PALETTE.textPrimary,
    textAlign: 'center',
  },
  subtitle: {
    marginTop: 8,
    fontSize: 15,
    fontWeight: '400',
    color: PALETTE.textSecondary,
    textAlign: 'center',
  },
  form: {
    marginTop: 32,
    gap: 20,
  },
  field: {
    gap: 8,
  },
  fieldLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: PALETTE.textPrimary,
  },
  inputRow: {
    position: 'relative',
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: PALETTE.card,
    borderWidth: 1,
    borderColor: PALETTE.borderStrong,
    borderRadius: 12,
    height: 50,
    paddingHorizontal: 14,
    outlineWidth: 0,
  },
  inputRowFocused: {
    borderColor: PALETTE.accent,
  },
  inputIcon: {
    position: 'absolute',
    left: 14,
  },
  input: {
    flex: 1,
    height: '100%',
    paddingLeft: 36,
    fontSize: 16,
    color: PALETTE.textPrimary,
    borderWidth: 0,
    outlineWidth: 0,
  },
  optionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  rememberRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  checkbox: {
    width: 20,
    height: 20,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: PALETTE.textPrimary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: PALETTE.accent,
    borderColor: PALETTE.accent,
  },
  rememberLabel: {
    fontSize: 14,
    color: PALETTE.textSecondary,
  },
  forgotLink: {
    fontSize: 14,
    fontWeight: '500',
    color: PALETTE.accent,
  },
  submitButton: {
    height: 52,
    borderRadius: 12,
    backgroundColor: PALETTE.brand,
    alignItems: 'center',
    justifyContent: 'center',
  },
  submitButtonPressed: {
    opacity: 0.85,
  },
  submitButtonDisabled: {
    opacity: 0.7,
  },
  submitLoading: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  submitLabel: {
    fontSize: 16,
    fontWeight: '700',
    color: PALETTE.textPrimary,
  },
  divider: {
    height: 1,
    backgroundColor: PALETTE.border,
    alignSelf: 'center',
    width: '100%',
    marginVertical: 24,
  },
  demoSection: {
    gap: 16,
  },
  demoHeading: {
    fontSize: 13,
    fontWeight: '600',
    color: '#374151',
    textAlign: 'center',
  },
  demoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  demoRowPressed: {
    opacity: 0.6,
  },
  demoRole: {
    fontSize: 14,
    fontWeight: '700',
    color: PALETTE.textPrimary,
  },
  demoEmail: {
    fontSize: 14,
    color: PALETTE.textSecondary,
  },
});