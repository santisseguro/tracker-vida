import type { ComponentProps } from 'react';
import type { ColorValue } from 'react-native';
import { SymbolView } from 'expo-symbols';
import { Tabs } from 'expo-router';

import { colors } from '@/constants/theme';

type TabIconProps = {
  color: ColorValue;
  name: ComponentProps<typeof SymbolView>['name'];
};

function TabIcon({ color, name }: TabIconProps) {
  return <SymbolView name={name} tintColor={color} size={24} />;
}

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.tabInactive,
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Dashboard',
          tabBarIcon: ({ color }) => (
            <TabIcon color={color} name="house.fill" />
          ),
        }}
      />
      <Tabs.Screen
        name="gym-health"
        options={{
          title: 'Health',
          tabBarIcon: ({ color }) => (
            <TabIcon color={color} name="heart.fill" />
          ),
        }}
      />
      <Tabs.Screen
        name="university"
        options={{
          title: 'University',
          tabBarIcon: ({ color }) => (
            <TabIcon color={color} name="graduationcap.fill" />
          ),
        }}
      />
      <Tabs.Screen
        name="money"
        options={{
          title: 'Money',
          tabBarIcon: ({ color }) => (
            <TabIcon color={color} name="dollarsign.circle.fill" />
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Settings',
          tabBarIcon: ({ color }) => (
            <TabIcon color={color} name="gearshape.fill" />
          ),
        }}
      />
    </Tabs>
  );
}
