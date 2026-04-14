'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import { getUser } from '@/lib/api';

export default function ProfilePage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function load() {
      try {
        const storedEmail = localStorage.getItem('userEmail');
        if (!storedEmail) return;
        const result = await getUser(storedEmail);
        setName(result.name);
        setEmail(result.email);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  function handleLogout() {
    localStorage.removeItem('userEmail');
    localStorage.removeItem('userName');
  }

  return (
    <AppShell>
      <SectionHeader title="Profile" description="Your account information." />

      {loading && <p className="muted">Loading...</p>}
      {error && <p className="error">{error}</p>}

      {!loading && !error && (
        <section className="panel">
          <p><strong>Name:</strong> {name}</p>
          <p><strong>Email:</strong> {email}</p>

          <Link href="/login" className="button logoutButton" onClick={handleLogout}>
            Logout
          </Link>
        </section>
      )}
    </AppShell>
  );
}