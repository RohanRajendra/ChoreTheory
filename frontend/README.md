# HouseMate Frontend

A basic multi-page Next.js + TypeScript frontend for a shared-house booking and expense app.

## Features included
- Login page
- Signup page
- House list view
- House details page
- Add resource form (admin only in UI)
- Add member by username form (admin only in UI)
- Resource booking page
- My bookings page
- Profile page with logout button
- House expenses page with equal-split display
- Reminder note for bookings (30 minutes before start time)

## 1. Create a new Next.js app
You can either use this starter directly, or create a fresh app:

```bash
npx create-next-app@latest housemate-frontend --typescript --app
cd housemate-frontend
```

When prompted:
- TypeScript: Yes
- ESLint: Yes or No, either is fine
- Tailwind: No for this simple version
- src/ directory: No
- App Router: Yes
- Import alias: Yes

## 2. Install dependencies
```bash
npm install
```

## 3. Run the app
```bash
npm run dev
```

Open `http://localhost:3000`

## 4. Main folders
- `app/` → pages
- `components/` → reusable UI parts
- `lib/types.ts` → TypeScript types
- `lib/mock-data.ts` → fake data for now
- `lib/api.ts` → placeholder API calls to replace with FastAPI later

## 5. How to connect to FastAPI later
In `lib/api.ts`, replace the placeholder functions with `fetch` calls.

Example:
```ts
export async function loginUser(payload: { username: string; password: string }) {
  const response = await fetch('http://127.0.0.1:8000/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error('Login failed');
  }

  return response.json();
}
```

## 6. Suggested FastAPI routes
- `POST /auth/signup`
- `POST /auth/login`
- `GET /houses`
- `POST /houses`
- `POST /houses/{house_id}/members`
- `GET /houses/{house_id}/resources`
- `POST /houses/{house_id}/resources`
- `POST /resources/{resource_id}/bookings`
- `GET /bookings/me`
- `GET /profile/me`
- `GET /houses/{house_id}/expenses`
- `POST /houses/{house_id}/expenses`

## 7. Reminder logic
The frontend should send the booking request.
The backend should:
1. save the booking
2. calculate `start_time - 30 minutes`
3. create the reminder record automatically

## 8. Why this frontend is intentionally simple
This version is meant to be easy to understand:
- no complex state management
- local page state only
- simple reusable cards
- mock data first, backend wiring later

