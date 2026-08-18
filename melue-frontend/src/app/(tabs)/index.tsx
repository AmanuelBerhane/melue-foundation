import { SymbolView } from 'expo-symbols';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useAuthStore } from '@/stores/auth-store';

const PALETTE = {
  background: '#F1F3F5',
  card: '#FFFFFF',
  textPrimary: '#1F2937',
  textSecondary: '#6B7280',
  accent: '#3B82F6',
  brand: '#FBBF24',
  brandDark: '#D97706',
  border: '#E5E7EB',
} as const;

const STATS = [
  { label: 'Sessions Today', value: '0 / 2', icon: 'play.circle' },
  { label: 'Active Students', value: '2', icon: 'person.2' },
  { label: 'Trials Logged', value: '0', icon: 'checkmark.circle' },
  { label: 'Pending Reviews', value: '1', icon: 'doc.text' },
] as const;

const SCHEDULE = [
  { start: '08:00', end: '09:30', block: 'Block 1 · Morning', station: 'Station 1 · Room A', students: 'Yonas G.' },
  { start: '09:30', end: '11:00', block: 'Block 2 · Morning', station: 'Station 2 · Room C', students: 'Meron H.' },
  { start: '11:00', end: '12:30', block: 'Block 3 · Midday', station: 'Station 1 · Room B', students: 'Yonas G.' },
] as const;

function greetingForHour(hour: number): string {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

function mockEmailFromToken(token: string | null): string | null {
  return token?.startsWith('mock-') ? token.slice(5) : null;
}

function StatCard({ label, value, icon }: { label: string; value: string; icon: string }) {
  return (
    <View style={styles.statCard}>
      <View style={styles.statIconRow}>
        <SymbolView
          name={{ ios: icon as never, android: 'circle', web: 'circle' }}
          tintColor={PALETTE.accent}
          size={18}
        />
        <Text style={styles.statValue}>{value}</Text>
      </View>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

export default function DashboardScreen() {
  const token = useAuthStore((state) => state.token);
  const signOut = useAuthStore((state) => state.signOut);

  const email = mockEmailFromToken(token);
  const greeting = greetingForHour(new Date().getHours());
  const dateLabel = new Date().toLocaleDateString(undefined, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  function handleLogout() {
    void signOut();
  }

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <View style={styles.headerText}>
            <Text style={styles.greeting}>
              {greeting},
            </Text>
            <Text style={styles.name}>{email ?? 'Staff Member'}</Text>
            <Text style={styles.dateLabel}>{dateLabel}</Text>
          </View>
          <Pressable
            accessibilityRole="button"
            style={({ pressed }) => [styles.logoutButton, pressed && styles.pressed]}
            onPress={handleLogout}>
            <SymbolView
              name={{ ios: 'rectangle.portrait.and.arrow.right', android: 'logout', web: 'logout' }}
              tintColor={PALETTE.textSecondary}
              size={18}
            />
            <Text style={styles.logoutLabel}>Sign Out</Text>
          </Pressable>
        </View>

        <View style={styles.statsGrid}>
          {STATS.map((stat) => (
            <StatCard key={stat.label} {...stat} />
          ))}
        </View>

        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Today&apos;s Schedule</Text>
            <Text style={styles.moreLabel}>3 sessions</Text>
          </View>

          {SCHEDULE.map((item) => (
            <View key={item.block} style={styles.scheduleCard}>
              <View style={styles.timeColumn}>
                <Text style={styles.timeStart}>{item.start}</Text>
                <Text style={styles.timeEnd}>{item.end}</Text>
              </View>
              <View style={styles.scheduleDivider} />
              <View style={styles.scheduleBody}>
                <Text style={styles.scheduleBlock}>{item.block}</Text>
                <Text style={styles.scheduleMeta}>{item.station}</Text>
                <View style={styles.studentChip}>
                  <Text style={styles.studentChipText}>{item.students}</Text>
                </View>
              </View>
            </View>
          ))}
        </View>

        <View style={styles.mockNote}>
          <Text style={styles.mockNoteText}>Mock dashboard — static data for UI development.</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: PALETTE.background,
  },
  content: {
    padding: 20,
    gap: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
  },
  headerText: {
    flex: 1,
    gap: 2,
  },
  greeting: {
    fontSize: 26,
    fontWeight: '700',
    color: PALETTE.textPrimary,
  },
  name: {
    fontSize: 18,
    fontWeight: '600',
    color: PALETTE.brandDark,
  },
  dateLabel: {
    fontSize: 14,
    color: PALETTE.textSecondary,
    marginTop: 2,
  },
  logoutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: PALETTE.border,
    backgroundColor: PALETTE.card,
  },
  logoutLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: PALETTE.textSecondary,
  },
  pressed: {
    opacity: 0.7,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  statCard: {
    flexBasis: '47%',
    flexGrow: 1,
    backgroundColor: PALETTE.card,
    borderRadius: 14,
    padding: 16,
    gap: 10,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  statIconRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  statValue: {
    fontSize: 24,
    fontWeight: '800',
    color: PALETTE.textPrimary,
  },
  statLabel: {
    fontSize: 13,
    color: PALETTE.textSecondary,
  },
  section: {
    gap: 12,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: PALETTE.textPrimary,
  },
  moreLabel: {
    fontSize: 14,
    color: PALETTE.accent,
    fontWeight: '600',
  },
  scheduleCard: {
    flexDirection: 'row',
    alignItems: 'stretch',
    backgroundColor: PALETTE.card,
    borderRadius: 14,
    padding: 16,
    gap: 16,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  timeColumn: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
    minWidth: 52,
  },
  timeStart: {
    fontSize: 16,
    fontWeight: '700',
    color: PALETTE.textPrimary,
  },
  timeEnd: {
    fontSize: 12,
    color: PALETTE.textSecondary,
  },
  scheduleDivider: {
    width: 1,
    backgroundColor: PALETTE.border,
  },
  scheduleBody: {
    flex: 1,
    gap: 6,
  },
  scheduleBlock: {
    fontSize: 16,
    fontWeight: '700',
    color: PALETTE.textPrimary,
  },
  scheduleMeta: {
    fontSize: 13,
    color: PALETTE.textSecondary,
  },
  studentChip: {
    alignSelf: 'flex-start',
    backgroundColor: '#FEF3C7',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  studentChipText: {
    fontSize: 13,
    fontWeight: '600',
    color: PALETTE.brandDark,
  },
  mockNote: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  mockNoteText: {
    fontSize: 12,
    color: PALETTE.textSecondary,
  },
});