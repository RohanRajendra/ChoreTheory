'use client';

import { FormEvent, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import ExpenseCard from '@/components/ExpenseCard';
import SectionHeader from '@/components/SectionHeader';
import { createExpense, getHouse, getUserExpenses } from '@/lib/api';
import { Expense } from '@/lib/types';

export default function HouseExpensesPage({ params }: { params: { houseId: string } }) {
  const houseId = Number(params.houseId);

  const [houseName, setHouseName] = useState('');
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [isRecurring, setIsRecurring] = useState(false);
  const [formError, setFormError] = useState('');

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
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [houseId]);

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
      // Reload expenses after creation
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

  if (loading) return <AppShell><p className="muted">Loading...</p></AppShell>;
  if (error) return <AppShell><p className="error">{error}</p></AppShell>;

  return (
    <AppShell>
      <SectionHeader
        title={`${houseName} — Expenses`}
        description="Any member can add an expense and split it among housemates."
      />

      <div className="grid">
        {expenses.map((expense) => (
          <ExpenseCard key={expense.expense_id} expense={expense} />
        ))}
      </div>

      <section className="panel">
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
            <input value={description} onChange={(e) => setDescription(e.target.value)} required />
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
      </section>
    </AppShell>
  );
}