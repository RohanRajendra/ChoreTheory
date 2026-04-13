import { Booking } from '@/lib/types';

export default function BookingCard({ booking }: { booking: Booking }) {
  return (
    <div className="card">
      <div>
        <h3>{booking.resourceName}</h3>
        <p className="muted">House: {booking.houseName}</p>
        <p>Start: {booking.startTime.replace('T', ' ')}</p>
        <p>End: {booking.endTime.replace('T', ' ')}</p>
        <p className="muted">Reminder: {booking.reminderTime.replace('T', ' ')}</p>
      </div>
    </div>
  );
}
