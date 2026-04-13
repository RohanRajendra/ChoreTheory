import Link from 'next/link';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import { currentUser, houses } from '@/lib/mock-data';

export default function ProfilePage() {
  return (
    <AppShell>
      <SectionHeader title="Profile" description="Basic user information and logout action." />

      <section className="panel">
        <p><strong>Name:</strong> {currentUser.name}</p>
        <p><strong>Username:</strong> {currentUser.username}</p>
        <p><strong>Total houses:</strong> {houses.length}</p>
        <p><strong>Admin status:</strong> {currentUser.isAdmin ? 'Yes' : 'No'}</p>

        <Link href="/login" className="button logoutButton">
          Logout
        </Link>
      </section>
    </AppShell>
  );
}
