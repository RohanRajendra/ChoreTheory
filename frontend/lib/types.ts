// Types aligned with FastAPI backend response shapes.
// email is the user identifier throughout — there is no separate username.

export type User = {
  email: string;
  name: string;
};

// is_admin is per house, not a global user property.
// It is included on the House type as returned by get_user_houses.
export type House = {
  house_id: number;
  name: string;
  address: string;
  is_admin: boolean;          // true if the current user is admin of this house
  role: 'admin' | 'member' | 'guest';
};

export type Resource = {
  resource_id: number;
  house_id: number;
  name: string;
  icon: string | null;
  time_limit: number;         // in minutes
  resource_type: 'space' | 'appliance' | 'base';

  // Space fields — present when resource_type === 'space'
  clean_after_use: boolean | null;
  max_occupancy: number | null;

  // Appliance fields — present when resource_type === 'appliance'
  requires_maintenance: boolean | null;
};

export type Booking = {
  booking_id: number;
  resource_id: number;
  resource_name: string;
  house_id: number;
  start_time: string;
  end_time: string;
  user_email: string;
};

export type Reminder = {
  reminder_id: number;
  booking_id: number;
  reminder_time: string;
  status: 'pending' | 'sent' | 'cancelled';
  message: string | null;
};

export type Expense = {
  expense_id: number;
  amount: number;
  description: string;
  due_date: string;
  creation_date: string;
  receipts_attachment: string | null;
  is_recurring: boolean;
  created_by: string;
  creator_name: string | null;
};

export type ExpenseParticipant = {
  email: string;
  name: string;
  user_share: number;
  payment_status: 'unpaid' | 'paid' | 'partial';
};

export type HouseMember = {
  email: string;
  name: string;
  is_admin: boolean;
  role: 'admin' | 'member' | 'guest';
};

// ==================================================================
// ANALYTICS TYPES
// ==================================================================

export type ExpenseTrendPoint = {
  yr: number;
  mo: number;
  total: number;
};

export type ForecastPoint = {
  yr: number;
  mo: number;
  predicted_amount: number;
};

export type TopSpender = {
  email: string;
  name: string;
  total_spent: number;
};

export type BookingFrequencyItem = {
  resource_id: number;
  resource_name: string;
  resource_type: string;
  booking_count: number;
};

export type SettlementBreakdownItem = {
  payment_status: string;
  cnt: number;
};

export type ResourceUtilizationItem = {
  resource_type: string;
  total_minutes_booked: number;
  booking_count: number;
};

export type ResourceRecommendation = {
  resource_id: number;
  resource_name: string;
  resource_type: string;
  score: number;
};