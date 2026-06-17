"use client";

import { useEffect, useState } from "react";
import { apiFetch } from "@/lib/api-client";
import { auth } from "@/lib/firebase";
import type { AppUser } from "@/lib/types";
import { Search, X, Trash2, ShieldOff, ShieldCheck, CheckCircle, XCircle, AlertTriangle } from "lucide-react";
import Image from "next/image";
import DateFilter from "@/components/DateFilter";

const ROLE_COLORS: Record<string, { bg: string; color: string }> = {
  donor: { bg: "#1e1b4b", color: "#a5b4fc" },
  beneficiary: { bg: "#2e1065", color: "#c4b5fd" },
};

function isBanned(user: AppUser) {
  return user.banUntil != null && new Date(user.banUntil as unknown as string) > new Date();
}

const inputStyle = {
  background: "#1a1a28",
  border: "1px solid var(--border)",
  color: "var(--text-primary)",
};
const card = { background: "var(--bg-card)", border: "1px solid var(--border)" };

type Tab = "all" | "ic_pending" | "banned" | "deleted";

const TABS: { key: Tab; label: string }[] = [
  { key: "all", label: "All" },
  { key: "ic_pending", label: "IC Pending" },
  { key: "banned", label: "Banned" },
  { key: "deleted", label: "Deleted" },
];

