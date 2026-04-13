'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { FormEvent, useState } from 'react';
import { loginUser } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('atharva');
  const [password, setPassword] = useState('password123');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await loginUser({ username, password });
    router.push('/houses');
  }

  return (
    <div className="authPage">
      <form className="authCard" onSubmit={handleSubmit}>
        <h1>Login</h1>
        <p className="muted">Enter your username and password.</p>

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
          Login
        </button>

        <p className="muted smallText">
          New user? <Link href="/signup">Create an account</Link>
        </p>
      </form>
    </div>
  );
}
