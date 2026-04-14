import Link from 'next/link';
import { Resource } from '@/lib/types';

interface ResourceCardProps {
  resource: Resource;
  onDelete?: (resourceId: number) => void; // only passed in when current user is admin
  canBook?: boolean;                        // false for guests
}

export default function ResourceCard({ resource, onDelete, canBook = true }: ResourceCardProps) {
  return (
    <div className="card">
      <div>
        <h3>
          {resource.icon} {resource.name}
        </h3>
        <p className="muted">Type: {resource.resource_type}</p>
        <p className="muted">Time limit: {resource.time_limit} min</p>
      </div>

      <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem' }}>
        {canBook && (
          <Link href={`/resource/${resource.resource_id}`} className="button secondaryButton">
            Book Resource
          </Link>
        )}

        {onDelete && (
          <button
            className="button secondaryButton"
            onClick={() => {
              if (confirm(`Delete resource "${resource.name}"? All its bookings will also be deleted.`)) {
                onDelete(resource.resource_id);
              }
            }}
          >
            Delete
          </button>
        )}
      </div>
    </div>
  );
}