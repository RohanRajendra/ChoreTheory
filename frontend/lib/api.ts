// All API calls to the FastAPI backend.
// Base URL is read from the environment variable NEXT_PUBLIC_API_URL.
// Add this to your .env.local file:
//   NEXT_PUBLIC_API_URL=http://127.0.0.1:8000

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://127.0.0.1:8000';

// ------------------------------------------------------------------
// Internal helper
// Makes a fetch call and throws a readable error if the response
// is not ok. Surfaces the detail message from FastAPI error bodies.
// ------------------------------------------------------------------
async function request<T>(
  path: string,
  options?: RequestInit
): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: 'Unknown error' }));
    throw new Error(error.detail ?? 'Request failed');
  }

  // 204 No Content — return null
  if (response.status === 204) return null as T;

  return response.json();
}


// ==================================================================
// USERS
// ==================================================================

// Note: the frontend uses 'username' in its forms but the backend
// uses email as the identifier. Map username → email at the call site.

export async function loginUser(payload: {
  email: string;
  password: string;
}) {
  return request<{ message: string; email: string; name: string }>(
    '/users/login',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function signupUser(payload: {
  email: string;
  name: string;
  password: string;
}) {
  return request<{ message: string; email: string }>(
    '/users',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function getUser(email: string) {
  return request<{ email: string; name: string }>(
    `/users/${encodeURIComponent(email)}`
  );
}

export async function updateUser(
  email: string,
  payload: { name?: string; password?: string }
) {
  return request<{ message: string }>(
    `/users/${encodeURIComponent(email)}`,
    {
      method: 'PUT',
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteUser(email: string) {
  return request<{ message: string }>(
    `/users/${encodeURIComponent(email)}`,
    { method: 'DELETE' }
  );
}


// ==================================================================
// HOUSES
// ==================================================================

export async function getUserHouses(email: string) {
  return request<
    Array<{
      house_id: number;
      name: string;
      address: string;
      is_admin: boolean;
      role: 'admin' | 'member' | 'guest';
    }>
  >(`/houses/user/${encodeURIComponent(email)}`);
}

export async function getHouse(houseId: number) {
  return request<{ house_id: number; name: string; address: string }>(
    `/houses/${houseId}`
  );
}

export async function createHouse(payload: {
  address: string;
  name: string;
  creator_email: string;
}) {
  return request<{ message: string; house_id: number }>(
    '/houses',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function updateHouse(
  houseId: number,
  payload: { address?: string; name?: string }
) {
  return request<{ message: string }>(
    `/houses/${houseId}`,
    {
      method: 'PUT',
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteHouse(houseId: number) {
  return request<{ message: string }>(
    `/houses/${houseId}`,
    { method: 'DELETE' }
  );
}

export async function getHouseMembers(houseId: number) {
  return request<Array<{ email: string; name: string; is_admin: boolean; role: 'admin' | 'member' | 'guest' }>>(
    `/houses/${houseId}/members`
  );
}

// Admin only — admin_email must belong to a user who is_admin for this house.
export async function addMemberToHouse(payload: {
  houseId: number;
  admin_email: string;
  new_user_email: string;
  role?: 'member' | 'guest';
}) {
  return request<{ message: string }>(
    `/houses/${payload.houseId}/members`,
    {
      method: 'POST',
      body: JSON.stringify({
        admin_email: payload.admin_email,
        new_user_email: payload.new_user_email,
        role: payload.role ?? 'member',
      }),
    }
  );
}

export async function removeMemberFromHouse(houseId: number, email: string) {
  return request<{ message: string }>(
    `/houses/${houseId}/members/${encodeURIComponent(email)}`,
    { method: 'DELETE' }
  );
}

export async function getHouseBalance(houseId: number) {
  return request<{ house_id: number; total_expenses: number }>(
    `/houses/${houseId}/balance`
  );
}


// ==================================================================
// RESOURCES
// ==================================================================

export async function getHouseResources(houseId: number) {
  return request<
    Array<{
      resource_id: number;
      name: string;
      time_limit: number;
      icon: string | null;
      resource_type: 'space' | 'appliance' | 'base';
      clean_after_use: boolean | null;
      max_occupancy: number | null;
      requires_maintenance: boolean | null;
    }>
  >(`/resources/house/${houseId}`);
}

export async function getResource(resourceId: number) {
  return request<{
    resource_id: number;
    name: string;
    time_limit: number;
    icon: string | null;
    house_id: number;
    resource_type: 'space' | 'appliance' | 'base';
    clean_after_use: boolean | null;
    max_occupancy: number | null;
    requires_maintenance: boolean | null;
  }>(`/resources/${resourceId}`);
}

export async function checkResourceAvailability(
  resourceId: number,
  startTime: string,
  endTime: string
) {
  const params = new URLSearchParams({ start_time: startTime, end_time: endTime });
  return request<{ resource_id: number; available: boolean }>(
    `/resources/${resourceId}/availability?${params}`
  );
}

export async function addResource(payload: {
  name: string;
  time_limit: number;
  icon?: string;
  house_id: number;
  subclass?: 'space' | 'appliance';
  clean_after_use?: boolean;
  max_occupancy?: number;
  requires_maintenance?: boolean;
}) {
  return request<{ message: string; resource_id: number; subclass: string }>(
    '/resources',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function updateResource(
  resourceId: number,
  payload: { name?: string; time_limit?: number; icon?: string }
) {
  return request<{ message: string }>(
    `/resources/${resourceId}`,
    {
      method: 'PUT',
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteResource(resourceId: number) {
  return request<{ message: string }>(
    `/resources/${resourceId}`,
    { method: 'DELETE' }
  );
}


// ==================================================================
// BOOKINGS
// ==================================================================

export async function getUserBookings(email: string) {
  return request<
    Array<{
      booking_id: number;
      start_time: string;
      end_time: string;
      resource_id: number;
      resource_name: string;
      house_id: number;
    }>
  >(`/bookings/user/${encodeURIComponent(email)}`);
}

export async function getBooking(bookingId: number) {
  return request<{
    booking_id: number;
    start_time: string;
    end_time: string;
    user_email: string;
    resource_id: number;
    resource_name: string;
  }>(`/bookings/${bookingId}`);
}

export async function createBooking(payload: {
  user_email: string;
  resource_id: number;
  start_time: string;
  end_time: string;
}) {
  return request<{ message: string }>(
    '/bookings',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteBooking(bookingId: number) {
  return request<{ message: string }>(
    `/bookings/${bookingId}`,
    { method: 'DELETE' }
  );
}


// ==================================================================
// REMINDERS
// ==================================================================

export async function getBookingReminders(bookingId: number) {
  return request<
    Array<{
      reminder_id: number;
      booking_id: number;
      reminder_time: string;
      status: 'pending' | 'sent' | 'cancelled';
      message: string | null;
    }>
  >(`/reminders/booking/${bookingId}`);
}

export async function createReminder(payload: {
  booking_id: number;
  reminder_time: string;
  message?: string;
}) {
  return request<{ message: string }>(
    '/reminders',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function updateReminder(
  reminderId: number,
  payload: { booking_id: number; reminder_time?: string; message?: string }
) {
  return request<{ message: string }>(
    `/reminders/${reminderId}`,
    {
      method: 'PUT',
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteReminder(reminderId: number, bookingId: number) {
  return request<{ message: string }>(
    `/reminders/${reminderId}?booking_id=${bookingId}`,
    { method: 'DELETE' }
  );
}


// ==================================================================
// EXPENSES
// ==================================================================

export async function getUserExpenses(email: string) {
  return request<
    Array<{
      expense_id: number;
      amount: number;
      description: string;
      due_date: string;
      is_recurring: boolean;
      created_by: string;
      user_share: number;
      payment_status: 'unpaid' | 'paid' | 'partial';
    }>
  >(`/expenses/user/${encodeURIComponent(email)}`);
}

export async function getExpense(expenseId: number) {
  return request<{
    expense_id: number;
    amount: number;
    description: string;
    due_date: string;
    creation_date: string;
    receipts_attachment: string | null;
    is_recurring: boolean;
    created_by: string;
    creator_name: string | null;
  }>(`/expenses/${expenseId}`);
}

export async function getExpenseParticipants(expenseId: number) {
  return request<
    Array<{
      email: string;
      name: string;
      user_share: number;
      payment_status: 'unpaid' | 'paid' | 'partial';
    }>
  >(`/expenses/${expenseId}/participants`);
}

export async function getUserBalance(email: string, houseId: number) {
  return request<{ email: string; house_id: number; outstanding_balance: number }>(
    `/expenses/user/${encodeURIComponent(email)}/balance/${houseId}`
  );
}

export async function createExpense(payload: {
  amount: number;
  description: string;
  due_date: string;
  receipts_attachment?: string;
  is_recurring: boolean;
  created_by: string;
}) {
  return request<{ message: string }>(
    '/expenses',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function splitExpense(
  expenseId: number,
  payload: { email: string; user_share: number }
) {
  return request<{ message: string; user_share: number }>(
    `/expenses/${expenseId}/split`,
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  );
}

export async function settlePayment(expenseId: number, email: string) {
  return request<{ message: string }>(
    `/expenses/${expenseId}/settle/${encodeURIComponent(email)}`,
    { method: 'PUT' }
  );
}

export async function deleteExpense(expenseId: number) {
  return request<{ message: string }>(
    `/expenses/${expenseId}`,
    { method: 'DELETE' }
  );
}


// ==================================================================
// ANALYTICS
// ==================================================================

export async function getExpenseTrend(houseId: number) {
  return request<Array<{ yr: number; mo: number; total_amount: number }>>(
    `/analytics/houses/${houseId}/expense-trend`
  );
}

export async function getTopSpenders(houseId: number) {
  return request<Array<{ email: string; name: string; total_spent: number }>>(
    `/analytics/houses/${houseId}/top-spenders`
  );
}

export async function getBookingFrequency(houseId: number) {
  return request<Array<{ resource_id: number; resource_name: string; resource_type: string; booking_count: number }>>(
    `/analytics/houses/${houseId}/booking-frequency`
  );
}

export async function getSettlementBreakdown(houseId: number) {
  return request<Array<{ payment_status: string; cnt: number }>>(
    `/analytics/houses/${houseId}/settlement-breakdown`
  );
}

export async function getResourceUtilization(houseId: number) {
  return request<Array<{ resource_type: string; total_minutes_booked: number; booking_count: number }>>(
    `/analytics/houses/${houseId}/resource-utilization`
  );
}


// ==================================================================
// ML
// ==================================================================

export async function getExpenseForecast(houseId: number) {
  return request<{
    historical: Array<{ yr: number; mo: number; total: number }>;
    forecast: Array<{ yr: number; mo: number; predicted_amount: number }>;
    message?: string;
  }>(`/ml/houses/${houseId}/expense-forecast`);
}

export async function getResourceRecommendations(houseId: number, userEmail: string) {
  return request<{
    user_email: string;
    recommendations: Array<{ resource_id: number; resource_name: string; resource_type: string; score: number }>;
    message?: string;
  }>(`/ml/houses/${houseId}/resource-recommendations?user_email=${encodeURIComponent(userEmail)}`);
}