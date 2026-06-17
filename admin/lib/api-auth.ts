import { adminAuth } from "./firebase-admin";

export async function verifyAdminToken(request: Request): Promise<boolean> {
  const token = request.headers.get("Authorization")?.replace("Bearer ", "");
  if (!token) return false;
  try {
    const decoded = await adminAuth.verifyIdToken(token);
    return decoded.email === process.env.ADMIN_EMAIL;
  } catch {
    return false;
  }
}
