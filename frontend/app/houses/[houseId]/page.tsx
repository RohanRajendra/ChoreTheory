'use client';

import Link from 'next/link';
import { FormEvent, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import ResourceCard from '@/components/ResourceCard';
import SectionHeader from '@/components/SectionHeader';
import { addMemberToHouse, addResource, getHouse, getHouseResources } from '@/lib/api';
import { House, Resource } from '@/lib/types';

export default function HouseDetailsPage({ params }: { params: { houseId: string } }) {
  const houseId = Number(params.houseId);

  const [house, setHouse] = useState<House | null>(null);
  const [resources, setResources] = useState<Resource[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Resource form state
  const [resourceName, setResourceName] = useState('');
  const [resourceIcon, setResourceIcon] = useState('🏠');
  const [timeLimit, setTimeLimit] = useState(60);
  const [resourceType, setResourceType] = useState<'space' | 'appliance'>('space');
  const [cleanAfterUse, setCleanAfterUse] = useState(false);
  const [maxOccupancy, setMaxOccupancy] = useState(1);
  const [requiresMaintenance, setRequiresMaintenance] = useState(false);
  const [resourceError, setResourceError] = useState('');

  // Member form state
  const [newMember, setNewMember] = useState('');
  const [memberError, setMemberError] = useState('');

  useEffect(() => {
    async function load() {
      try {
        const [houseData, resourceData] = await Promise.all([
          getHouse(houseId),
          getHouseResources(houseId),
        ]);
        // Attach is_admin from localStorage-cached house list or default false
        const email = localStorage.getItem('userEmail');
        const storedHouses = JSON.parse(localStorage.getItem('userHouses') ?? '[]');
        const match = storedHouses.find((h: { house_id: number }) => h.house_id === houseId);
        setHouse({ ...houseData, is_admin: match?.is_admin ?? false });
        setResources(resourceData);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [houseId]);

  async function handleAddResource(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setResourceError('');
    try {
      const result = await addResource({
        name: resourceName,
        time_limit: timeLimit,
        icon: resourceIcon,
        house_id: houseId,
        subclass: resourceType,
        clean_after_use: resourceType === 'space' ? cleanAfterUse : undefined,
        max_occupancy: resourceType === 'space' ? maxOccupancy : undefined,
        requires_maintenance: resourceType === 'appliance' ? requiresMaintenance : undefined,
      });
      // Optimistically add the new resource to the list
      setResources((prev) => [
        ...prev,
        {
          resource_id: result.resource_id,
          house_id: houseId,
          name: resourceName,
          icon: resourceIcon,
          time_limit: timeLimit,
          resource_type: resourceType,
          clean_after_use: resourceType === 'space' ? cleanAfterUse : null,
          max_occupancy: resourceType === 'space' ? maxOccupancy : null,
          requires_maintenance: resourceType === 'appliance' ? requiresMaintenance : null,
        },
      ]);
      setResourceName('');
      setResourceIcon('🏠');
      setTimeLimit(60);
    } catch (e) {
      setResourceError((e as Error).message);
    }
  }

  async function handleAddMember(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMemberError('');
    try {
      const adminEmail = localStorage.getItem('userEmail');
      if (!adminEmail) throw new Error('Not logged in.');
      await addMemberToHouse({
        houseId,
        admin_email: adminEmail,
        new_user_email: newMember,
      });
      setNewMember('');
      alert(`${newMember} added successfully.`);
    } catch (e) {
      setMemberError((e as Error).message);
    }
  }

  if (loading) return <AppShell><p className="muted">Loading...</p></AppShell>;
  if (error) return <AppShell><p className="error">{error}</p></AppShell>;
  if (!house) return <AppShell><p>House not found.</p></AppShell>;

  return (
    <AppShell>
      <SectionHeader
        title={house.name}
        description={`Address: ${house.address}`}
        action={
          <Link href={`/houses/${houseId}/expenses`} className="button secondaryButton">
            View Expenses
          </Link>
        }
      />

      <section className="panel">
        <h2>Resources</h2>
        <div className="grid">
          {resources.map((resource) => (
            <ResourceCard key={resource.resource_id} resource={resource} />
          ))}
        </div>
      </section>

      {house.is_admin && (
        <>
          <section className="panel">
            <h2>Add Resource</h2>
            {resourceError && <p className="error">{resourceError}</p>}
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
                Time limit (minutes)
                <input
                  type="number"
                  min={1}
                  value={timeLimit}
                  onChange={(e) => setTimeLimit(Number(e.target.value))}
                  required
                />
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

              {resourceType === 'space' && (
                <>
                  <label>
                    Max occupancy
                    <input
                      type="number"
                      min={1}
                      value={maxOccupancy}
                      onChange={(e) => setMaxOccupancy(Number(e.target.value))}
                      required
                    />
                  </label>
                  <label className="checkboxLabel">
                    <input
                      type="checkbox"
                      checked={cleanAfterUse}
                      onChange={(e) => setCleanAfterUse(e.target.checked)}
                    />
                    Requires cleaning after use
                  </label>
                </>
              )}

              {resourceType === 'appliance' && (
                <label className="checkboxLabel">
                  <input
                    type="checkbox"
                    checked={requiresMaintenance}
                    onChange={(e) => setRequiresMaintenance(e.target.checked)}
                  />
                  Requires maintenance after use
                </label>
              )}

              <button className="button" type="submit">
                Add Resource
              </button>
            </form>
          </section>

          <section className="panel">
            <h2>Add Member by Email</h2>
            {memberError && <p className="error">{memberError}</p>}
            <form className="inlineForm" onSubmit={handleAddMember}>
              <input
                type="email"
                placeholder="Enter member email"
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