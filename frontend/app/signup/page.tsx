'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { FormEvent, useState } from 'react';
import { signupUser } from '@/lib/api';

export default function SignupPage() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await signupUser({ name, username, password });
    router.push('/houses');
  }

  return (
    <div className="authPage">
      <form className="authCard" onSubmit={handleSubmit}>
        <h1>Sign Up</h1>
        <p className="muted">Create an account to join or manage houses.</p>

        <label>
          Full name
          <input value={name} onChange={(e) => setName(e.target.value)} required />
        </label>

        <label>
          Username
          <input value={username} onChange={(e) => setUsername(e.target.value)} required />
        </label>

        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>

        <button className="button" type="submit">
          Create account
        </button>

        <p className="muted smallText">
          Already have an account? <Link href="/login">Login</Link>
        </p>
      </form>
    </div>
  );
}
