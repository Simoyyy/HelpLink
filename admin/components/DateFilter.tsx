"use client";

const PRESETS = [
  { key: "all",  label: "All time" },
  { key: "today", label: "Today" },
  { key: "3d",   label: "3 days" },
  { key: "7d",   label: "1 week" },
  { key: "30d",  label: "1 month" },
  { key: "90d",  label: "3 months" },
  { key: "1y",   label: "1 year" },
] as const;

type PresetKey = (typeof PRESETS)[number]["key"];

function toDateStr(d: Date): string {
  return d.toISOString().split("T")[0];
}

function getPresetDate(key: PresetKey): string | null {
  const d = new Date();
  switch (key) {
    case "all":   return null;
    case "today": return toDateStr(d);
    case "3d":    d.setDate(d.getDate() - 3); return toDateStr(d);
    case "7d":    d.setDate(d.getDate() - 7); return toDateStr(d);
    case "30d":   d.setMonth(d.getMonth() - 1); return toDateStr(d);
    case "90d":   d.setMonth(d.getMonth() - 3); return toDateStr(d);
    case "1y":    d.setFullYear(d.getFullYear() - 1); return toDateStr(d);
  }
}

function detectActivePreset(dateFrom: string, dateTo: string): PresetKey | "custom" {
  if (!dateFrom && !dateTo) return "all";
  if (!dateTo) {
    for (const p of PRESETS) {
      if (p.key === "all") continue;
      if (dateFrom === getPresetDate(p.key)) return p.key;
    }
  }
  return "custom";
}

const inputStyle = {
  background: "#1a1a28",
  border: "1px solid var(--border)",
  color: "var(--text-primary)",
};

interface Props {
  dateFrom: string;
  dateTo: string;
  onDateFromChange: (v: string) => void;
  onDateToChange: (v: string) => void;
}

export default function DateFilter({ dateFrom, dateTo, onDateFromChange, onDateToChange }: Props) {
  const active = detectActivePreset(dateFrom, dateTo);

  function applyPreset(key: PresetKey) {
    const date = getPresetDate(key);
    onDateFromChange(date ?? "");
    onDateToChange("");
  }

  return (
    <div className="space-y-2">
      {/* Quick presets */}
      <div className="flex flex-wrap gap-1.5 items-center">
        <span className="text-xs mr-1" style={{ color: "var(--text-secondary)" }}>Quick:</span>
        {PRESETS.map((p) => (
          <button
            key={p.key}
            onClick={() => applyPreset(p.key)}
            className="px-2.5 py-1 rounded-md text-xs font-medium transition-colors"
            style={
              active === p.key
                ? { background: "#7c3aed", color: "#fff" }
                : { background: "#1a1a28", border: "1px solid var(--border)", color: "var(--text-secondary)" }
            }
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* Specific date range */}
      <div className="flex flex-wrap gap-2 items-center">
        <span className="text-xs" style={{ color: "var(--text-secondary)" }}>From:</span>
        <input
          type="date"
          value={dateFrom}
          onChange={(e) => onDateFromChange(e.target.value)}
          className="px-3 py-1.5 rounded-lg text-sm outline-none"
          style={inputStyle}
        />
        <span className="text-xs" style={{ color: "var(--text-secondary)" }}>To:</span>
        <input
          type="date"
          value={dateTo}
          onChange={(e) => onDateToChange(e.target.value)}
          className="px-3 py-1.5 rounded-lg text-sm outline-none"
          style={inputStyle}
        />
      </div>
    </div>
  );
}
