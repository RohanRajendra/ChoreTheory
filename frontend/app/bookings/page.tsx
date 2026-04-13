import AppShell from '@/components/AppShell';
import BookingCard from '@/components/BookingCard';
import SectionHeader from '@/components/SectionHeader';
import { bookings } from '@/lib/mock-data';

export default function BookingsPage() {
  return (
    <AppShell>
      <SectionHeader
        title="My Bookings"
        description="Show every booking made by the current user."
      />

      <div className="grid">
        {bookings.map((booking) => (
          <BookingCard key={booking.id} booking={booking} />
        ))}
      </div>
    </AppShell>
  );
}
