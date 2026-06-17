"use client";

import { useEffect, useState } from "react";
import {
  Users, ClipboardList, CheckCircle, Flag,
  ShieldAlert, Clock, Zap, UserCheck, TrendingUp, Ban,
} from "lucide-react";
import Link from "next/link";
import { apiFetch } from "@/lib/api-client";
import {
  BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer, Legend,
} from "recharts";

interface Stats {
  totalUsers: number;
  bannedCount: number;
  newUsersThisWeek: number;
  icPendingCount: number;
  icVerifiedCount: number;
  totalRequests: number;
  pendingRequests: number;
  completedRequests: number;
  activeRequests: number;
  emergencyRequests: number;
  completionRate: number;
  pendingReports: number;
  byStatus: Record<string, number>;
  byCategory: Record<string, number>;
}

const STATUS_COLORS: Record<string, string> = {
  pending: "#f59e0b",
  matched: "#818cf8",
  active: "#a78bfa",
  pendingConfirmation: "#f97316",
  completed: "#34d399",
  cancelled: "#f87171",
};

const USER_VIEW_FILTERS = [
  { key: "status", label: "Account Status" },
  { key: "ic", label: "IC Verification" },
] as const;

type UserView = "status" | "ic";

const card = { background: "var(--bg-card)", border: "1px solid var(--border)" };
const tooltipStyle = { background: "#1a1a28", border: "1px solid #2d2d45", color: "#f0eeff" };

