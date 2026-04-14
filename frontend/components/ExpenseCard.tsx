import { Expense } from '@/lib/types';

export default function ExpenseCard({ expense }: { expense: Expense }) {
  return (
    <div className="card">
      <div>
        <h3>{expense.description}</h3>
        <p>Total: ${expense.amount}</p>
        <p>Due date: {expense.due_date}</p>
        <p>Added by: {expense.created_by}</p>
        {/* user_share is returned directly from the backend per user */}
        <p className="muted">Your share: ${expense.user_share.toFixed(2)}</p>
        <p className="muted">Status: {expense.payment_status}</p>
      </div>
    </div>
  );
}