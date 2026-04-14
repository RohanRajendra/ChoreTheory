'use client';

import { FormEvent, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import { createBooking, getResource } from '@/lib/api';
import { Resource } from '@/lib/types';
import { use } from 'react';

export default function ResourceBookingPage({ params }: { params: Promise<{ resourceId: string }> }) {
  const { resourceId: resourceIdStr } = use(params);
  const resourceId = Number(resourceIdStr);

  const [resource, setResource] = useState<Resource | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [formError, setFormError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    async function load() {
      try {
        const result = await getResource(resourceId);
        setResource(result);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [resourceId]);

  async function handleBooking(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError('');
    setSuccess('');
    try {
      const email = localStorage.getItem('userEmail');
      if (!email) throw new Error('Not logged in.');
      // Convert datetime-local value (YYYY-MM-DDTHH:mm) to
      // ISO string the backend expects (YYYY-MM-DD HH:MM:SS)
      const fmt = (dt: string) => dt.replace('T', ' ') + ':00';
      await createBooking({
        user_email: email,
        resource_id: resourceId,
        start_time: fmt(startTime),
        end_time: fmt(endTime),
      });
      setSuccess('Booking created. A 30-minute reminder has been set automatically.');
      setStartTime('');
      setEndTime('');
    } catch (e) {
      setFormError((e as Error).message);
    }
  }

  if (loading) return <AppShell><p className="muted">Loading...</p></AppShell>;
  if (error) return <AppShell><p className="error">{error}</p></AppShell>;
  if (!resource) return <AppShell><p>Resource not found.</p></AppShell>;

  return (
    <AppShell>
      <SectionHeader
        title={`Book ${resource.name}`}
        description={`Type: ${resource.resource_type} • Time limit: ${resource.time_limit} min`}
      />

      <section className="panel">
        {formError && <p className="error">{formError}</p>}
        {success && <p className="success">{success}</p>}

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
            A reminder will be generated automatically for{' '}
            <strong>30 minutes before</strong> your booking start time.
          </div>

          <button className="button" type="submit">
            Create Booking
          </button>
        </form>
      </section>
    </AppShell>
  );
}