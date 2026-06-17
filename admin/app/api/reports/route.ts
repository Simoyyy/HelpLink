import { NextResponse } from "next/server";
import { adminDb } from "@/lib/firebase-admin";
import { verifyAdminToken } from "@/lib/api-auth";
import { Timestamp } from "firebase-admin/firestore";

function toDate(v: unknown): string | undefined {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  return undefined;
}

export async function GET(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const snap = await adminDb.collection("reports").orderBy("createdAt", "desc").get();

  const reports = snap.docs.map((doc) => {
    const d = doc.data();
    return {
      id: doc.id,
      reporterId: d.reporterId ?? "",
      reporterRole: d.reporterRole ?? "",
      type: d.type ?? "app",
      targetId: d.targetId ?? null,
      category: d.category ?? "",
      description: d.description ?? "",
      photoUrl: d.photoUrl ?? null,
      status: d.status ?? "pending",
      createdAt: toDate(d.createdAt),
    };
  });

  return NextResponse.json(reports);
}

export async function PATCH(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id, status } = await request.json();
  if (!id || !status) {
    return NextResponse.json({ error: "Missing id or status" }, { status: 400 });
  }

  await adminDb.collection("reports").doc(id).update({ status });
  return NextResponse.json({ success: true });
}
