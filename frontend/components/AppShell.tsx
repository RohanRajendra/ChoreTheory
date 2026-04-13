import { ReactNode } from 'react';
import Sidebar from './Sidebar';

export default function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="shell">
      <Sidebar />
      <main className="content">{children}</main>
    </div>
  );
}
