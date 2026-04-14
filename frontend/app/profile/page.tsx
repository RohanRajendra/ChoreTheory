'use client';

import Link from 'next/link';
import { FormEvent, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import { getUser, updateUser } from '@/lib/api';

export default function ProfilePage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Edit form state
  const [editName, setEditName] = useState('');
  const [editPassword, setEditPassword] = useState('');
  const [updateError, setUpdateError] = useState('');
  const [updateSuccess, setUpdateSuccess] = useState('');

  useEffect(() => {
    async function load() {
      try {
        const storedEmail = localStorage.getItem('userEmail');
        if (!storedEmail) return;
        const result = await getUser(storedEmail);
        setName(result.name);
        setEmail(result.email);
        setEditName(result.name);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  async function handleUpdate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setUpdateError('');
    setUpdateSuccess('');
    try {
      await updateUser(email, {
        name: editName || undefined,
        password: editPassword || undefined,
      });
      setName(editName);
      localStorage.setItem('userName', editName);
      setEditPassword('');
      setUpdateSuccess('Profile updated successfully.');
    } catch (e) {
      setUpdateError((e as Error).message);
    }
  }

  function handleLogout() {
    localStorage.removeItem('userEmail');
    localStorage.removeItem('userName');
    localStorage.removeItem('userHouses');
  }

  return (
    <AppShell>
      <SectionHeader title="Profile" description="Your account information." />

      {loading && <p className="muted">Loading...</p>}
      {error && <p className="error">{error}</p>}

      {!loading && !error && (
        <>
          <section className="panel">
            <p><strong>Name:</strong> {name}</p>
            <p><strong>Email:</strong> {email}</p>

            <Link
              href="/login"
              className="button logoutButton"
              onClick={handleLogout}
            >
              Logout
            </Link>
          </section>

          <section className="panel">
            <h2>Edit Profile</h2>
            {updateError && <p className="error">{updateError}</p>}
            {updateSuccess && <p className="success">{updateSuccess}</p>}
            <form className="formGrid" onSubmit={handleUpdate}>
              <label>
                Name
                <input
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                />
              </label>

              <label>
                New password
                <input
                  type="password"
                  placeholder="Leave blank to keep current"
                  value={editPassword}
                  onChange={(e) => setEditPassword(e.target.value)}
                />
              </label>

              <button className="button" type="submit">
                Save Changes
              </button>
            </form>
          </section>
        </>
      )}
    </AppShell>
  );
}