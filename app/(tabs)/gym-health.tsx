import { StyleSheet, Text } from 'react-native';

import { Card, ScreenContainer, SectionTitle } from '@/components/ui';
import { colors } from '@/constants/theme';

export default function GymHealthScreen() {
  return (
    <ScreenContainer>
      <SectionTitle
        title="Gym / Health"
        subtitle="Foundation screen for health and workout tracking."
      />
      <Card>
        <Text style={styles.cardTitle}>Health area</Text>
        <Text style={styles.body}>
          Workout logs, habits, and metrics will be added in a later task.
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
