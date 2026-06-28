import { Link } from 'expo-router';

import { Button, Card, ScreenContainer, SectionTitle } from '@/components/ui';

export default function NotFoundScreen() {
  return (
    <ScreenContainer>
      <Card>
        <SectionTitle
          title="Screen not found"
          subtitle="This route is not part of the app shell."
        />
        <Link href="/" asChild>
          <Button>Go to dashboard</Button>
        </Link>
      </Card>
    </ScreenContainer>
  );
}
