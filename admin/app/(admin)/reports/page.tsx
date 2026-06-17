"use client";

import { useEffect, useState } from "react";
import { apiFetch } from "@/lib/api-client";
import type { Report, ReportStatus } from "@/lib/types";
import { Search, X, XCircle, Trash2, CheckCircle, ExternalLink } from "lucide-react";
import DateFilter from "@/components/DateFilter";
import Link from "next/link";

interface RequestDetail {
  id: string;
  title: string;
  description: string;
  category: string;
  status: string;
  isAnonymous: boolean;
  beneficiaryName: string;
  realName: string | null;
  donorName: string | null;
  isEmergency: boolean;
  createdAt: string | null;
  cancellationReason: string | null;
}

const STATUS_STYLES: Record<ReportStatus, { bg: string; color: string }> = {
  pending:   { bg: "#451a03", color: "#fcd34d" },
  reviewed:  { bg: "#1e1b4b", color: "#a5b4fc" },
  resolved:  { bg: "#064e3b", color: "#6ee7b7" },
  dismissed: { bg: "#1a1a28", color: "#8b8ba8" },
};

const REQ_STATUS_STYLES: Record<string, { bg: string; color: string }> = {
  pending:             { bg: "#451a03", color: "#fcd34d" },
  matched:             { bg: "#1e1b4b", color: "#a5b4fc" },
  active:              { bg: "#2e1065", color: "#c4b5fd" },
  pendingConfirmation: { bg: "#431407", color: "#fdba74" },
  completed:           { bg: "#064e3b", color: "#6ee7b7" },
  cancelled:           { bg: "#450a0a", color: "#fca5a5" },
};

const ALL_STATUSES: ReportStatus[] = ["pending", "reviewed", "resolved", "dismissed"];

const inputStyle = { background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-primary)" };
const card = { background: "var(--bg-card)", border: "1px solid var(--border)" };

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs mb-0.5" style={{ color: "var(--text-secondary)" }}>{label}</p>
      <div className="text-sm" style={{ color: "var(--text-primary)" }}>{children || "—"}</div>
    </div>
  );
}

