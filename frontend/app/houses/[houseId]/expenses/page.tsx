'use client';

import { FormEvent, use, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import {
  createExpense,
  deleteExpense,
  getExpenseParticipants,
  getHouse,
  getUserExpenses,
  settlePayment,
  splitExpense,
} from '@/lib/api';
import { Expense, ExpenseParticipant } from '@/lib/types';

export default function HouseExpensesPage({
  params,
}: {
  params: Promise<{ houseId: string }>;
}) {
  const { houseId: houseIdStr } = use(params);
  const houseId = Number(houseIdStr);

  const [houseName, setHouseName] = useState('');
  const [userRole, setUserRole] = useState<'admin' | 'member' | 'guest'>('member');
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [participants, setParticipants] = useState<
    Record<number, ExpenseParticipant[]>
  >({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Create expense form
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [isRecurring, setIsRecurring] = useState(false);
  const [formError, setFormError] = useState('');

  // Split form — one active expense at a time
  const [splitExpenseId, setSplitExpenseId] = useState<number | null>(null);
  const [splitEmail, setSplitEmail] = useState('');
  const [splitShare, setSplitShare] = useState('');
  const [splitError, setSplitError] = useState('');
  const [splitSuccess, setSplitSuccess] = useState('');

  const currentEmail = typeof window !== 'undefined'
    ? localStorage.getItem('userEmail') ?? ''
    : '';

  useEffect(() => {
    async function load() {
      try {
        const email = localStorage.getItem('userEmail');
        if (!email) return;
        const [houseData, expenseData] = await Promise.all([
          getHouse(houseId),
          getUserExpenses(email),
        ]);
        setHouseName(houseData.name);
        setExpenses(expenseData);
        const storedHouses = JSON.parse(localStorage.getItem('userHouses') ?? '[]');
        const match = storedHouses.find((h: { house_id: number }) => h.house_id === houseId);
        setUserRole(match?.role ?? 'member');
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [houseId]);

  async function loadParticipants(expenseId: number) {
    if (participants[expenseId]) return; // already loaded
    try {
      const result = await getExpenseParticipants(expenseId);
      setParticipants((prev) => ({ ...prev, [expenseId]: result }));
    } catch {
      // Silently fail — not critical
    }
  }

  async function handleExpenseSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError('');
    try {
      const email = localStorage.getItem('userEmail');
      if (!email) throw new Error('Not logged in.');
      await createExpense({
        amount: Number(amount),
        description,
        due_date: dueDate,
        is_recurring: isRecurring,
        created_by: email,
      });
      const updated = await getUserExpenses(email);
      setExpenses(updated);
      setAmount('');
      setDescription('');
      setDueDate('');
      setIsRecurring(false);
    } catch (e) {
      setFormError((e as Error).message);
    }
  }

  async function handleSettle(expenseId: number) {
    try {
      await settlePayment(expenseId, currentEmail);
      setExpenses((prev) =>
        prev.map((e) =>
          e.expense_id === expenseId
            ? { ...e, payment_status: 'paid' }
            : e
        )
      );
    } catch (e) {
      alert((e as Error).message);
    }
  }

  async function handleDelete(expenseId: number) {
    if (!confirm('Delete this expense? This cannot be undone.')) return;
    try {
      await deleteExpense(expenseId);
      setExpenses((prev) => prev.filter((e) => e.expense_id !== expenseId));
    } catch (e) {
      alert((e as Error).message);
    }
  }

  async function handleSplit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSplitError('');
    setSplitSuccess('');
    try {
      await splitExpense(splitExpenseId!, {
        email: splitEmail,
        user_share: Number(splitShare),
      });
      // Refresh participants for this expense
      const updated = await getExpenseParticipants(splitExpenseId!);
      setParticipants((prev) => ({ ...prev, [splitExpenseId!]: updated }));
      setSplitSuccess(`${splitEmail} added to expense.`);
      setSplitEmail('');
      setSplitShare('');
    } catch (e) {
      setSplitError((e as Error).message);
    }
  }

  if (loading) return <AppShell><p className="muted">Loading...</p></AppShell>;
  if (error) return <AppShell><p className="error">{error}</p></AppShell>;

  return (
    <AppShell>
      <SectionHeader
        title={`${houseName} — Expenses`}
        description="Any member can add an expense and split it among housemates."
      />

      {expenses.length === 0 && (
        <p className="muted">No expenses yet.</p>
      )}

      {expenses.map((expense) => (
        <div key={expense.expense_id} className="card">
          <div>
            <h3>{expense.description}</h3>
            <p>Total: ${expense.amount}</p>
            <p>Due: {expense.due_date}</p>
            <p>Added by: {expense.created_by}</p>
            <p className="muted">Your share: ${expense.user_share.toFixed(2)}</p>
            <p className="muted">Status: {expense.payment_status}</p>
            {expense.is_recurring && (
              <span className="badge">Recurring</span>
            )}
          </div>

          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginTop: '0.5rem' }}>
            {/* Settle — only if not already paid and not a guest */}
            {expense.payment_status !== 'paid' && userRole !== 'guest' && (
              <button
                className="button"
                onClick={() => handleSettle(expense.expense_id)}
              >
                Mark as Paid
              </button>
            )}

            {/* View / split participants */}
            <button
              className="button secondaryButton"
              onClick={() => {
                setSplitExpenseId(
                  splitExpenseId === expense.expense_id ? null : expense.expense_id
                );
                loadParticipants(expense.expense_id);
                setSplitError('');
                setSplitSuccess('');
              }}
            >
              {splitExpenseId === expense.expense_id ? 'Hide' : 'Split / View'}
            </button>

            {/* Delete — only creator can delete */}
            {expense.created_by === currentEmail && (
              <button
                className="button secondaryButton"
                onClick={() => handleDelete(expense.expense_id)}
              >
                Delete
              </button>
            )}
          </div>

          {/* Expanded split panel */}
          {splitExpenseId === expense.expense_id && (
            <div className="panel" style={{ marginTop: '1rem' }}>
              <h4>Participants</h4>
              {(participants[expense.expense_id] ?? []).map((p) => (
                <p key={p.email}>
                  {p.name} ({p.email}) — ${p.user_share.toFixed(2)}{' '}
                  <span className="badge">{p.payment_status}</span>
                </p>
              ))}

              <h4 style={{ marginTop: '1rem' }}>Add participant</h4>
              {splitError && <p className="error">{splitError}</p>}
              {splitSuccess && <p className="success">{splitSuccess}</p>}
              <form className="formGrid" onSubmit={handleSplit}>
                <label>
                  Email
                  <input
                    type="email"
                    value={splitEmail}
                    onChange={(e) => setSplitEmail(e.target.value)}
                    required
                  />
                </label>
                <label>
                  Share amount ($)
                  <input
                    type="number"
                    min="0.01"
                    step="0.01"
                    value={splitShare}
                    onChange={(e) => setSplitShare(e.target.value)}
                    required
                  />
                </label>
                <button className="button" type="submit">
                  Add to Split
                </button>
              </form>
            </div>
          )}
        </div>
      ))}

      {userRole === 'guest' && (
        <p className="muted" style={{ padding: '0.5rem 0' }}>
          You are a guest — you can view expenses but cannot add or modify them.
        </p>
      )}

      {userRole !== 'guest' && <section className="panel">
        <h2>Add Expense</h2>
        {formError && <p className="error">{formError}</p>}
        <form className="formGrid" onSubmit={handleExpenseSubmit}>
          <label>
            Amount
            <input
              type="number"
              min="0.01"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
          </label>

          <label>
            Description
            <input
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              required
            />
          </label>

          <label>
            Due date
            <input
              type="date"
              value={dueDate}
              onChange={(e) => setDueDate(e.target.value)}
              required
            />
          </label>

          <label className="checkboxLabel">
            <input
              type="checkbox"
              checked={isRecurring}
              onChange={(e) => setIsRecurring(e.target.checked)}
            />
            Recurring expense (e.g. rent, utilities)
          </label>

          <button className="button" type="submit">
            Add Expense
          </button>
        </form>
      </section>}
    </AppShell>
  );
}