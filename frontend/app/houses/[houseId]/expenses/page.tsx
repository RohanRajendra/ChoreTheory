'use client';

import { FormEvent, useMemo, useState } from 'react';
import AppShell from '@/components/AppShell';
import ExpenseCard from '@/components/ExpenseCard';
import SectionHeader from '@/components/SectionHeader';
import { createExpense } from '@/lib/api';
import { expenses, houses } from '@/lib/mock-data';

export default function HouseExpensesPage({ params }: { params: { houseId: string } }) {
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [dueDate, setDueDate] = useState('');

  const house = useMemo(() => houses.find((item) => item.id === params.houseId), [params.houseId]);
  const houseExpenses = expenses.filter((expense) => expense.houseId === params.houseId);

  if (!house) {
    return <AppShell><p>House not found.</p></AppShell>;
  }

  async function handleExpenseSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await createExpense({
      houseId: house.id,
      amount: Number(amount),
      description,
      dueDate,
    });
    alert('Expense submitted. Backend can split equally across house members.');
    setAmount('');
    setDescription('');
    setDueDate('');
  }

  return (
    <AppShell>
      <SectionHeader
        title={`${house.name} Expenses`}
        description="Any member can add an expense. It is split equally across members."
      />

      <div className="grid">
        {houseExpenses.map((expense) => (
          <ExpenseCard key={expense.id} expense={expense} />
        ))}
      </div>

      <section className="panel">
        <h2>Add Expense</h2>
        <form className="formGrid" onSubmit={handleExpenseSubmit}>
          <label>
            Amount
            <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} required />
          </label>

          <label>
            Description
            <input value={description} onChange={(e) => setDescription(e.target.value)} required />
          </label>

          <label>
            Due date
            <input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} required />
          </label>

          <button className="button" type="submit">
            Add Expense
          </button>
        </form>
      </section>
    </AppShell>
  );
}
