export type User = {
  username: string;
  name: string;
  isAdmin: boolean;
};

export type House = {
  id: string;
  name: string;
  address: string;
  isCurrentUserAdmin: boolean;
};

export type Resource = {
  id: string;
  houseId: string;
  name: string;
  icon: string;
  timeLimit: string;
  type: 'space' | 'appliance';
};

export type Booking = {
  id: string;
  resourceId: string;
  resourceName: string;
  houseName: string;
  startTime: string;
  endTime: string;
  reminderTime: string;
};

export type Expense = {
  id: string;
  houseId: string;
  amount: number;
  description: string;
  dueDate: string;
  createdBy: string;
  splitCount: number;
};