function StatCard({
  label, value, icon: Icon, accent, bg, suffix = "", href,
}: {
  label: string; value: number | string; icon: React.ElementType;
  accent: string; bg: string; suffix?: string; href?: string;
}) {
  const inner = (
    <div
      className="rounded-xl p-5 flex items-center gap-4 transition-opacity"
      style={{ ...card, cursor: href ? "pointer" : "default" }}
      onMouseEnter={(e) => { if (href) (e.currentTarget as HTMLDivElement).style.opacity = "0.8"; }}
      onMouseLeave={(e) => { if (href) (e.currentTarget as HTMLDivElement).style.opacity = "1"; }}
    >
      <div className="p-3 rounded-lg shrink-0" style={{ background: bg }}>
        <Icon size={20} style={{ color: accent }} />
      </div>
      <div className="min-w-0">
        <p className="text-xs truncate" style={{ color: "var(--text-secondary)" }}>{label}</p>
        <p className="text-xl font-bold mt-0.5" style={{ color: "var(--text-primary)" }}>
          {value}{suffix}
        </p>
      </div>
    </div>
  );
  if (href) return <Link href={href} className="block">{inner}</Link>;
  return inner;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState("");
  const [userView, setUserView] = useState<UserView>("status");

  useEffect(() => {
    apiFetch("/api/stats")
      .then(setStats)
      .catch(() => setError("Failed to load stats."));
  }, []);

  const statusData = stats
    ? Object.entries(stats.byStatus).map(([name, value]) => ({ name, value }))
    : [];

  const categoryData = stats
    ? Object.entries(stats.byCategory).map(([name, value]) => ({
        name: name.charAt(0).toUpperCase() + name.slice(1), value,
      }))
    : [];

  const accountStatusData = stats
    ? [
        { name: "Active", value: Math.max(0, stats.totalUsers - stats.bannedCount), color: "#34d399" },
        { name: "Banned", value: stats.bannedCount, color: "#f87171" },
      ]
    : [];

  const icData = stats
    ? [
        { name: "Verified", value: stats.icVerifiedCount, color: "#34d399" },
        { name: "Pending", value: stats.icPendingCount, color: "#fbbf24" },
        {
          name: "Not Submitted",
          value: Math.max(0, stats.totalUsers - stats.icVerifiedCount - stats.icPendingCount),
          color: "#6b7280",
        },
      ]
    : [];

  const userChartData = userView === "status" ? accountStatusData : icData;

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold" style={{ color: "var(--text-primary)" }}>Dashboard</h2>

      {error && (
        <p className="text-sm px-4 py-3 rounded-lg" style={{ background: "#3b0a0a", color: "#fca5a5" }}>{error}</p>
      )}

      {stats === null && !error ? (
        <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
          {Array(8).fill(null).map((_, i) => (
            <div key={i} className="rounded-xl h-20 animate-pulse" style={{ background: "var(--bg-card)", border: "1px solid var(--border)" }} />
          ))}
        </div>
      ) : stats && (
        <>
          {/* Users row */}
          <div>
            <p className="text-xs font-semibold uppercase tracking-widest mb-3" style={{ color: "var(--text-secondary)" }}>Users</p>
            <div className="grid grid-cols-2 xl:grid-cols-5 gap-4">
              <StatCard label="Total Users" value={stats.totalUsers} icon={Users} accent="#818cf8" bg="#1e1b4b" href="/users" />
              <StatCard label="New This Week" value={stats.newUsersThisWeek} icon={TrendingUp} accent="#34d399" bg="#064e3b" href="/users" />
              <StatCard label="IC Pending Review" value={stats.icPendingCount} icon={UserCheck} accent="#fbbf24" bg="#451a03" href="/users?tab=ic_pending" />
              <StatCard label="Banned Users" value={stats.bannedCount} icon={Ban} accent="#f87171" bg="#450a0a" href="/users?tab=banned" />
              <StatCard label="Pending Reports" value={stats.pendingReports} icon={Flag} accent="#f87171" bg="#450a0a" href="/reports" />
            </div>
          </div>

          {/* Requests row */}
          <div>
            <p className="text-xs font-semibold uppercase tracking-widest mb-3" style={{ color: "var(--text-secondary)" }}>Requests</p>
            <div className="grid grid-cols-2 xl:grid-cols-3 gap-4">
              <StatCard label="Total Requests" value={stats.totalRequests} icon={ClipboardList} accent="#818cf8" bg="#1e1b4b" href="/requests" />
              <StatCard label="Pending" value={stats.pendingRequests} icon={Clock} accent="#f59e0b" bg="#451a03" href="/requests?status=pending" />
              <StatCard label="Active Now" value={stats.activeRequests} icon={Zap} accent="#a78bfa" bg="#2e1065" href="/requests?status=active" />
              <StatCard label="Completed" value={stats.completedRequests} icon={CheckCircle} accent="#34d399" bg="#064e3b" href="/requests?status=completed" />
              <StatCard label="Completion Rate" value={stats.completionRate} icon={TrendingUp} accent="#34d399" bg="#064e3b" suffix="%" href="/requests?status=completed" />
              <StatCard label="Emergency" value={stats.emergencyRequests} icon={ShieldAlert} accent="#f97316" bg="#431407" href="/requests?emergency=true" />
            </div>
          </div>

          {/* Charts — 2 per row */}
          <div>
            <p className="text-xs font-semibold uppercase tracking-widest mb-3" style={{ color: "var(--text-secondary)" }}>Charts</p>
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">

              {/* Requests by Status */}
              <div className="rounded-xl p-5" style={card}>
                <h3 className="text-sm font-semibold mb-4" style={{ color: "var(--text-secondary)" }}>Requests by Status</h3>
                <ResponsiveContainer width="100%" height={240}>
                  <PieChart>
                    <Pie
                      data={statusData}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      outerRadius={85}
                      label={({ name, percent }) => `${name} ${((percent ?? 0) * 100).toFixed(0)}%`}
                      labelLine={{ stroke: "#8b8ba8" }}
                    >
                      {statusData.map((entry) => (
                        <Cell key={entry.name} fill={STATUS_COLORS[entry.name] ?? "#6b7280"} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={tooltipStyle} />
                  </PieChart>
                </ResponsiveContainer>
              </div>

              {/* Requests by Category */}
              <div className="rounded-xl p-5" style={card}>
                <h3 className="text-sm font-semibold mb-4" style={{ color: "var(--text-secondary)" }}>Requests by Category</h3>
                <ResponsiveContainer width="100%" height={240}>
                  <BarChart data={categoryData} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
                    <XAxis dataKey="name" tick={{ fontSize: 11, fill: "#8b8ba8" }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontSize: 11, fill: "#8b8ba8" }} axisLine={false} tickLine={false} allowDecimals={false} />
                    <Tooltip contentStyle={tooltipStyle} />
                    <Bar dataKey="value" fill="#7c3aed" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>

              {/* Users — filterable, spans full row */}
              <div className="rounded-xl p-5 xl:col-span-2" style={card}>
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-sm font-semibold" style={{ color: "var(--text-secondary)" }}>Users</h3>
                  <div className="flex gap-1 p-1 rounded-lg" style={{ background: "#0d0d14", border: "1px solid var(--border)" }}>
                    {USER_VIEW_FILTERS.map(({ key, label }) => (
                      <button
                        key={key}
                        onClick={() => setUserView(key)}
                        className="px-3 py-1 rounded-md text-xs font-medium transition-colors"
                        style={userView === key
                          ? { background: "#7c3aed", color: "#fff" }
                          : { color: "var(--text-secondary)" }
                        }
                      >
                        {label}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 items-center">
                  {/* Donut chart */}
                  <ResponsiveContainer width="100%" height={260}>
                    <PieChart>
                      <Pie
                        data={userChartData}
                        dataKey="value"
                        nameKey="name"
                        cx="50%"
                        cy="50%"
                        innerRadius={65}
                        outerRadius={100}
                      >
                        {userChartData.map((entry) => (
                          <Cell key={entry.name} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip contentStyle={tooltipStyle} />
                      <Legend formatter={(value) => <span style={{ color: "#8b8ba8", fontSize: 12 }}>{value}</span>} />
                    </PieChart>
                  </ResponsiveContainer>

                  {/* Breakdown table */}
                  <div className="space-y-3">
                    {userChartData.map((entry) => {
                      const pct = stats.totalUsers > 0
                        ? Math.round((entry.value / stats.totalUsers) * 100)
                        : 0;
                      return (
                        <div key={entry.name}>
                          <div className="flex justify-between text-sm mb-1">
                            <span style={{ color: "var(--text-primary)" }}>{entry.name}</span>
                            <span style={{ color: "var(--text-secondary)" }}>
                              {entry.value} <span className="text-xs">({pct}%)</span>
                            </span>
                          </div>
                          <div className="h-2 rounded-full overflow-hidden" style={{ background: "#1a1a28" }}>
                            <div
                              className="h-full rounded-full transition-all duration-500"
                              style={{ width: `${pct}%`, background: entry.color }}
                            />
                          </div>
                        </div>
                      );
                    })}
                    <p className="text-xs pt-1" style={{ color: "var(--text-secondary)" }}>
                      Total users: <span style={{ color: "var(--text-primary)" }}>{stats.totalUsers}</span>
                    </p>
                  </div>
                </div>
              </div>

            </div>
          </div>
        </>
      )}
    </div>
  );
}
