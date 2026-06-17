import { NextResponse } from "next/server";
import { adminDb, adminAuth } from "@/lib/firebase-admin";
import { verifyAdminToken } from "@/lib/api-auth";
import { Timestamp } from "firebase-admin/firestore";

export async function GET(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const now = new Date();

  const [usersSnap, requestsSnap, reportsSnap] = await Promise.all([
    adminDb.collection("users").get(),
    adminDb.collection("help_requests").get(),
    adminDb.collection("reports").where("status", "==", "pending").count().get(),
  ]);

  // Batch-verify which UIDs still exist in Firebase Auth (chunks of 100)
  const allDocs = usersSnap.docs;
  const notFoundUids = new Set<string>();
  for (let i = 0; i < allDocs.length; i += 100) {
    const identifiers = allDocs.slice(i, i + 100).map((d) => ({ uid: d.id }));
    const result = await adminAuth.getUsers(identifiers);
    result.notFound.forEach((id) => {
      if ("uid" in id) notFoundUids.add(id.uid as string);
    });
  }

  // Only count users who still have an active Auth account
  const activeDocs = allDocs.filter((d) => !notFoundUids.has(d.id));
  const users = activeDocs.map((d) => d.data());

  // User breakdown — derived from active docs only
  let bannedCount = 0;
  let icPendingCount = 0;
  let icVerifiedCount = 0;
  let newUsersThisWeek = 0;

  for (const u of users) {
    const banUntil = (u.banUntil as Timestamp | null)?.toDate();
    if (banUntil && banUntil > now) bannedCount++;
    if (u.icPendingVerification === true) icPendingCount++;
    if (u.isICVerified === true) icVerifiedCount++;
    const createdAt = (u.createdAt as Timestamp | null)?.toDate();
    if (createdAt && createdAt.getTime() >= weekAgo) newUsersThisWeek++;
  }

  // Request breakdown
  const requests = requestsSnap.docs.map((d) => d.data());
  const byStatus: Record<string, number> = {};
  const byCategory: Record<string, number> = {};
  let completed = 0;
  let cancelled = 0;
  let activeCount = 0;
  let emergencyCount = 0;

  let pendingCount = 0;

  for (const r of requests) {
    const status = r.status as string;
    const category = r.category as string;
    byStatus[status] = (byStatus[status] ?? 0) + 1;
    byCategory[category] = (byCategory[category] ?? 0) + 1;
    if (status === "completed") completed++;
    if (status === "cancelled") cancelled++;
    if (status === "pending") pendingCount++;
    if (["matched", "active", "pendingConfirmation"].includes(status)) activeCount++;
    if (r.isEmergency === true && status === "pending") emergencyCount++;
  }

  const nonCancelled = requests.length - cancelled;
  const completionRate = nonCancelled > 0 ? Math.round((completed / nonCancelled) * 100) : 0;

  return NextResponse.json({
    totalUsers: users.length,
    bannedCount,
    newUsersThisWeek,
    icPendingCount,
    icVerifiedCount,
    totalRequests: requests.length,
    pendingRequests: pendingCount,
    completedRequests: completed,
    activeRequests: activeCount,
    emergencyRequests: emergencyCount,
    completionRate,
    pendingReports: reportsSnap.data().count,
    byStatus,
    byCategory,
  });
}
