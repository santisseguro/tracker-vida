import { StyleSheet, Text } from 'react-native';

import { Card, ScreenContainer, SectionTitle } from '@/components/ui';
import { colors } from '@/constants/theme';

export default function DashboardScreen() {
  return (
    <ScreenContainer>
      <SectionTitle
        title="Dashboard"
        subtitle="A starting point for the personal daily overview."
      />
      <Card>
        <Text style={styles.cardTitle}>Today</Text>
        <Text style={styles.body}>
          Placeholder for the future cross-area summary.
        </Text>
      </Card>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  cardTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
  },
  body: {
    color: colors.textMuted,
    fontSize: 16,
    lineHeight: 22,
  },
});
