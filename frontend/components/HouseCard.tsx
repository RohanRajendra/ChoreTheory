import Link from 'next/link';
import { House } from '@/lib/types';

export default function HouseCard({ house }: { house: House }) {
  return (
    <div className="card">
      <div>
        <h3>{house.name}</h3>
        <p className="muted">{house.address}</p>
        <span className="badge">{house.isCurrentUserAdmin ? 'Admin' : 'Member'}</span>
      </div>
      <Link href={`/houses/${house.id}`} className="button secondaryButton">
        View House
      </Link>
    </div>
  );
}
