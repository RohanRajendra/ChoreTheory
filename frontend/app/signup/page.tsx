'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { FormEvent, useState } from 'react';
import { signupUser } from '@/lib/api';

export default function SignupPage() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    try {
      await signupUser({ email, name, password });
      localStorage.setItem('userEmail', email);
      localStorage.setItem('userName', name);
      router.push('/houses');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <div className="authPage">
      <form className="authCard" onSubmit={handleSubmit}>
        <h1>Sign Up</h1>
        <p className="muted">Create an account to join or manage houses.</p>

        {error && <p className="error">{error}</p>}

        <label>
          Full name
          <input value={name} onChange={(e) => setName(e.target.value)} required />
        </label>

        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
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