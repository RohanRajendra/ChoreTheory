'use client';

import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import BookingCard from '@/components/BookingCard';
import SectionHeader from '@/components/SectionHeader';
import { getUserBookings } from '@/lib/api';
import { Booking } from '@/lib/types';

export default function BookingsPage() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

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
          <BookingCard key={booking.booking_id} booking={booking} />
        ))}
      </div>
    </AppShell>
  );
}