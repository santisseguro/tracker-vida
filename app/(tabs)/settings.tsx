import { StyleSheet, Text } from 'react-native';

import { Card, ScreenContainer, SectionTitle } from '@/components/ui';
import { colors } from '@/constants/theme';

export default function SettingsScreen() {
  return (
    <ScreenContainer>
      <SectionTitle
        title="Settings"
        subtitle="Foundation screen for app preferences and data controls."
      />
      <Card>
        <Text style={styles.cardTitle}>Settings area</Text>
        <Text style={styles.body}>
          Preferences and data management controls will be added in a later
          task.
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
