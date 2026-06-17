import { NextResponse } from "next/server";
import { adminDb, adminAuth } from "@/lib/firebase-admin";
import { verifyAdminToken } from "@/lib/api-auth";
import { Timestamp, FieldValue } from "firebase-admin/firestore";

function toDate(v: unknown): string | undefined {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  return undefined;
}

export async function GET(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const snap = await adminDb.collection("users").orderBy("createdAt", "desc").get();
  const docs = snap.docs;

  // Batch-verify which UIDs still exist in Firebase Auth (chunks of 100)
  const notFoundUids = new Set<string>();
  for (let i = 0; i < docs.length; i += 100) {
    const identifiers = docs.slice(i, i + 100).map((d) => ({ uid: d.id }));
    const result = await adminAuth.getUsers(identifiers);
    result.notFound.forEach((id) => {
      if ("uid" in id) notFoundUids.add(id.uid as string);
    });
  }

  // Detect emails that appear on more than one Firestore document
  const emailCount: Record<string, number> = {};
  docs.forEach((doc) => {
    const email = (doc.data().email as string) ?? "";
    if (email) emailCount[email] = (emailCount[email] ?? 0) + 1;
  });

  const users = docs.map((doc) => {
    const d = doc.data();
    const email = (d.email as string) ?? "";
    return {
      uid: doc.id,
      fullName: d.fullName ?? "",
      email,
      role: d.role ?? "beneficiary",
      isEmailVerified: d.isEmailVerified === true,
      createdAt: toDate(d.createdAt),
      profileImageUrl: d.profileImageUrl ?? null,
      location: d.location ?? null,
      icNumber: d.icNumber ?? null,
      phoneNumber: d.phoneNumber ?? null,
      isICVerified: d.isICVerified === true,
      icVerifiedAt: toDate(d.icVerifiedAt),
      icPendingVerification: d.icPendingVerification === true,
      isPhoneVerified: d.isPhoneVerified === true,
      cancellationStrikes: d.cancellationStrikes ?? 0,
      banUntil: toDate(d.banUntil),
      autoWithdrawalCount: d.autoWithdrawalCount ?? 0,
      authDeleted: notFoundUids.has(doc.id),
      duplicateEmail: (emailCount[email] ?? 0) > 1,
    };
  });

  return NextResponse.json(users);
}

export async function PATCH(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { uid, action, banHours } = await request.json();
  if (!uid || !action) return NextResponse.json({ error: "Missing fields" }, { status: 400 });

  const ref = adminDb.collection("users").doc(uid);

  switch (action) {
    case "ban": {
      const hours = banHours ?? 24;
      const banUntil = new Date(Date.now() + hours * 60 * 60 * 1000);
      await ref.update({ banUntil: Timestamp.fromDate(banUntil) });
      break;
    }
    case "unban":
      await ref.update({ banUntil: FieldValue.delete() });
      break;
    case "verifyIC":
      await ref.update({
        isICVerified: true,
        icPendingVerification: false,
        icVerifiedAt: Timestamp.now(),
      });
      break;
    case "rejectIC":
      await ref.update({ icPendingVerification: false });
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

  const { uid } = await request.json();
  if (!uid) return NextResponse.json({ error: "Missing uid" }, { status: 400 });

  await Promise.all([
    // Auth user may already be gone if they self-deleted
    adminAuth.deleteUser(uid).catch((e: { code: string }) => {
      if (e.code !== "auth/user-not-found") throw e;
    }),
    adminDb.collection("users").doc(uid).delete(),
  ]);

  return NextResponse.json({ success: true });
}
