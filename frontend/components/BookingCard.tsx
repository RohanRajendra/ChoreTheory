import { Booking } from '@/lib/types';

export default function BookingCard({ booking }: { booking: Booking }) {
  return (
    <div className="card">
      <div>
        <h3>{booking.resource_name}</h3>
        <p className="muted">House ID: {booking.house_id}</p>
        <p>Start: {booking.start_time.replace('T', ' ')}</p>
        <p>End: {booking.end_time.replace('T', ' ')}</p>
      </div>
    </div>
  );
}