export default function UsersPage() {
  const [users, setUsers] = useState<AppUser[]>([]);
  const [filtered, setFiltered] = useState<AppUser[]>([]);
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState<Tab>("all");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Read initial tab from URL param (?tab=ic_pending etc.)
  useEffect(() => {
    const param = new URLSearchParams(window.location.search).get("tab") as Tab | null;
    if (param && TABS.some((t) => t.key === param)) setTab(param);
  }, []);

  // IC verification modal
  const [icUser, setIcUser] = useState<AppUser | null>(null);
  const [icPhotoUrl, setIcPhotoUrl] = useState<string | null>(null);
  const [icLoading, setIcLoading] = useState(false);
  const [icError, setIcError] = useState<string>("");

  function loadUsers() {
    setLoading(true);
    apiFetch("/api/users")
      .then((data) => { setUsers(data); setLoading(false); })
      .catch(() => { setError("Failed to load users."); setLoading(false); });
  }

  useEffect(() => { loadUsers(); }, []);

  useEffect(() => {
    let result = users;
    if (tab === "ic_pending") result = result.filter((u) => u.icPendingVerification);
    else if (tab === "banned") result = result.filter((u) => !u.authDeleted && isBanned(u));
    else if (tab === "deleted") result = result.filter((u) => u.authDeleted);
    if (search.trim()) {
      const q = search.toLowerCase();
      result = result.filter((u) => u.fullName.toLowerCase().includes(q) || u.email.toLowerCase().includes(q));
    }
    if (dateFrom) result = result.filter((u) => u.createdAt && new Date(u.createdAt as unknown as string) >= new Date(dateFrom));
    if (dateTo) {
      const end = new Date(dateTo); end.setDate(end.getDate() + 1);
      result = result.filter((u) => u.createdAt && new Date(u.createdAt as unknown as string) < end);
    }
    setFiltered(result);
  }, [search, tab, dateFrom, dateTo, users]);

  async function openICModal(user: AppUser) {
    if (icPhotoUrl) URL.revokeObjectURL(icPhotoUrl);
    setIcUser(user);
    setIcPhotoUrl(null);
    setIcError("");
    setIcLoading(true);
    try {
      const token = await auth.currentUser?.getIdToken();
      const res = await fetch(`/api/users/ic-photo?uid=${user.uid}`, {
        headers: { Authorization: `Bearer ${token ?? ""}` },
      });
      if (!res.ok) {
        setIcError(res.status === 404 ? "No IC photo submitted by this user." : "Server error loading photo.");
        return;
      }
      const blob = await res.blob();
      setIcPhotoUrl(URL.createObjectURL(blob));
    } catch {
      setIcError("Failed to load IC photo.");
    } finally {
      setIcLoading(false);
    }
  }

  function closeICModal() {
    if (icPhotoUrl) URL.revokeObjectURL(icPhotoUrl);
    setIcUser(null);
    setIcPhotoUrl(null);
    setIcError("");
  }

  async function doAction(uid: string, action: string, banHours?: number) {
    if (action === "delete" && !confirm("Delete this user permanently? This cannot be undone.")) return;
    try {
      if (action === "delete") {
        await apiFetch("/api/users", { method: "DELETE", body: JSON.stringify({ uid }) });
      } else {
        await apiFetch("/api/users", { method: "PATCH", body: JSON.stringify({ uid, action, banHours }) });
      }
      closeICModal();
      loadUsers();
    } catch {
      alert("Action failed. Please try again.");
    }
  }

  const icPendingCount = users.filter((u) => u.icPendingVerification).length;
  const deletedCount = users.filter((u) => u.authDeleted).length;

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6" style={{ color: "var(--text-primary)" }}>Users</h2>

      {/* Tabs */}
      <div className="flex gap-1 mb-4 p-1 rounded-lg w-fit" style={{ background: "var(--bg-card)", border: "1px solid var(--border)" }}>
        {TABS.map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className="px-3 py-1.5 rounded-md text-sm font-medium transition-colors relative"
            style={tab === key
              ? { background: "#7c3aed", color: "#fff" }
              : { color: "var(--text-secondary)" }
            }
          >
            {label}
            {key === "ic_pending" && icPendingCount > 0 && (
              <span className="ml-1.5 text-xs px-1.5 py-0.5 rounded-full" style={{ background: "#451a03", color: "#fcd34d" }}>
                {icPendingCount}
              </span>
            )}
            {key === "deleted" && deletedCount > 0 && (
              <span className="ml-1.5 text-xs px-1.5 py-0.5 rounded-full" style={{ background: "#3b0a0a", color: "#fca5a5" }}>
                {deletedCount}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Search + date filters */}
      <div className="space-y-3 mb-4">
        <div className="relative">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--text-secondary)" }} />
          <input
            type="text"
            placeholder="Search by name or email…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-3 py-2 rounded-lg text-sm outline-none"
            style={inputStyle}
          />
        </div>
        <DateFilter
          dateFrom={dateFrom}
          dateTo={dateTo}
          onDateFromChange={setDateFrom}
          onDateToChange={setDateTo}
        />
        {(dateFrom || dateTo || search) && (
          <button onClick={() => { setDateFrom(""); setDateTo(""); setSearch(""); }}
            className="px-3 py-1.5 rounded-lg text-xs" style={{ background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-secondary)" }}>
            Clear all ×
          </button>
        )}
      </div>

      {error && <p className="text-sm px-4 py-3 rounded-lg mb-4" style={{ background: "#3b0a0a", color: "#fca5a5" }}>{error}</p>}

      <div className="rounded-xl overflow-hidden" style={card}>
        {loading ? (
          <div className="flex items-center justify-center py-16 text-sm" style={{ color: "var(--text-secondary)" }}>Loading users…</div>
        ) : filtered.length === 0 ? (
          <div className="flex items-center justify-center py-16 text-sm" style={{ color: "var(--text-secondary)" }}>No users found.</div>
        ) : (
          <table className="w-full text-sm">
            <thead style={{ background: "#0d0d14", borderBottom: "1px solid var(--border)" }}>
              <tr>
                {["Name", "Email", "Role", "IC Status", "Account Status", "Strikes", "Joined", "Actions"].map((h) => (
                  <th key={h} className="text-left px-4 py-3 font-medium" style={{ color: "var(--text-secondary)" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((user, i) => (
                <tr key={user.uid} style={{
                  borderTop: i === 0 ? "none" : "1px solid var(--border)",
                  opacity: user.authDeleted ? 0.55 : 1,
                }}>
                  <td className="px-4 py-3 font-medium" style={{ color: "var(--text-primary)" }}>{user.fullName}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1.5">
                      <span style={{ color: "var(--text-secondary)" }}>{user.email}</span>
                      {user.duplicateEmail && (
                        <span title="Another account uses this email">
                          <AlertTriangle size={13} style={{ color: "#f59e0b" }} />
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={ROLE_COLORS[user.role]}>{user.role}</span>
                  </td>
                  <td className="px-4 py-3">
                    {user.icPendingVerification && !user.authDeleted ? (
                      <button
                        onClick={() => openICModal(user)}
                        className="px-2 py-0.5 rounded-full text-xs font-medium cursor-pointer transition-opacity hover:opacity-80"
                        style={{ background: "#451a03", color: "#fcd34d" }}
                      >
                        Pending — Review
                      </button>
                    ) : user.isICVerified ? (
                      <span className="text-xs font-medium" style={{ color: "#34d399" }}>Verified</span>
                    ) : (
                      <span className="text-xs" style={{ color: "var(--text-secondary)" }}>Not submitted</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {user.authDeleted ? (
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#1c1c1c", color: "#6b7280" }}>Deleted</span>
                    ) : isBanned(user) ? (
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#450a0a", color: "#f87171" }}>Banned</span>
                    ) : (
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#064e3b", color: "#34d399" }}>Active</span>
                    )}
                  </td>
                  <td className="px-4 py-3" style={{ color: "var(--text-secondary)" }}>{user.cancellationStrikes}</td>
                  <td className="px-4 py-3" style={{ color: "var(--text-secondary)" }}>
                    {user.createdAt ? new Date(user.createdAt as unknown as string).toLocaleDateString() : "—"}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      {!user.authDeleted && (isBanned(user) ? (
                        <button title="Unban" onClick={() => doAction(user.uid, "unban")}
                          className="p-1.5 rounded-lg transition-colors hover:opacity-80"
                          style={{ background: "#064e3b", color: "#34d399" }}>
                          <ShieldCheck size={14} />
                        </button>
                      ) : (
                        <button title="Ban 24h" onClick={() => doAction(user.uid, "ban", 24)}
                          className="p-1.5 rounded-lg transition-colors hover:opacity-80"
                          style={{ background: "#451a03", color: "#fcd34d" }}>
                          <ShieldOff size={14} />
                        </button>
                      ))}
                      <button title={user.authDeleted ? "Remove record" : "Delete user"} onClick={() => doAction(user.uid, "delete")}
                        className="p-1.5 rounded-lg transition-colors hover:opacity-80"
                        style={{ background: "#450a0a", color: "#f87171" }}>
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <p className="text-xs mt-2" style={{ color: "var(--text-secondary)" }}>{filtered.length} user(s) shown</p>

      {/* IC Verification Modal */}
      {icUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: "rgba(0,0,0,0.7)" }} onClick={closeICModal}>
          <div className="w-full max-w-md rounded-2xl p-6 space-y-4" style={{ background: "var(--bg-card)", border: "1px solid var(--border)" }} onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>IC Verification Review</h3>
              <button onClick={closeICModal} style={{ color: "var(--text-secondary)" }}><X size={20} /></button>
            </div>

            <div className="space-y-1 text-sm">
              <p style={{ color: "var(--text-primary)" }}><span style={{ color: "var(--text-secondary)" }}>Name: </span>{icUser.fullName}</p>
              <p style={{ color: "var(--text-primary)" }}><span style={{ color: "var(--text-secondary)" }}>Email: </span>{icUser.email}</p>
              {icUser.icNumber && (
                <p style={{ color: "var(--text-primary)" }}><span style={{ color: "var(--text-secondary)" }}>IC Number: </span>{icUser.icNumber}</p>
              )}
              {icUser.phoneNumber && (
                <p style={{ color: "var(--text-primary)" }}><span style={{ color: "var(--text-secondary)" }}>Phone: </span>{icUser.phoneNumber}</p>
              )}
            </div>

            <div className="rounded-lg overflow-hidden" style={{ background: "#0d0d14", border: "1px solid var(--border)", minHeight: 180 }}>
              {icLoading ? (
                <div className="flex items-center justify-center h-44 text-sm" style={{ color: "var(--text-secondary)" }}>Loading IC photo…</div>
              ) : icPhotoUrl ? (
                <Image src={icPhotoUrl} alt="IC Photo" width={400} height={240} className="w-full object-contain max-h-56" unoptimized />
              ) : (
                <div className="flex flex-col items-center justify-center h-44 gap-1 text-sm">
                  <span style={{ color: "var(--text-secondary)" }}>{icError || "No IC photo found"}</span>
                </div>
              )}
            </div>

            <div className="flex gap-3 pt-1">
              <button
                onClick={() => doAction(icUser.uid, "verifyIC")}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium transition-opacity hover:opacity-80"
                style={{ background: "#064e3b", color: "#34d399" }}
              >
                <CheckCircle size={16} /> Approve
              </button>
              <button
                onClick={() => doAction(icUser.uid, "rejectIC")}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium transition-opacity hover:opacity-80"
                style={{ background: "#450a0a", color: "#f87171" }}
              >
                <XCircle size={16} /> Reject
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
