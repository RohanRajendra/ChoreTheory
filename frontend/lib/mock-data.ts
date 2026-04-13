import { Booking, Expense, House, Resource, User } from './types';

export const currentUser: User = {
  username: 'atharva',
  name: 'Atharva',
  isAdmin: true,
};

export const houses: House[] = [
  {
    id: '1',
    name: 'Maple House',
    address: '12 Maple St',
    isCurrentUserAdmin: true,
  },
  {
    id: '2',
    name: 'River House',
    address: '88 River Ave',
    isCurrentUserAdmin: false,
  },
];

export const resources: Resource[] = [
  {
    id: 'r1',
    houseId: '1',
    name: 'Laundry Room',
    icon: '🧺',
    timeLimit: '2 hours',
    type: 'space',
  },
  {
    id: 'r2',
    houseId: '1',
    name: 'TV Room',
    icon: '📺',
    timeLimit: '3 hours',
    type: 'space',
  },
  {
    id: 'r3',
    houseId: '1',
    name: 'Dishwasher',
    icon: '🍽️',
    timeLimit: '1 hour',
    type: 'appliance',
  },
  {
    id: 'r4',
    houseId: '2',
    name: 'Parking Spot',
    icon: '🚗',
    timeLimit: '8 hours',
    type: 'space',
  },
];

export const bookings: Booking[] = [
  {
    id: 'b1',
    resourceId: 'r1',
    resourceName: 'Laundry Room',
    houseName: 'Maple House',
    startTime: '2026-04-15T18:00',
    endTime: '2026-04-15T20:00',
    reminderTime: '2026-04-15T17:30',
  },
  {
    id: 'b2',
    resourceId: 'r4',
    resourceName: 'Parking Spot',
    houseName: 'River House',
    startTime: '2026-04-16T09:00',
    endTime: '2026-04-16T17:00',
    reminderTime: '2026-04-16T08:30',
  },
];

export const expenses: Expense[] = [
  {
    id: 'e1',
    houseId: '1',
    amount: 120,
    description: 'Electricity bill',
    dueDate: '2026-04-20',
    createdBy: 'atharva',
    splitCount: 4,
  },
  {
    id: 'e2',
    houseId: '1',
    amount: 40,
    description: 'Cleaning supplies',
    dueDate: '2026-04-18',
    createdBy: 'jane',
    splitCount: 4,
  },
];
