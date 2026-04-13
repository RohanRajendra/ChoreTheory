// Replace these placeholder functions with real FastAPI calls later.
// Keeping them in one file makes the UI easier to connect to the backend.

export async function loginUser(payload: { username: string; password: string }) {
  console.log('POST /auth/login', payload);
  return { success: true };
}

export async function signupUser(payload: {
  username: string;
  name: string;
  password: string;
}) {
  console.log('POST /auth/signup', payload);
  return { success: true };
}

export async function createHouse(payload: { name: string; address: string }) {
  console.log('POST /houses', payload);
  return { success: true };
}

export async function addResource(payload: {
  houseId: string;
  name: string;
  icon: string;
  timeLimit: string;
  type: 'space' | 'appliance';
}) {
  console.log('POST /resources', payload);
  return { success: true };
}

export async function addMemberToHouse(payload: { houseId: string; username: string }) {
  console.log('POST /houses/add-member', payload);
  return { success: true };
}

export async function createBooking(payload: {
  resourceId: string;
  startTime: string;
  endTime: string;
}) {
  console.log('POST /bookings', payload);
  console.log('Reminder should be created 30 minutes before start time by backend.');
  return { success: true };
}

export async function createExpense(payload: {
  houseId: string;
  amount: number;
  description: string;
  dueDate: string;
}) {
  console.log('POST /expenses', payload);
  return { success: true };
}
