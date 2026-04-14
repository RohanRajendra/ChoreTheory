'use client';

import { FormEvent, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import BookingCard from '@/components/BookingCard';
import SectionHeader from '@/components/SectionHeader';
import {
  createReminder,
  deleteBooking,
  deleteReminder,
  getBookingReminders,
  getUserBookings,
} from '@/lib/api';
import { Booking, Reminder } from '@/lib/types';

export default function BookingsPage() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Reminders state keyed by booking_id
  const [reminders, setReminders] = useState<Record<number, Reminder[]>>({});
  // Which booking's reminder panel is open
  const [openReminders, setOpenReminders] = useState<number | null>(null);

  // Add reminder form state
  const [reminderTime, setReminderTime] = useState('');
  const [reminderMessage, setReminderMessage] = useState('');
  const [reminderError, setReminderError] = useState('');
  const [reminderSuccess, setReminderSuccess] = useState('');

  useEffect(() => {
    async function load() {
      try {
        const email = localStorage.getItem('userEmail');
        if (!email) return;
        const result = await getUserBookings(email);
        setBookings(result);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  async function handleCancel(bookingId: number) {
    if (!confirm('Cancel this booking? Its reminders will also be deleted.')) return;
    try {
      await deleteBooking(bookingId);
      setBookings((prev) => prev.filter((b) => b.booking_id !== bookingId));
      setReminders((prev) => {
        const copy = { ...prev };
        delete copy[bookingId];
        return copy;
      });
    } catch (e) {
      alert((e as Error).message);
    }
  }

  async function loadReminders(bookingId: number) {
    try {
      const result = await getBookingReminders(bookingId);
      setReminders((prev) => ({ ...prev, [bookingId]: result }));
    } catch (e) {
      alert((e as Error).message);
    }
  }

  function toggleReminders(bookingId: number) {
    if (openReminders === bookingId) {
      setOpenReminders(null);
    } else {
      setOpenReminders(bookingId);
      setReminderError('');
      setReminderSuccess('');
      setReminderTime('');
      setReminderMessage('');
      if (!reminders[bookingId]) {
        loadReminders(bookingId);
      }
    }
  }

  async function handleAddReminder(
    event: FormEvent<HTMLFormElement>,
    bookingId: number
  ) {
    event.preventDefault();
    setReminderError('');
    setReminderSuccess('');
    try {
      // Convert datetime-local value to backend format
      const fmt = (dt: string) => dt.replace('T', ' ') + ':00';
      await createReminder({
        booking_id: bookingId,
        reminder_time: fmt(reminderTime),
        message: reminderMessage || undefined,
      });
      // Reload reminders for this booking
      const updated = await getBookingReminders(bookingId);
      setReminders((prev) => ({ ...prev, [bookingId]: updated }));
      setReminderSuccess('Reminder added.');
      setReminderTime('');
      setReminderMessage('');
    } catch (e) {
      setReminderError((e as Error).message);
    }
  }

  async function handleDeleteReminder(reminderId: number, bookingId: number) {
    if (!confirm('Delete this reminder?')) return;
    try {
      await deleteReminder(reminderId, bookingId);
      setReminders((prev) => ({
        ...prev,
        [bookingId]: prev[bookingId].filter((r) => r.reminder_id !== reminderId),
      }));
    } catch (e) {
      alert((e as Error).message);
    }
  }

  return (
    <AppShell>
      <SectionHeader
        title="My Bookings"
        description="All resource bookings you have made."
      />

      {loading && <p className="muted">Loading bookings...</p>}
      {error && <p className="error">{error}</p>}

      {!loading && bookings.length === 0 && (
        <p className="muted">No bookings yet.</p>
      )}

      <div className="grid">
        {bookings.map((booking) => (
          <div key={booking.booking_id}>
            <BookingCard booking={booking} />

            <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem' }}>
              <button
                className="button secondaryButton"
                onClick={() => toggleReminders(booking.booking_id)}
              >
                {openReminders === booking.booking_id
                  ? 'Hide Reminders'
                  : 'View Reminders'}
              </button>

              <button
                className="button secondaryButton"
                onClick={() => handleCancel(booking.booking_id)}
              >
                Cancel Booking
              </button>
            </div>

            {/* Reminders panel */}
            {openReminders === booking.booking_id && (
              <div className="panel" style={{ marginTop: '0.75rem' }}>
                <h4>Reminders</h4>

                {!reminders[booking.booking_id] && (
                  <p className="muted">Loading...</p>
                )}

                {reminders[booking.booking_id]?.length === 0 && (
                  <p className="muted">No reminders yet.</p>
                )}

                {reminders[booking.booking_id]?.map((reminder) => (
                  <div
                    key={reminder.reminder_id}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '0.5rem',
                    }}
                  >
                    <div>
                      <p>
                        {reminder.reminder_time.replace('T', ' ')}{' '}
                        <span className="badge">{reminder.status}</span>
                      </p>
                      {reminder.message && (
                        <p className="muted">{reminder.message}</p>
                      )}
                    </div>
                    <button
                      className="button secondaryButton"
                      onClick={() =>
                        handleDeleteReminder(
                          reminder.reminder_id,
                          booking.booking_id
                        )
                      }
                    >
                      Delete
                    </button>
                  </div>
                ))}

                {/* Add manual reminder form */}
                <h4 style={{ marginTop: '1rem' }}>Add Reminder</h4>
                {reminderError && <p className="error">{reminderError}</p>}
                {reminderSuccess && <p className="success">{reminderSuccess}</p>}
                <form
                  className="formGrid"
                  onSubmit={(e) => handleAddReminder(e, booking.booking_id)}
                >
                  <label>
                    Reminder time
                    <input
                      type="datetime-local"
                      value={reminderTime}
                      onChange={(e) => setReminderTime(e.target.value)}
                      required
                    />
                  </label>

                  <label>
                    Message (optional)
                    <input
                      value={reminderMessage}
                      onChange={(e) => setReminderMessage(e.target.value)}
                      placeholder="e.g. Kitchen booking in 1 hour"
                    />
                  </label>

                  <button className="button" type="submit">
                    Add Reminder
                  </button>
                </form>
              </div>
            )}
          </div>
        ))}
      </div>
    </AppShell>
  );
}