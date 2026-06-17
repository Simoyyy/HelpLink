import { NextResponse } from "next/server";
import { adminDb } from "@/lib/firebase-admin";
import { verifyAdminToken } from "@/lib/api-auth";
import { Timestamp } from "firebase-admin/firestore";

function toDate(v: unknown): string | undefined {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  return undefined;
}

function mapDoc(doc: FirebaseFirestore.DocumentSnapshot, realNames: Record<string, string> = {}) {
  const d = doc.data() ?? {};
  const isAnonymous = d.isAnonymous === true;
  const beneficiaryId = d.beneficiaryId as string;
  return {
    id: doc.id,
    beneficiaryId,
    beneficiaryName: d.beneficiaryName ?? "",
    realName: isAnonymous ? (realNames[beneficiaryId] ?? "Unknown") : null,
    title: d.title ?? "",
    description: d.description ?? "",
    category: d.category ?? "other",
    status: d.status ?? "pending",
    isAnonymous,
    location: d.location ?? null,
    donorId: d.donorId ?? null,
    donorName: d.donorName ?? null,
    createdAt: toDate(d.createdAt),
    matchedAt: toDate(d.matchedAt),
    completedAt: toDate(d.completedAt),
    deliveredAt: toDate(d.deliveredAt),
    isEmergency: d.isEmergency === true,
    cancellationReason: d.cancellationReason ?? null,
    cancelledBy: d.cancelledBy ?? null,
    completionMethod: d.completionMethod ?? null,
    completionPhotoUrl: d.completionPhotoUrl ?? null,
  };
}

export async function GET(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { searchParams } = new URL(request.url);
  const singleId = searchParams.get("id");

  // Single-request lookup used by the reports page
  if (singleId) {
    const doc = await adminDb.collection("help_requests").doc(singleId).get();
    if (!doc.exists) return NextResponse.json(null);
    const d = doc.data() ?? {};
    if (d.isAnonymous === true && d.beneficiaryId) {
      const userDoc = await adminDb.collection("users").doc(d.beneficiaryId as string).get();
      const realNames = userDoc.exists ? { [d.beneficiaryId as string]: (userDoc.data()?.fullName as string) ?? "Unknown" } : {};
      return NextResponse.json(mapDoc(doc, realNames));
    }
    return NextResponse.json(mapDoc(doc));
  }

  const snap = await adminDb.collection("help_requests").orderBy("createdAt", "desc").get();

  const anonymousIds = new Set<string>();
  snap.docs.forEach((doc) => {
    const d = doc.data();
    if (d.isAnonymous === true && d.beneficiaryId) anonymousIds.add(d.beneficiaryId as string);
  });

  const realNames: Record<string, string> = {};
  if (anonymousIds.size > 0) {
    await Promise.all(
      Array.from(anonymousIds).map(async (uid) => {
        const userDoc = await adminDb.collection("users").doc(uid).get();
        if (userDoc.exists) realNames[uid] = (userDoc.data()?.fullName as string) ?? "Unknown";
      })
    );
  }

  const requests = snap.docs.map((doc) => mapDoc(doc, realNames));

  return NextResponse.json(requests);
}

export async function PATCH(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id, action } = await request.json();
  if (!id || !action) return NextResponse.json({ error: "Missing fields" }, { status: 400 });

  const ref = adminDb.collection("help_requests").doc(id);

  switch (action) {
    case "cancel":
      await ref.update({ status: "cancelled", cancelledBy: "admin", cancellationReason: "Cancelled by admin" });
      break;
    case "complete":
      await ref.update({ status: "completed", completedAt: Timestamp.now() });
      break;
    default:
      return NextResponse.json({ error: "Unknown action" }, { status: 400 });
  }

  return NextResponse.json({ success: true });
}

export async function DELETE(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await request.json();
  if (!id) return NextResponse.json({ error: "Missing id" }, { status: 400 });

  await adminDb.collection("help_requests").doc(id).delete();
  return NextResponse.json({ success: true });
}
