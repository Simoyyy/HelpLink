"use client";

import { useEffect, useState } from "react";
import { apiFetch } from "@/lib/api-client";
import type { RequestStatus } from "@/lib/types";
import { Search, X, Trash2, XCircle, CheckCircle } from "lucide-react";
import DateFilter from "@/components/DateFilter";

interface RequestRow {
  id: string;
  beneficiaryId: string;
  beneficiaryName: string;
  realName: string | null;
  title: string;
  description: string;
  category: string;
  status: RequestStatus;
  isAnonymous: boolean;
  location: string | null;
  donorId: string | null;
  donorName: string | null;
  isEmergency: boolean;
  createdAt: string | null;
  matchedAt: string | null;
  completedAt: string | null;
  deliveredAt: string | null;
  cancellationReason: string | null;
  cancelledBy: string | null;
  completionMethod: string | null;
  completionPhotoUrl: string | null;
}

const STATUS_STYLES: Record<RequestStatus, { bg: string; color: string }> = {
  pending: { bg: "#451a03", color: "#fcd34d" },
  matched: { bg: "#1e1b4b", color: "#a5b4fc" },
  active: { bg: "#2e1065", color: "#c4b5fd" },
  pendingConfirmation: { bg: "#431407", color: "#fdba74" },
  completed: { bg: "#064e3b", color: "#6ee7b7" },
  cancelled: { bg: "#450a0a", color: "#fca5a5" },
};

const STATUS_LABELS: Record<RequestStatus, string> = {
  pending: "Pending", matched: "Matched", active: "Active",
  pendingConfirmation: "Pending Confirmation", completed: "Completed", cancelled: "Cancelled",
};

const ALL_STATUSES: RequestStatus[] = ["pending", "matched", "active", "pendingConfirmation", "completed", "cancelled"];

const inputStyle = { background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-primary)" };
const card = { background: "var(--bg-card)", border: "1px solid var(--border)" };

function DetailField({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs mb-0.5" style={{ color: "var(--text-secondary)" }}>{label}</p>
      <p className="text-sm" style={{ color: "var(--text-primary)" }}>{value || "—"}</p>
    </div>
  );
}

