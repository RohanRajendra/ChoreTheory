'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const links = [
  { href: '/houses', label: 'Houses' },
  { href: '/bookings', label: 'Bookings' },
  { href: '/profile', label: 'Profile' },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="sidebar">
      <div>
        <h2 className="appTitle">HouseMate</h2>
        <p className="muted">Shared home booking and expense app</p>
      </div>

      <nav className="navLinks">
        {links.map((link) => {
          const active = pathname.startsWith(link.href);
          return (
            <Link key={link.href} href={link.href} className={active ? 'navLink active' : 'navLink'}>
              {link.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
