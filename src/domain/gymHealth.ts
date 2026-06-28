import type { BaseEntity, ISODateString, ISODateTimeString } from './shared';
import { sortByIsoDateAsc } from './shared';

export const WORKOUT_TYPES = [
  'push',
  'pull',
  'legs',
  'full-body',
  'cardio',
  'other',
] as const;
export const SLEEP_QUALITY_LEVELS = ['poor', 'fair', 'good', 'great'] as const;
export const HEALTH_ENTRY_SOURCES = ['manual', 'apple-health'] as const;

export type WorkoutType = (typeof WORKOUT_TYPES)[number];
export type SleepQualityLevel = (typeof SLEEP_QUALITY_LEVELS)[number];
export type HealthEntrySource = (typeof HEALTH_ENTRY_SOURCES)[number];

export interface HealthSourceMetadata {
  source: HealthEntrySource;
  importedAt?: ISODateTimeString;
  externalId?: string;
  deviceName?: string;
}

export interface LateEntryMetadata {
  isLateEntry: boolean;
  originalEntryDate: ISODateString;
  enteredAt: ISODateTimeString;
  reason?: string;
}

export interface WeightLog extends BaseEntity {
  area: 'gym-health';
  date: ISODateString;
  weightKg: number;
  source: HealthSourceMetadata;
  lateEntry?: LateEntryMetadata;
  notes?: string;
}

export interface WeightGoal extends BaseEntity {
  area: 'gym-health';
  targetWeightKg: number;
  startWeightKg?: number;
  startDate: ISODateString;
  targetDate?: ISODateString;
  active: boolean;
  notes?: string;
}

export interface DailyHealthLog extends BaseEntity {
  area: 'gym-health';
  date: ISODateString;
  totalCalories?: number;
  gymAttended: boolean;
  workoutDurationMinutes?: number;
  workoutType?: WorkoutType;
  sleepHours?: number;
  sleepQuality?: SleepQualityLevel;
  source: HealthSourceMetadata;
  lateEntry?: LateEntryMetadata;
  notes?: string;
}

export function isLateEntry(date: ISODateString, enteredAt: ISODateTimeString) {
  return enteredAt.slice(0, 10) !== date;
}

export function getLatestWeightLog(logs: readonly WeightLog[]) {
  return sortByIsoDateAsc(logs, (log) => log.date).at(-1);
}

export function getGymAttendanceCount(logs: readonly DailyHealthLog[]) {
  return logs.filter((log) => log.gymAttended).length;
}

export function getAverageSleepHours(logs: readonly DailyHealthLog[]) {
  const logsWithSleep = logs.filter((log) => log.sleepHours !== undefined);

  if (logsWithSleep.length === 0) {
    return 0;
  }

  return (
    logsWithSleep.reduce((total, log) => total + Number(log.sleepHours), 0) /
    logsWithSleep.length
  );
}
