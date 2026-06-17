import { NextResponse } from "next/server";
import { adminStorage } from "@/lib/firebase-admin";
import { verifyAdminToken } from "@/lib/api-auth";

export async function GET(request: Request) {
  if (!(await verifyAdminToken(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { searchParams } = new URL(request.url);
  const uid = searchParams.get("uid");
  if (!uid) return NextResponse.json({ error: "Missing uid" }, { status: 400 });

  try {
    const bucket = adminStorage.bucket("helplink-73412.firebasestorage.app");
    const file = bucket.file(`ic_photos/${uid}.jpg`);
    const [exists] = await file.exists();
    if (!exists) {
      return NextResponse.json({ error: "Not found" }, { status: 404 });
    }
    const [buffer] = await file.download();
    return new Response(new Uint8Array(buffer), {
      headers: {
        "Content-Type": "image/jpeg",
        "Cache-Control": "private, max-age=300",
      },
    });
  } catch (err) {
    console.error("[IC Photo] Error:", err);
    return NextResponse.json({ error: "Failed to get photo" }, { status: 500 });
  }
}