export default function ReportsPage() {
  const [reports, setReports] = useState<Report[]>([]);
  const [filtered, setFiltered] = useState<Report[]>([]);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<ReportStatus | "all">("all");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [selected, setSelected] = useState<Report | null>(null);
  const [reqDetail, setReqDetail] = useState<RequestDetail | null>(null);
  const [reqLoading, setReqLoading] = useState(false);
  const [actionMsg, setActionMsg] = useState("");

  useEffect(() => {
    apiFetch("/api/reports")
      .then((data) => { setReports(data); setLoading(false); })
      .catch(() => { setError("Failed to load reports."); setLoading(false); });
  }, []);

  useEffect(() => {
    let result = reports;
    if (statusFilter !== "all") result = result.filter((r) => r.status === statusFilter);
    if (search.trim()) {
      const q = search.toLowerCase();
      result = result.filter(
        (r) => r.category.toLowerCase().includes(q) || r.description.toLowerCase().includes(q)
      );
    }
    if (dateFrom) result = result.filter((r) => r.createdAt && new Date(r.createdAt as unknown as string) >= new Date(dateFrom));
    if (dateTo) {
      const end = new Date(dateTo); end.setDate(end.getDate() + 1);
      result = result.filter((r) => r.createdAt && new Date(r.createdAt as unknown as string) < end);
    }
    setFiltered(result);
  }, [search, statusFilter, dateFrom, dateTo, reports]);

  async function openReport(report: Report) {
    setSelected(report);
    setReqDetail(null);
    setActionMsg("");
    if (report.type === "request" && report.targetId) {
      setReqLoading(true);
      try {
        const data = await apiFetch(`/api/requests?id=${report.targetId}`);
        setReqDetail(data);
      } catch {
        setReqDetail(null);
      } finally {
        setReqLoading(false);
      }
    }
  }

  async function updateReportStatus(id: string, status: ReportStatus) {
    try {
      await apiFetch("/api/reports", { method: "PATCH", body: JSON.stringify({ id, status }) });
      setReports((prev) => prev.map((r) => (r.id === id ? { ...r, status } : r)));
      if (selected?.id === id) setSelected((s) => s ? { ...s, status } : s);
      setActionMsg(`Report marked as ${status}.`);
    } catch {
      setActionMsg("Failed to update report status.");
    }
  }

  async function doRequestAction(requestId: string, action: "cancel" | "delete") {
    const confirmMsg = action === "delete"
      ? "Permanently delete this request? This cannot be undone."
      : "Cancel this request?";
    if (!confirm(confirmMsg)) return;
    try {
      if (action === "delete") {
        await apiFetch("/api/requests", { method: "DELETE", body: JSON.stringify({ id: requestId }) });
        setReqDetail(null);
        setActionMsg("Request deleted.");
      } else {
        await apiFetch("/api/requests", { method: "PATCH", body: JSON.stringify({ id: requestId, action: "cancel" }) });
        setReqDetail((prev) => prev ? { ...prev, status: "cancelled", cancellationReason: "Cancelled by admin" } : prev);
        setActionMsg("Request cancelled.");
      }
    } catch {
      setActionMsg("Action failed. Please try again.");
    }
  }

  const isClosed = (status: string) => ["completed", "cancelled"].includes(status);

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6" style={{ color: "var(--text-primary)" }}>Reports</h2>

      <div className="space-y-3 mb-4">
        <div className="flex flex-col sm:flex-row gap-2">
          <div className="relative flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--text-secondary)" }} />
            <input type="text" placeholder="Search by category or description…" value={search}
              onChange={(e) => setSearch(e.target.value)} className="w-full pl-9 pr-3 py-2 rounded-lg text-sm outline-none" style={inputStyle} />
          </div>
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as typeof statusFilter)}
            className="px-3 py-2 rounded-lg text-sm outline-none" style={inputStyle}>
            <option value="all">All Statuses</option>
            {ALL_STATUSES.map((s) => <option key={s} value={s} className="capitalize">{s}</option>)}
          </select>
        </div>
        <DateFilter dateFrom={dateFrom} dateTo={dateTo} onDateFromChange={setDateFrom} onDateToChange={setDateTo} />
        {(dateFrom || dateTo || search || statusFilter !== "all") && (
          <button onClick={() => { setDateFrom(""); setDateTo(""); setSearch(""); setStatusFilter("all"); }}
            className="px-3 py-1.5 rounded-lg text-xs" style={{ background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-secondary)" }}>
            Clear all ×
          </button>
        )}
      </div>

      {error && <p className="text-sm px-4 py-3 rounded-lg mb-4" style={{ background: "#3b0a0a", color: "#fca5a5" }}>{error}</p>}

      <div className="rounded-xl overflow-hidden" style={card}>
        {loading ? (
          <div className="flex items-center justify-center py-16 text-sm" style={{ color: "var(--text-secondary)" }}>Loading reports…</div>
        ) : filtered.length === 0 ? (
          <div className="flex items-center justify-center py-16 text-sm" style={{ color: "var(--text-secondary)" }}>No reports found.</div>
        ) : (
          <table className="w-full text-sm">
            <thead style={{ background: "#0d0d14", borderBottom: "1px solid var(--border)" }}>
              <tr>
                {["Category", "Type", "Reporter", "Description", "Status", "Date"].map((h) => (
                  <th key={h} className="text-left px-4 py-3 font-medium" style={{ color: "var(--text-secondary)" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((report, i) => (
                <tr key={report.id}
                  className="cursor-pointer transition-colors"
                  onClick={() => openReport(report)}
                  style={{ borderTop: i === 0 ? "none" : "1px solid var(--border)" }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = "#1a1a28")}
                  onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
                >
                  <td className="px-4 py-3 font-medium" style={{ color: "var(--text-primary)" }}>{report.category}</td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-0.5 rounded-full text-xs font-medium capitalize"
                      style={report.type === "request"
                        ? { background: "#1e1b4b", color: "#a5b4fc" }
                        : { background: "#1a1a28", color: "var(--text-secondary)" }
                      }>
                      {report.type}
                    </span>
                  </td>
                  <td className="px-4 py-3 capitalize" style={{ color: "var(--text-secondary)" }}>{report.reporterRole}</td>
                  <td className="px-4 py-3 max-w-56 truncate" style={{ color: "var(--text-secondary)" }} title={report.description}>
                    {report.description}
                  </td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-0.5 rounded-full text-xs font-medium capitalize" style={STATUS_STYLES[report.status]}>
                      {report.status}
                    </span>
                  </td>
                  <td className="px-4 py-3" style={{ color: "var(--text-secondary)" }}>
                    {report.createdAt ? new Date(report.createdAt as unknown as string).toLocaleDateString() : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <p className="text-xs mt-2" style={{ color: "var(--text-secondary)" }}>{filtered.length} report(s) shown</p>

      {/* Detail slide-over */}
      {selected && (
        <div className="fixed inset-0 z-50 flex justify-end" style={{ background: "rgba(0,0,0,0.6)" }} onClick={() => setSelected(null)}>
          <div className="w-full max-w-lg h-full overflow-y-auto flex flex-col"
            style={{ background: "var(--bg-card)", borderLeft: "1px solid var(--border)" }}
            onClick={(e) => e.stopPropagation()}>

            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 sticky top-0 z-10"
              style={{ background: "var(--bg-card)", borderBottom: "1px solid var(--border)" }}>
              <div className="flex items-center gap-2">
                <h3 className="font-semibold" style={{ color: "var(--text-primary)" }}>Report Detail</h3>
                <span className="px-2 py-0.5 rounded-full text-xs font-medium capitalize" style={STATUS_STYLES[selected.status]}>
                  {selected.status}
                </span>
              </div>
              <button onClick={() => setSelected(null)} style={{ color: "var(--text-secondary)" }}><X size={20} /></button>
            </div>

            <div className="px-6 py-5 space-y-6 flex-1">

              {actionMsg && (
                <p className="text-xs px-3 py-2 rounded-lg" style={{ background: "#064e3b", color: "#6ee7b7" }}>{actionMsg}</p>
              )}

              {/* Report details */}
              <section className="space-y-3">
                <p className="text-xs font-semibold uppercase tracking-widest" style={{ color: "var(--text-secondary)" }}>Report</p>
                <div className="grid grid-cols-2 gap-3">
                  <Field label="Category">{selected.category}</Field>
                  <Field label="Type">
                    <span className="capitalize">{selected.type}</span>
                  </Field>
                  <Field label="Reporter Role">
                    <span className="capitalize">{selected.reporterRole}</span>
                  </Field>
                  <Field label="Submitted">
                    {selected.createdAt ? new Date(selected.createdAt as unknown as string).toLocaleString() : "—"}
                  </Field>
                </div>
                <Field label="Description">{selected.description}</Field>
                {selected.photoUrl && (
                  <Field label="Attached Photo">
                    <a href={selected.photoUrl} target="_blank" rel="noreferrer"
                      className="text-sm underline" style={{ color: "#a78bfa" }}>
                      View photo ↗
                    </a>
                  </Field>
                )}
              </section>

              {/* Report status actions */}
              <section className="space-y-2">
                <p className="text-xs font-semibold uppercase tracking-widest" style={{ color: "var(--text-secondary)" }}>Update Report Status</p>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    disabled={selected.status === "resolved"}
                    onClick={() => updateReportStatus(selected.id, "resolved")}
                    className="flex items-center justify-center gap-2 py-2 rounded-lg text-sm font-medium disabled:opacity-40"
                    style={{ background: "#064e3b", color: "#34d399" }}>
                    <CheckCircle size={15} /> Mark Resolved
                  </button>
                  <button
                    disabled={selected.status === "dismissed"}
                    onClick={() => updateReportStatus(selected.id, "dismissed")}
                    className="flex items-center justify-center gap-2 py-2 rounded-lg text-sm font-medium disabled:opacity-40"
                    style={{ background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-secondary)" }}>
                    <XCircle size={15} /> Dismiss
                  </button>
                  <button
                    disabled={selected.status === "reviewed"}
                    onClick={() => updateReportStatus(selected.id, "reviewed")}
                    className="flex items-center justify-center gap-2 py-2 rounded-lg text-sm font-medium disabled:opacity-40 col-span-2"
                    style={{ background: "#1e1b4b", color: "#a5b4fc" }}>
                    Mark Reviewed
                  </button>
                </div>
              </section>

              {/* Reported request section */}
              {selected.type === "request" && (
                <section className="space-y-3">
                  <p className="text-xs font-semibold uppercase tracking-widest" style={{ color: "var(--text-secondary)" }}>
                    Reported Aid Request
                  </p>

                  {reqLoading && (
                    <p className="text-sm" style={{ color: "var(--text-secondary)" }}>Loading request…</p>
                  )}

                  {!reqLoading && !reqDetail && (
                    <p className="text-sm" style={{ color: "var(--text-secondary)" }}>
                      {selected.targetId ? "Request not found — it may have been deleted." : "No request linked to this report."}
                    </p>
                  )}

                  {reqDetail && (
                    <div className="rounded-xl p-4 space-y-3" style={{ background: "#0d0d14", border: "1px solid var(--border)" }}>
                      <div className="flex items-start justify-between gap-2">
                        <div className="space-y-1">
                          <p className="font-medium text-sm" style={{ color: "var(--text-primary)" }}>{reqDetail.title}</p>
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="px-2 py-0.5 rounded-full text-xs font-medium"
                              style={REQ_STATUS_STYLES[reqDetail.status] ?? { bg: "#1a1a28", color: "#8b8ba8" }}>
                              {reqDetail.status}
                            </span>
                            {reqDetail.isEmergency && (
                              <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#450a0a", color: "#f87171" }}>
                                Emergency
                              </span>
                            )}
                            {reqDetail.isAnonymous && (
                              <span className="px-2 py-0.5 rounded-full text-xs font-medium" style={{ background: "#2e1065", color: "#c4b5fd" }}>
                                Anonymous
                              </span>
                            )}
                          </div>
                        </div>
                        <Link href={`/requests?search=${encodeURIComponent(reqDetail.title)}`}
                          className="shrink-0 p-1.5 rounded-lg transition-opacity hover:opacity-70"
                          style={{ background: "#1a1a28", color: "var(--text-secondary)" }}
                          title="Open in Requests page">
                          <ExternalLink size={14} />
                        </Link>
                      </div>

                      <div className="grid grid-cols-2 gap-3 text-sm">
                        <Field label="Category"><span className="capitalize">{reqDetail.category}</span></Field>
                        <Field label="Created">
                          {reqDetail.createdAt ? new Date(reqDetail.createdAt).toLocaleDateString() : "—"}
                        </Field>
                        <Field label="Beneficiary">
                          {reqDetail.isAnonymous && reqDetail.realName
                            ? <><span style={{ color: "#a78bfa" }}>{reqDetail.realName}</span> <span className="text-xs">(Anonymous)</span></>
                            : reqDetail.beneficiaryName}
                        </Field>
                        <Field label="Donor">{reqDetail.donorName}</Field>
                      </div>

                      <Field label="Description">{reqDetail.description}</Field>

                      {reqDetail.cancellationReason && (
                        <Field label="Cancellation Reason">{reqDetail.cancellationReason}</Field>
                      )}

                      {/* Request actions */}
                      {!isClosed(reqDetail.status) && (
                        <div className="flex gap-2 pt-1">
                          <button
                            onClick={() => doRequestAction(reqDetail.id, "cancel")}
                            className="flex-1 flex items-center justify-center gap-2 py-2 rounded-lg text-sm font-medium hover:opacity-80"
                            style={{ background: "#451a03", color: "#fcd34d" }}>
                            <XCircle size={14} /> Cancel Request
                          </button>
                          <button
                            onClick={() => doRequestAction(reqDetail.id, "delete")}
                            className="flex-1 flex items-center justify-center gap-2 py-2 rounded-lg text-sm font-medium hover:opacity-80"
                            style={{ background: "#450a0a", color: "#f87171" }}>
                            <Trash2 size={14} /> Delete Request
                          </button>
                        </div>
                      )}

                      {isClosed(reqDetail.status) && (
                        <div className="flex gap-2 pt-1">
                          <button
                            onClick={() => doRequestAction(reqDetail.id, "delete")}
                            className="w-full flex items-center justify-center gap-2 py-2 rounded-lg text-sm font-medium hover:opacity-80"
                            style={{ background: "#450a0a", color: "#f87171" }}>
                            <Trash2 size={14} /> Delete Request
                          </button>
                        </div>
                      )}
                    </div>
                  )}
                </section>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
