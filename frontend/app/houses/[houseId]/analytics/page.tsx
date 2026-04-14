'use client';

import { use, useEffect, useState } from 'react';
import AppShell from '@/components/AppShell';
import SectionHeader from '@/components/SectionHeader';
import {
  getExpenseTrend,
  getTopSpenders,
  getBookingFrequency,
  getSettlementBreakdown,
  getResourceUtilization,
  getExpenseForecast,
  getResourceRecommendations,
} from '@/lib/api';
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';

const COLORS = ['#6366f1', '#22d3ee', '#f59e0b', '#10b981', '#ef4444', '#a855f7'];
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default function AnalyticsDashboard({
  params,
}: {
  params: Promise<{ houseId: string }>;
}) {
  const { houseId: houseIdStr } = use(params);
  const houseId = Number(houseIdStr);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [trendData, setTrendData] = useState<Array<{ label: string; total: number; predicted?: number }>>([]);
  const [spenders, setSpenders] = useState<Array<{ name: string; total_spent: number }>>([]);
  const [bookingFreq, setBookingFreq] = useState<Array<{ resource_name: string; booking_count: number; resource_type: string }>>([]);
  const [settlement, setSettlement] = useState<Array<{ payment_status: string; cnt: number }>>([]);
  const [utilization, setUtilization] = useState<Array<{ resource_type: string; total_minutes_booked: number; booking_count: number }>>([]);
  const [recommendations, setRecommendations] = useState<Array<{ resource_name: string; resource_type: string; score: number }>>([]);
  const [forecastMessage, setForecastMessage] = useState('');
  const [recoMessage, setRecoMessage] = useState('');

  useEffect(() => {
    async function load() {
      const email = localStorage.getItem('userEmail') ?? '';
      try {
        const [trend, topSpend, freq, settle, util, forecast, reco] = await Promise.all([
          getExpenseTrend(houseId),
          getTopSpenders(houseId),
          getBookingFrequency(houseId),
          getSettlementBreakdown(houseId),
          getResourceUtilization(houseId),
          getExpenseForecast(houseId),
          getResourceRecommendations(houseId, email),
        ]);

        // Merge historical + forecast into one series for the trend chart
        const historicalMap = new Map(
          (forecast.historical ?? []).map((p) => [`${p.yr}-${p.mo}`, p.total])
        );
        const trendLabels = trend.map((p) => ({
          label: `${MONTH_NAMES[p.mo - 1]} ${p.yr}`,
          total: Number(p.total_amount),
          predicted: undefined as number | undefined,
        }));
        const forecastPoints = (forecast.forecast ?? []).map((p) => ({
          label: `${MONTH_NAMES[p.mo - 1]} ${p.yr}`,
          total: undefined as number | undefined,
          predicted: p.predicted_amount,
        }));
        setTrendData([...trendLabels, ...forecastPoints] as typeof trendData);
        if (forecast.message) setForecastMessage(forecast.message);

        setSpenders(topSpend.map((s) => ({ name: s.name, total_spent: Number(s.total_spent) })));
        setBookingFreq(freq.map((f) => ({ resource_name: f.resource_name, booking_count: f.booking_count, resource_type: f.resource_type })));
        setSettlement(settle);
        setUtilization(util.map((u) => ({ ...u, total_minutes_booked: Number(u.total_minutes_booked) })));

        setRecommendations(reco.recommendations ?? []);
        if (reco.message) setRecoMessage(reco.message);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [houseId]);

  if (loading) return <AppShell><p className="muted">Loading analytics...</p></AppShell>;
  if (error) return <AppShell><p className="error">{error}</p></AppShell>;

  return (
    <AppShell>
      <SectionHeader
        title="Analytics"
        description="Expense trends, spending patterns, resource usage, and ML insights."
      />

      {/* 1. Expense Trend + Forecast */}
      <section className="panel">
        <h2>Expense Trend &amp; Forecast</h2>
        {forecastMessage && <p className="muted" style={{ fontSize: '0.85rem' }}>{forecastMessage}</p>}
        {trendData.length === 0 ? (
          <p className="muted">No expense data yet.</p>
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={trendData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="label" tick={{ fontSize: 12 }} />
              <YAxis tickFormatter={(v) => `$${v}`} />
              <Tooltip formatter={(v: number) => `$${v?.toFixed(2)}`} />
              <Legend />
              <Line type="monotone" dataKey="total" name="Actual ($)" stroke="#6366f1" strokeWidth={2} dot connectNulls />
              <Line type="monotone" dataKey="predicted" name="Forecast ($)" stroke="#f59e0b" strokeWidth={2} strokeDasharray="6 3" dot connectNulls />
            </LineChart>
          </ResponsiveContainer>
        )}
      </section>

      {/* 2. Top Spenders */}
      <section className="panel">
        <h2>Top Spenders</h2>
        {spenders.length === 0 ? (
          <p className="muted">No expense data yet.</p>
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={spenders} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis type="number" tickFormatter={(v) => `$${v}`} />
              <YAxis type="category" dataKey="name" width={90} tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v: number) => `$${v.toFixed(2)}`} />
              <Bar dataKey="total_spent" name="Total Spent ($)" fill="#6366f1" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </section>

      {/* 3. Booking Frequency */}
      <section className="panel">
        <h2>Booking Frequency by Resource</h2>
        {bookingFreq.length === 0 ? (
          <p className="muted">No bookings yet.</p>
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={bookingFreq}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="resource_name" tick={{ fontSize: 12 }} />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="booking_count" name="Bookings" fill="#22d3ee" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </section>

      {/* 4. Settlement Breakdown (pie) */}
      <section className="panel">
        <h2>Expense Settlement Status</h2>
        {settlement.length === 0 ? (
          <p className="muted">No expense data yet.</p>
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie
                data={settlement}
                dataKey="cnt"
                nameKey="payment_status"
                cx="50%"
                cy="50%"
                outerRadius={90}
                label={({ payment_status, percent }) =>
                  `${payment_status} ${(percent * 100).toFixed(0)}%`
                }
              >
                {settlement.map((_, i) => (
                  <Cell key={i} fill={COLORS[i % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        )}
      </section>

      {/* 5. Resource Utilization */}
      <section className="panel">
        <h2>Resource Utilization by Type</h2>
        {utilization.length === 0 ? (
          <p className="muted">No booking data yet.</p>
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={utilization}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="resource_type" />
              <YAxis yAxisId="left" orientation="left" tickFormatter={(v) => `${v}m`} />
              <YAxis yAxisId="right" orientation="right" allowDecimals={false} />
              <Tooltip />
              <Legend />
              <Bar yAxisId="left" dataKey="total_minutes_booked" name="Total Minutes" fill="#10b981" radius={[4, 4, 0, 0]} />
              <Bar yAxisId="right" dataKey="booking_count" name="# Bookings" fill="#a855f7" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </section>

      {/* 6. KNN Resource Recommendations */}
      <section className="panel">
        <h2>Resource Recommendations (KNN)</h2>
        <p className="muted" style={{ fontSize: '0.85rem' }}>
          Based on what similar housemates have booked.
        </p>
        {recoMessage && <p className="muted" style={{ fontSize: '0.85rem' }}>{recoMessage}</p>}
        {recommendations.length === 0 && !recoMessage && (
          <p className="muted">No recommendations available.</p>
        )}
        {recommendations.map((r, i) => (
          <div key={r.resource_id} className="card" style={{ marginBottom: '0.5rem' }}>
            <div>
              <p><strong>#{i + 1} {r.resource_name}</strong></p>
              <p className="muted">{r.resource_type} · affinity score: {r.score}</p>
            </div>
          </div>
        ))}
      </section>
    </AppShell>
  );
}
