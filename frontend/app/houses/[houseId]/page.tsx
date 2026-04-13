'use client';

import Link from 'next/link';
import { FormEvent, useMemo, useState } from 'react';
import AppShell from '@/components/AppShell';
import ResourceCard from '@/components/ResourceCard';
import SectionHeader from '@/components/SectionHeader';
import { addMemberToHouse, addResource } from '@/lib/api';
import { houses, resources } from '@/lib/mock-data';

export default function HouseDetailsPage({ params }: { params: { houseId: string } }) {
  const [resourceName, setResourceName] = useState('');
  const [resourceIcon, setResourceIcon] = useState('🏠');
  const [timeLimit, setTimeLimit] = useState('1 hour');
  const [resourceType, setResourceType] = useState<'space' | 'appliance'>('space');
  const [newMember, setNewMember] = useState('');

  const house = useMemo(() => houses.find((item) => item.id === params.houseId), [params.houseId]);
  const houseResources = resources.filter((resource) => resource.houseId === params.houseId);

  if (!house) {
    return <AppShell><p>House not found.</p></AppShell>;
  }

  async function handleAddResource(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addResource({
      houseId: house.id,
      name: resourceName,
      icon: resourceIcon,
      timeLimit,
      type: resourceType,
    });
    alert('Resource submitted. Replace alert with real refresh after backend is ready.');
  }

  async function handleAddMember(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await addMemberToHouse({ houseId: house.id, username: newMember });
    setNewMember('');
    alert('Member add request submitted.');
  }

  return (
    <AppShell>
      <SectionHeader
        title={house.name}
        description={`Address: ${house.address}`}
        action={
          <Link href={`/houses/${house.id}/expenses`} className="button secondaryButton">
            View Expenses
          </Link>
        }
      />

      <section className="panel">
        <h2>Resources</h2>
        <div className="grid">
          {houseResources.map((resource) => (
            <ResourceCard key={resource.id} resource={resource} />
          ))}
        </div>
      </section>

      {house.isCurrentUserAdmin && (
        <>
          <section className="panel">
            <h2>Add Resource</h2>
            <form className="formGrid" onSubmit={handleAddResource}>
              <label>
                Resource name
                <input value={resourceName} onChange={(e) => setResourceName(e.target.value)} required />
              </label>

              <label>
                Icon
                <input value={resourceIcon} onChange={(e) => setResourceIcon(e.target.value)} required />
              </label>

              <label>
                Time limit
                <input value={timeLimit} onChange={(e) => setTimeLimit(e.target.value)} required />
              </label>

              <label>
                Resource type
                <select
                  value={resourceType}
                  onChange={(e) => setResourceType(e.target.value as 'space' | 'appliance')}
                >
                  <option value="space">Space</option>
                  <option value="appliance">Appliance</option>
                </select>
              </label>

              <button className="button" type="submit">
                Add Resource
              </button>
            </form>
          </section>

          <section className="panel">
            <h2>Add Member by Username</h2>
            <form className="inlineForm" onSubmit={handleAddMember}>
              <input
                placeholder="Enter username"
                value={newMember}
                onChange={(e) => setNewMember(e.target.value)}
                required
              />
              <button className="button" type="submit">
                Add Member
              </button>
            </form>
          </section>
        </>
      )}
    </AppShell>
  );
}
