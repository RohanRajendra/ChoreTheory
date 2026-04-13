'use client';

import { FormEvent, useState } from 'react';
import AppShell from '@/components/AppShell';
import HouseCard from '@/components/HouseCard';
import SectionHeader from '@/components/SectionHeader';
import { createHouse } from '@/lib/api';
import { houses } from '@/lib/mock-data';

export default function HouseListPage() {
  const [houseName, setHouseName] = useState('');
  const [address, setAddress] = useState('');

  async function handleCreateHouse(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await createHouse({ name: houseName, address });
    setHouseName('');
    setAddress('');
    alert('House submitted. Connect this to FastAPI and refresh with real data.');
  }

  return (
    <AppShell>
      <SectionHeader
        title="Your Houses"
        description="This is the HouseListView. After login, show every house connected to the user."
      />

      <div className="grid">
        {houses.map((house) => (
          <HouseCard key={house.id} house={house} />
        ))}
      </div>

      <section className="panel">
        <h2>Create New House</h2>
        <p className="muted">When a user creates a house, they become its admin.</p>

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
