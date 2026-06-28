import { StyleSheet, Text } from 'react-native';

import { Card, ScreenContainer, SectionTitle } from '@/components/ui';
import { colors } from '@/constants/theme';

export default function UniversityScreen() {
  return (
    <ScreenContainer>
      <SectionTitle
        title="University"
        subtitle="Foundation screen for academic organization."
      />
      <Card>
        <Text style={styles.cardTitle}>Academic area</Text>
        <Text style={styles.body}>
          Courses, deadlines, and study tasks will be added in a later task.
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