export default function RequestsPage() {
  const [requests, setRequests] = useState<RequestRow[]>([]);
  const [filtered, setFiltered] = useState<RequestRow[]>([]);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<RequestStatus | "all">("all");
  const [emergencyOnly, setEmergencyOnly] = useState(false);
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<RequestRow | null>(null);

  // Read initial filters from URL params
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const status = params.get("status") as RequestStatus | null;
    if (status && ALL_STATUSES.includes(status)) setStatusFilter(status);
    if (params.get("emergency") === "true") setEmergencyOnly(true);
  }, []);

  function loadRequests() {
    setLoading(true);
    apiFetch("/api/requests")
      .then((data) => { setRequests(data); setLoading(false); })
      .catch(() => { setError("Failed to load requests."); setLoading(false); });
  }

  useEffect(() => { loadRequests(); }, []);

  useEffect(() => {
    let result = requests;
    if (statusFilter !== "all") result = result.filter((r) => r.status === statusFilter);
    if (emergencyOnly) result = result.filter((r) => r.isEmergency);
    if (search.trim()) {
      const q = search.toLowerCase();
      result = result.filter((r) => r.title.toLowerCase().includes(q) || r.beneficiaryName.toLowerCase().includes(q));
    }
    if (dateFrom) result = result.filter((r) => r.createdAt && new Date(r.createdAt) >= new Date(dateFrom));
    if (dateTo) {
      const end = new Date(dateTo); end.setDate(end.getDate() + 1);
      result = result.filter((r) => r.createdAt && new Date(r.createdAt) < end);
    }
    setFiltered(result);
  }, [search, statusFilter, emergencyOnly, dateFrom, dateTo, requests]);

  function displayName(req: RequestRow) {
    if (!req.isAnonymous) return req.beneficiaryName;
    return `${req.realName ?? req.beneficiaryName} (Anonymous)`;
  }

  async function doAction(id: string, action: string) {
    if (action === "delete" && !confirm("Delete this request permanently? This cannot be undone.")) return;
    try {
      if (action === "delete") {
        await apiFetch("/api/requests", { method: "DELETE", body: JSON.stringify({ id }) });
      } else {
        await apiFetch("/api/requests", { method: "PATCH", body: JSON.stringify({ id, action }) });
      }
      setSelected(null);
      loadRequests();
    } catch {
      alert("Action failed. Please try again.");
    }
  }

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6" style={{ color: "var(--text-primary)" }}>Aid Requests</h2>

      <div className="space-y-3 mb-4">
        <div className="flex flex-col sm:flex-row gap-2">
          <div className="relative flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--text-secondary)" }} />
            <input type="text" placeholder="Search by title or beneficiary…" value={search}
              onChange={(e) => setSearch(e.target.value)} className="w-full pl-9 pr-3 py-2 rounded-lg text-sm outline-none" style={inputStyle} />
          </div>
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as typeof statusFilter)}
            className="px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle}>
            <option value="all">All Statuses</option>
            {ALL_STATUSES.map((s) => <option key={s} value={s}>{STATUS_LABELS[s]}</option>)}
          </select>
          <button
            onClick={() => setEmergencyOnly((v) => !v)}
            className="px-3 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap"
            style={emergencyOnly
              ? { background: "#431407", color: "#f97316", border: "1px solid #f97316" }
              : { background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-secondary)" }
            }
          >
            🚨 Emergency only
          </button>
        </div>
        <DateFilter
          dateFrom={dateFrom}
          dateTo={dateTo}
          onDateFromChange={setDateFrom}
          onDateToChange={setDateTo}
        />
        {(dateFrom || dateTo || search || statusFilter !== "all" || emergencyOnly) && (
          <button onClick={() => { setDateFrom(""); setDateTo(""); setSearch(""); setStatusFilter("all"); setEmergencyOnly(false); }}
            className="px-3 py-1.5 rounded-lg text-xs" style={{ background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-secondary)" }}>
            Clear all ×
          </button>
        )}
      </div>

      {error && <p className="text-sm px-4 py-3 rounded-lg mb-4" style={{ background: "#3b0a0a", color: "#fca5a5" }}>{error}</p>}

      <div className="rounded-xl overflow-hidden" style={card}>
        {loading ? (
          <div className="flex items-center justify-center py-16 text-sm" style={{ color: "var(--text-secondary)" }}>Loading requests…</div>
        ) : filtered.length === 0 ? (
          <div className="flex items-center justify-center py-16 text-sm" style={{ color: "var(--text-secondary)" }}>No requests found.</div>
        ) : (
          <table className="w-full text-sm">
            <thead style={{ background: "#0d0d14", borderBottom: "1px solid var(--border)" }}>
              <tr>
                {["Title", "Beneficiary", "Category", "Status", "Donor", "Emergency", "Date", "Actions"].map((h) => (
                  <th key={h} className="text-left px-4 py-3 font-medium" style={{ color: "var(--text-secondary)" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((req, i) => (
                <tr key={req.id}
                  className="cursor-pointer transition-colors"
                  onClick={() => setSelected(req)}
                  style={{ borderTop: i === 0 ? "none" : "1px solid var(--border)" }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = "#1a1a28")}
                  onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
                >
                  <td className="px-4 py-3 font-medium max-w-40 truncate" style={{ color: "var(--text-primary)" }}>{req.title}</td>
                  <td className="px-4 py-3" style={{ color: req.isAnonymous ? "#a78bfa" : "var(--text-secondary)" }}>{displayName(req)}</td>
                  <td className="px-4 py-3 capitalize" style={{ color: "var(--text-secondary)" }}>{req.category}</td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={STATUS_STYLES[req.status]}>{STATUS_LABELS[req.status]}</span>
                  </td>
                  <td className="px-4 py-3" style={{ color: "var(--text-secondary)" }}>{req.donorName ?? "—"}</td>
                  <td className="px-4 py-3">
                    {req.isEmergency ? (
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#450a0a", color: "#f87171" }}>Yes</span>
                    ) : <span style={{ color: "var(--text-secondary)" }}>—</span>}
                  </td>
                  <td className="px-4 py-3" style={{ color: "var(--text-secondary)" }}>
                    {req.createdAt ? new Date(req.createdAt).toLocaleDateString() : "—"}
                  </td>
                  <td className="px-4 py-3" onClick={(e) => e.stopPropagation()}>
                    <div className="flex items-center gap-2">
                      {!["completed", "cancelled"].includes(req.status) && (
                        <button title="Cancel request" onClick={() => doAction(req.id, "cancel")}
                          className="p-1.5 rounded-lg hover:opacity-80" style={{ background: "#451a03", color: "#fcd34d" }}>
                          <XCircle size={14} />
                        </button>
                      )}
                      <button title="Delete request" onClick={() => doAction(req.id, "delete")}
                        className="p-1.5 rounded-lg hover:opacity-80" style={{ background: "#450a0a", color: "#f87171" }}>
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
      <p className="text-xs mt-2" style={{ color: "var(--text-secondary)" }}>{filtered.length} request(s) shown</p>

      {/* Detail slide-over */}
      {selected && (
        <div className="fixed inset-0 z-50 flex justify-end" style={{ background: "rgba(0,0,0,0.6)" }} onClick={() => setSelected(null)}>
          <div className="w-full max-w-md h-full overflow-y-auto p-6 space-y-5" style={{ background: "var(--bg-card)", borderLeft: "1px solid var(--border)" }} onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold" style={{ color: "var(--text-primary)" }}>Request Details</h3>
              <button onClick={() => setSelected(null)} style={{ color: "var(--text-secondary)" }}><X size={20} /></button>
            </div>

            <div className="flex items-center gap-2">
              <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={STATUS_STYLES[selected.status]}>{STATUS_LABELS[selected.status]}</span>
              {selected.isEmergency && <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#450a0a", color: "#f87171" }}>Emergency</span>}
              {selected.isAnonymous && <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#2e1065", color: "#c4b5fd" }}>Anonymous</span>}
            </div>

            <div className="grid grid-cols-1 gap-4">
              <DetailField label="Title" value={selected.title} />
              <DetailField label="Description" value={selected.description} />
              <DetailField label="Category" value={<span className="capitalize">{selected.category}</span>} />
              <DetailField label="Beneficiary" value={displayName(selected)} />
              {selected.isAnonymous && selected.realName && (
                <DetailField label="Real Identity (Admin Only)" value={<span style={{ color: "#a78bfa" }}>{selected.realName}</span>} />
              )}
              <DetailField label="Donor" value={selected.donorName} />
              <DetailField label="Location" value={selected.location} />
              <DetailField label="Created" value={selected.createdAt ? new Date(selected.createdAt).toLocaleString() : null} />
              <DetailField label="Matched" value={selected.matchedAt ? new Date(selected.matchedAt).toLocaleString() : null} />
              <DetailField label="Delivered" value={selected.deliveredAt ? new Date(selected.deliveredAt).toLocaleString() : null} />
              <DetailField label="Completed" value={selected.completedAt ? new Date(selected.completedAt).toLocaleString() : null} />
              {selected.cancellationReason && <DetailField label="Cancellation Reason" value={selected.cancellationReason} />}
              {selected.cancelledBy && <DetailField label="Cancelled By" value={selected.cancelledBy} />}
              {selected.completionMethod && <DetailField label="Completion Method" value={selected.completionMethod} />}
            </div>

            {/* Admin actions */}
            <div className="pt-2 space-y-2">
              {!["completed", "cancelled"].includes(selected.status) && (
                <button onClick={() => doAction(selected.id, "cancel")}
                  className="w-full flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium hover:opacity-80"
                  style={{ background: "#451a03", color: "#fcd34d" }}>
                  <XCircle size={16} /> Cancel Request
                </button>
              )}
              {selected.status === "pending" && (
                <button onClick={() => doAction(selected.id, "complete")}
                  className="w-full flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium hover:opacity-80"
                  style={{ background: "#064e3b", color: "#34d399" }}>
                  <CheckCircle size={16} /> Mark Completed
                </button>
              )}
              <button onClick={() => doAction(selected.id, "delete")}
                className="w-full flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium hover:opacity-80"
                style={{ background: "#450a0a", color: "#f87171" }}>
                <Trash2 size={16} /> Delete Request
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
