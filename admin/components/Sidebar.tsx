"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { LayoutDashboard, Users, ClipboardList, Flag, LogOut } from "lucide-react";
import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";

const navItems = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/users", label: "Users", icon: Users },
  { href: "/requests", label: "Aid Requests", icon: ClipboardList },
  { href: "/reports", label: "Reports", icon: Flag },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  async function handleSignOut() {
    await signOut(auth);
    router.push("/login");
  }

  return (
    <aside className="w-60 min-h-screen flex flex-col" style={{ background: "var(--bg-sidebar)", borderRight: "1px solid var(--border)" }}>
      <div className="px-6 py-5" style={{ borderBottom: "1px solid var(--border)" }}>
        <h1 className="text-lg font-bold" style={{ color: "#a78bfa" }}>HelpLink</h1>
        <p className="text-xs mt-0.5" style={{ color: "var(--text-secondary)" }}>Admin Panel</p>
      </div>

      <nav className="flex-1 px-3 py-4 space-y-1">
        {navItems.map(({ href, label, icon: Icon }) => {
          const active = pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors"
              style={
                active
                  ? { background: "#7c3aed", color: "#fff" }
                  : { color: "var(--text-secondary)" }
              }
              onMouseEnter={(e) => {
                if (!active) (e.currentTarget as HTMLElement).style.background = "#1e1e30";
              }}
              onMouseLeave={(e) => {
                if (!active) (e.currentTarget as HTMLElement).style.background = "transparent";
              }}
            >
              <Icon size={18} />
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="px-3 py-4" style={{ borderTop: "1px solid var(--border)" }}>
        <button
          onClick={handleSignOut}
          className="flex items-center gap-3 px-3 py-2.5 w-full rounded-lg text-sm font-medium transition-colors"
          style={{ color: "var(--text-secondary)" }}
          onMouseEnter={(e) => ((e.currentTarget as HTMLElement).style.background = "#1e1e30")}
          onMouseLeave={(e) => ((e.currentTarget as HTMLElement).style.background = "transparent")}
        >
          <LogOut size={18} />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
