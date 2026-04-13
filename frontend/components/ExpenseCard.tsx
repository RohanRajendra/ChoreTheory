import { Expense } from '@/lib/types';

export default function ExpenseCard({ expense }: { expense: Expense }) {
  const userShare = (expense.amount / expense.splitCount).toFixed(2);

  return (
    <div className="card">
      <div>
        <h3>{expense.description}</h3>
        <p>Total: ${expense.amount}</p>
        <p>Due date: {expense.dueDate}</p>
        <p>Added by: {expense.createdBy}</p>
        <p className="muted">Equal split: ${userShare} per user</p>
      </div>
    </div>
  );
}
