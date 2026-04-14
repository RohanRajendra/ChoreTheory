import Link from 'next/link';
import { Resource } from '@/lib/types';

export default function ResourceCard({ resource }: { resource: Resource }) {
  return (
    <div className="card">
      <div>
        <h3>
          {resource.icon} {resource.name}
        </h3>
        <p className="muted">Type: {resource.resource_type}</p>
        <p className="muted">Time limit: {resource.time_limit} min</p>
      </div>
      <Link href={`/resource/${resource.resource_id}`} className="button secondaryButton">
        Book Resource
      </Link>
    </div>
  );
}
