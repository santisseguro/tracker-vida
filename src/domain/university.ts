import type {
  BaseEntity,
  CompletionStatus,
  EntityId,
  ISODateString,
  LinkedResource,
  PriorityLevel,
} from './shared';

export const COURSE_STATUSES = [
  'planned',
  'active',
  'completed',
  'dropped',
] as const;
export const ACADEMIC_TASK_TYPES = [
  'assignment',
  'exam',
  'reading',
  'project',
  'study',
  'admin',
  'other',
] as const;
export const ACADEMIC_URGENCY_LEVELS = [
  'overdue',
  'due-today',
  'upcoming',
  'later',
  'completed',
] as const;

export type CourseStatus = (typeof COURSE_STATUSES)[number];
export type AcademicTaskType = (typeof ACADEMIC_TASK_TYPES)[number];
export type AcademicUrgencyLevel = (typeof ACADEMIC_URGENCY_LEVELS)[number];

export interface Course extends BaseEntity {
  area: 'university';
  name: string;
  code?: string;
  term?: string;
  instructor?: string;
  status: CourseStatus;
  color?: string;
  notes?: string;
  links?: LinkedResource[];
}

export interface AcademicTask extends BaseEntity {
  area: 'university';
  courseId?: EntityId;
  title: string;
  type: AcademicTaskType;
  status: CompletionStatus;
  priority: PriorityLevel;
  dueDate?: ISODateString;
  completedAt?: ISODateString;
  notes?: string;
  links?: LinkedResource[];
}

export function isAcademicTaskComplete(task: AcademicTask) {
  return task.status === 'done' || task.status === 'skipped';
}

export function isAcademicTaskOverdue(
  task: AcademicTask,
  today: ISODateString,
) {
  return Boolean(
    task.dueDate && task.dueDate < today && !isAcademicTaskComplete(task),
  );
}

export function getAcademicTaskUrgency(
  task: AcademicTask,
  today: ISODateString,
): AcademicUrgencyLevel {
  if (isAcademicTaskComplete(task)) {
    return 'completed';
  }

  if (!task.dueDate) {
    return 'later';
  }

  if (task.dueDate < today) {
    return 'overdue';
  }

  if (task.dueDate === today) {
    return 'due-today';
  }

  return 'upcoming';
}
