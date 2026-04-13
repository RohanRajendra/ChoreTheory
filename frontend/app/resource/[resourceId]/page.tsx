'use client';

import { FormEvent, useMemo, useState } from 'react';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import { createBooking } from '@/lib/api';
import { resources } from '@/lib/mock-data';

export default function ResourceBookingPage({ params }: { params: { resourceId: string } }) {
  const resource = useMemo(
    () => resources.find((item) => item.id === params.resourceId),
    [params.resourceId]
  );

  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');

  if (!resource) {
    return <AppShell><p>Resource not found.</p></AppShell>;
  }

  async function handleBooking(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await createBooking({ resourceId: resource.id, startTime, endTime });
    alert('Booking submitted. Backend should also generate a reminder 30 minutes before start.');
    setStartTime('');
    setEndTime('');
  }

  return (
    <AppShell>
      <SectionHeader
        title={`Book ${resource.name}`}
        description={`Resource type: ${resource.type} • Time limit: ${resource.timeLimit}`}
      />

      <section className="panel">
        <form className="formGrid" onSubmit={handleBooking}>
          <label>
            Start time
            <input
              type="datetime-local"
              value={startTime}
              onChange={(e) => setStartTime(e.target.value)}
              required
            />
          </label>

          <label>
            End time
            <input
              type="datetime-local"
              value={endTime}
              onChange={(e) => setEndTime(e.target.value)}
              required
            />
          </label>

          <div className="infoBox">
            A reminder should be generated automatically for <strong>30 minutes before</strong> the booking
            start time.
          </div>

          <button className="button" type="submit">
            Create Booking
          </button>
        </form>
      </section>
    </AppShell>
  );
}
