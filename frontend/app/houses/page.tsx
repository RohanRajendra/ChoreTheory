'use client';

import { FormEvent, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import HouseCard from '@/components/HouseCard';
import SectionHeader from '@/components/SectionHeader';
import { createHouse, getUserHouses } from '@/lib/api';
import { House } from '@/lib/types';

export default function HouseListPage() {
  const [houses, setHouses] = useState<House[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [houseName, setHouseName] = useState('');
  const [address, setAddress] = useState('');
  const [formError, setFormError] = useState('');

  useEffect(() => {
    async function loadHouses() {
      try {
        const email = localStorage.getItem('userEmail');
        if (!email) return;
        const result = await getUserHouses(email);
        setHouses(result);
        // Store houses so [houseId]/page.tsx can read is_admin
        // without an extra API call.
        localStorage.setItem('userHouses', JSON.stringify(result));
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    loadHouses();
  }, []);

  async function handleCreateHouse(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError('');
    try {
      const email = localStorage.getItem('userEmail');
      if (!email) throw new Error('Not logged in.');
      const result = await createHouse({ name: houseName, address, creator_email: email });
      const newHouse: House = {
        house_id: result.house_id,
        name: houseName,
        address,
        is_admin: true,
      };
      const updated = [...houses, newHouse];
      setHouses(updated);
      localStorage.setItem('userHouses', JSON.stringify(updated));
      setHouseName('');
      setAddress('');
    } catch (e) {
      setFormError((e as Error).message);
    }
  }

  return (
    <AppShell>
      <SectionHeader
        title="Your Houses"
        description="All houses you belong to."
      />

      {loading && <p className="muted">Loading houses...</p>}
      {error && <p className="error">{error}</p>}

      <div className="grid">
        {houses.map((house) => (
          <HouseCard key={house.house_id} house={house} />
        ))}
      </div>

      <section className="panel">
        <h2>Create New House</h2>
        <p className="muted">When you create a house, you become its admin.</p>

        {formError && <p className="error">{formError}</p>}

        <form className="formGrid" onSubmit={handleCreateHouse}>
          <label>
            House name
            <input value={houseName} onChange={(e) => setHouseName(e.target.value)} required />
          </label>

          <label>
            Address
            <input value={address} onChange={(e) => setAddress(e.target.value)} required />
          </label>

          <button className="button" type="submit">
            Create House
          </button>
        </form>
      </section>
    </AppShell>
  );
}