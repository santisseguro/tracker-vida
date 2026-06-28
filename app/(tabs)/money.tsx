import { StyleSheet, Text } from 'react-native';

import { Card, ScreenContainer, SectionTitle } from '@/components/ui';
import { colors } from '@/constants/theme';

export default function MoneyScreen() {
  return (
    <ScreenContainer>
      <SectionTitle
        title="Money"
        subtitle="Foundation screen for personal finance tracking."
      />
      <Card>
        <Text style={styles.cardTitle}>Money area</Text>
        <Text style={styles.body}>
          Transactions, categories, and summaries will be added in a later task.
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
