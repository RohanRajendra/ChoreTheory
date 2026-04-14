'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { FormEvent, useState } from 'react';
import { loginUser } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    try {
      const result = await loginUser({ email, password });
      localStorage.setItem('userEmail', result.email);
      localStorage.setItem('userName', result.name);
      router.push('/houses');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <div className="authPage">
      <form className="authCard" onSubmit={handleSubmit}>
        <h1>Login</h1>
        <p className="muted">Enter your email and password.</p>

        {error && <p className="error">{error}</p>}

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
          Login
        </button>

        <p className="muted smallText">
          New user? <Link href="/signup">Create an account</Link>
        </p>
      </form>
    </div>
  );
}