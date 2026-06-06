import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

setGlobalOptions({ region: "asia-southeast1" });

admin.initializeApp();

const gmailEmail = defineSecret("GMAIL_EMAIL");
const gmailPassword = defineSecret("GMAIL_APP_PASSWORD");

const db = admin.firestore();

function generateCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function createTransport(email: string, password: string) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user: email, pass: password },
  });
}

// ─── Email Templates ────────────────────────────────────────────────────────

function verificationTemplate(code: string, name: string): string {
  const spaced = code;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Email Verification – HelpLink</title>
</head>
<body style="margin:0;padding:0;background-color:#071a3e;font-family:'Segoe UI',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#071a3e;padding:40px 16px;">
    <tr><td align="center">
      <table width="540" cellpadding="0" cellspacing="0" style="max-width:540px;width:100%;">

        <!-- Branding -->
        <tr><td align="center" style="padding-bottom:28px;">
          <table cellpadding="0" cellspacing="0"><tr>
            <td align="center" style="width:64px;height:64px;background:linear-gradient(135deg,#1565c0,#0097a7);border-radius:50%;">
              <span style="color:#fff;font-size:28px;font-weight:700;line-height:64px;display:block;">H</span>
            </td>
          </tr></table>
          <div style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:2px;margin-top:10px;">HelpLink</div>
          <div style="color:#7fb3d3;font-size:12px;margin-top:4px;">Connecting Communities &middot; Changing Lives</div>
        </td></tr>

        <!-- Card -->
        <tr><td style="background:#0d2452;border-radius:18px;overflow:hidden;">

          <!-- Card header -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td align="center" style="background:linear-gradient(135deg,#1565c0 0%,#0097a7 100%);padding:30px 32px 24px;">
              <div style="color:#ffffff;font-size:22px;font-weight:700;letter-spacing:0.5px;">Verify Your Email</div>
              <div style="color:#c8e6ff;font-size:14px;margin-top:8px;">Hi ${name}! Let's get you set up.</div>
            </td></tr>
          </table>

          <!-- Code section -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:34px 40px 28px;text-align:center;">
              <p style="color:#a8c8e8;font-size:15px;line-height:1.6;margin:0 0 26px 0;">
                Here's your verification code:
              </p>
              <table cellpadding="0" cellspacing="0" align="center">
                <tr><td style="background:#071a3e;border-radius:14px;padding:22px 36px;border:1px solid #1a4080;">
                  <span style="color:#ffffff;font-size:34px;font-weight:700;letter-spacing:20px;font-family:'Courier New',Courier,monospace;white-space:nowrap;display:block;text-indent:20px;">${spaced}</span>
                </td></tr>
              </table>
              <p style="color:#5a85a8;font-size:13px;margin:18px 0 0 0;">This code will expire soon.</p>
            </td></tr>
          </table>

          <!-- Safety notice -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:0 40px 30px;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="background:#071a3e;border-radius:10px;padding:14px 18px;border-left:3px solid #0097a7;">
                  <p style="color:#7a9cba;font-size:13px;line-height:1.5;margin:0;">
                    If you didn't create a HelpLink account, you can safely ignore this email. Your account will not be activated without verification.
                  </p>
                </td></tr>
              </table>
            </td></tr>
          </table>

          <!-- Footer -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td align="center" style="padding:16px 32px 24px;border-top:1px solid #1a3460;">
              <p style="color:#3a5a7a;font-size:11px;margin:0;">&copy; 2025 HelpLink. All rights reserved.</p>
            </td></tr>
          </table>

        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function passwordResetTemplate(code: string, name: string): string {
  const spaced = code;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Password Reset – HelpLink</title>
</head>
<body style="margin:0;padding:0;background-color:#071a3e;font-family:'Segoe UI',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#071a3e;padding:40px 16px;">
    <tr><td align="center">
      <table width="540" cellpadding="0" cellspacing="0" style="max-width:540px;width:100%;">

        <!-- Branding -->
        <tr><td align="center" style="padding-bottom:28px;">
          <table cellpadding="0" cellspacing="0"><tr>
            <td align="center" style="width:64px;height:64px;background:linear-gradient(135deg,#1565c0,#0097a7);border-radius:50%;">
              <span style="color:#fff;font-size:28px;font-weight:700;line-height:64px;display:block;">H</span>
            </td>
          </tr></table>
          <div style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:2px;margin-top:10px;">HelpLink</div>
          <div style="color:#7fb3d3;font-size:12px;margin-top:4px;">Connecting Communities &middot; Changing Lives</div>
        </td></tr>

        <!-- Card -->
        <tr><td style="background:#0d2452;border-radius:18px;overflow:hidden;">

          <!-- Card header – purple for reset -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td align="center" style="background:linear-gradient(135deg,#6a1b9a 0%,#4527a0 100%);padding:30px 32px 24px;">
              <div style="color:#ffffff;font-size:22px;font-weight:700;letter-spacing:0.5px;">Reset Your Password</div>
              <div style="color:#e1c8ff;font-size:14px;margin-top:8px;">Hi ${name}! Let's get you back in.</div>
            </td></tr>
          </table>

          <!-- Code section -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:34px 40px 28px;text-align:center;">
              <p style="color:#a8c8e8;font-size:15px;line-height:1.6;margin:0 0 26px 0;">
                Here's your password reset code:
              </p>
              <table cellpadding="0" cellspacing="0" align="center">
                <tr><td style="background:#071a3e;border-radius:14px;padding:22px 36px;border:1px solid #1a4080;">
                  <span style="color:#ffffff;font-size:34px;font-weight:700;letter-spacing:20px;font-family:'Courier New',Courier,monospace;white-space:nowrap;display:block;text-indent:20px;">${spaced}</span>
                </td></tr>
              </table>
              <p style="color:#5a85a8;font-size:13px;margin:18px 0 0 0;">This code will expire soon.</p>
            </td></tr>
          </table>

          <!-- Safety notice -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:0 40px 30px;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="background:#071a3e;border-radius:10px;padding:14px 18px;border-left:3px solid #6a1b9a;">
                  <p style="color:#7a9cba;font-size:13px;line-height:1.5;margin:0;">
                    If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.
                  </p>
                </td></tr>
              </table>
            </td></tr>
          </table>

          <!-- Footer -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td align="center" style="padding:16px 32px 24px;border-top:1px solid #1a3460;">
              <p style="color:#3a5a7a;font-size:11px;margin:0;">&copy; 2025 HelpLink. All rights reserved.</p>
            </td></tr>
          </table>

        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ─── Cloud Functions ─────────────────────────────────────────────────────────

export const sendEmailVerificationOTP = onCall(
  { secrets: [gmailEmail, gmailPassword], enforceAppCheck: false, invoker: 'public' },
  async (request) => {
    const { uid, email, name, fcmToken } = request.data as {
      uid: string;
      email: string;
      name?: string;
      fcmToken?: string;
    };

    if (!uid || !email) {
      throw new HttpsError("invalid-argument", "uid and email are required");
    }

    const code = generateCode();
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 15 * 60 * 1000)
    );

    await db.collection("email_otps").doc(uid).set({
      code,
      email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      used: false,
    });

    // Send push notification to device
    let fcmSent = false;
    if (fcmToken) {
      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "HelpLink Verification Code",
            body: `Your verification code is: ${code}. Valid for 15 minutes.`,
          },
          data: { type: "otp", code },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
        fcmSent = true;
      } catch (fcmErr) {
        console.error("FCM send failed:", fcmErr);
      }
    }

    // Send email
    try {
      const transport = createTransport(gmailEmail.value(), gmailPassword.value());
      await transport.sendMail({
        from: `"HelpLink" <${gmailEmail.value()}>`,
        to: email,
        subject: "Verify Your HelpLink Email",
        html: verificationTemplate(code, name ?? "there"),
      });
    } catch (err) {
      console.error("Email send failed:", err);
      if (!fcmSent) {
        throw new HttpsError(
          "unavailable",
          "Failed to send verification code. Please try again."
        );
      }
    }

    return { success: true };
  }
);

export const verifyEmailOTP = onCall(
  { enforceAppCheck: false, invoker: 'public' },
  async (request) => {
  const { uid, code } = request.data as { uid: string; code: string };

  if (!uid || !code) {
    throw new HttpsError("invalid-argument", "uid and code are required");
  }

  const snap = await db.collection("email_otps").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError(
      "not-found",
      "No verification code found. Please request a new one."
    );
  }

  const otp = snap.data()!;

  if (otp.used) {
    throw new HttpsError("already-exists", "This code has already been used.");
  }
  if ((otp.expiresAt as admin.firestore.Timestamp).toDate() < new Date()) {
    throw new HttpsError(
      "deadline-exceeded",
      "Code expired. Please request a new one."
    );
  }
  if (otp.code !== code) {
    throw new HttpsError("unauthenticated", "Incorrect code. Please try again.");
  }

  await snap.ref.update({ used: true });
  // Firestore user document is created client-side after this returns.

  return { success: true };
});

export const sendPasswordResetOTP = onCall(
  { secrets: [gmailEmail, gmailPassword], enforceAppCheck: false, invoker: 'public' },
  async (request) => {
    const { email } = request.data as { email: string };

    if (!email) {
      throw new HttpsError("invalid-argument", "email is required");
    }

    const normalizedEmail = email.trim().toLowerCase();
    let uid: string;
    let name = "there";

    try {
      const userRecord = await admin.auth().getUserByEmail(normalizedEmail);
      uid = userRecord.uid;
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists) {
        name = (userDoc.data()?.fullName as string | undefined) ?? "there";
      }
    } catch {
      // Don't reveal whether the email is registered
      return { success: true };
    }

    const code = generateCode();
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 15 * 60 * 1000)
    );

    await db.collection("password_reset_otps").doc(normalizedEmail).set({
      code,
      uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      used: false,
    });

    try {
      const transport = createTransport(gmailEmail.value(), gmailPassword.value());
      await transport.sendMail({
        from: `"HelpLink" <${gmailEmail.value()}>`,
        to: email,
        subject: "Reset Your HelpLink Password",
        html: passwordResetTemplate(code, name),
      });
    } catch (err) {
      throw new HttpsError(
        "unavailable",
        "Failed to send reset email. Please try again."
      );
    }

    return { success: true };
  }
);

export const checkPasswordResetCode = onCall(
  { enforceAppCheck: false, invoker: 'public' },
  async (request) => {
  const { email, code } = request.data as { email: string; code: string };

  if (!email || !code) {
    throw new HttpsError("invalid-argument", "email and code are required");
  }

  const normalizedEmail = email.trim().toLowerCase();
  const snap = await db
    .collection("password_reset_otps")
    .doc(normalizedEmail)
    .get();

  if (!snap.exists) {
    throw new HttpsError(
      "not-found",
      "No reset code found. Please request a new one."
    );
  }

  const otp = snap.data()!;

  if (otp.used) {
    throw new HttpsError(
      "already-exists",
      "This code has already been used. Please request a new one."
    );
  }
  if ((otp.expiresAt as admin.firestore.Timestamp).toDate() < new Date()) {
    throw new HttpsError(
      "deadline-exceeded",
      "Code expired. Please request a new one."
    );
  }
  if (otp.code !== code) {
    throw new HttpsError("unauthenticated", "Incorrect code. Please try again.");
  }

  return { success: true };
});

// ─── Phone Change — Email OTP ────────────────────────────────────────────────
// When a user wants to change their verified phone number they can choose to
// confirm via email instead of SMS. These two functions handle that path.

export const sendPhoneChangeOTP = onCall(
  { secrets: [gmailEmail, gmailPassword], enforceAppCheck: false, invoker: 'public' },
  async (request) => {
    const { uid, email, name } = request.data as {
      uid: string; email: string; name?: string;
    };
    if (!uid || !email) throw new HttpsError("invalid-argument", "uid and email are required");

    const code = generateCode();
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 15 * 60 * 1000));

    await db.collection("phone_change_otps").doc(uid).set({
      code, email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt, used: false,
    });

    const transport = createTransport(gmailEmail.value(), gmailPassword.value());
    await transport.sendMail({
      from: `"HelpLink" <${gmailEmail.value()}>`,
      to: email,
      subject: "HelpLink — Confirm Phone Number Change",
      html: verificationTemplate(code, name ?? "there"),
    });

    return { success: true };
  }
);

export const verifyPhoneChangeOTP = onCall(
  { enforceAppCheck: false, invoker: 'public' },
  async (request) => {
    const { uid, code } = request.data as { uid: string; code: string };
    if (!uid || !code) throw new HttpsError("invalid-argument", "uid and code are required");

    const snap = await db.collection("phone_change_otps").doc(uid).get();
    if (!snap.exists) throw new HttpsError("not-found", "No code found. Please request a new one.");

    const otp = snap.data()!;
    if (otp.used) throw new HttpsError("already-exists", "Code already used.");
    if ((otp.expiresAt as admin.firestore.Timestamp).toDate() < new Date())
      throw new HttpsError("deadline-exceeded", "Code expired. Please request a new one.");
    if (otp.code !== code) throw new HttpsError("unauthenticated", "Incorrect code.");

    await snap.ref.update({ used: true });
    return { success: true };
  }
);

// ─── Stale Request Auto-Withdrawal ──────────────────────────────────────────
// Runs every 30 minutes. For each matched/active request older than 4 hours:
//   - Re-opens the request to "pending" (beneficiary gets re-matched)
//   - Increments donor's autoWithdrawalCount and applies a progressive ban:
//       1st offence → 6h ban | 2nd → 24h ban | 3rd+ → 48h ban
//   - Sends FCM push to both donor (ban notice) and beneficiary (re-opened notice)

export const processStaleRequests = onSchedule(
  { schedule: "every 30 minutes", region: "asia-southeast1" },
  async () => {
    const cutoff = new Date(Date.now() - 4 * 60 * 60 * 1000); // 4 hours ago

    // Query by matchedAt only (avoids needing a composite index with status).
    // Filter status in memory.
    const snap = await db
      .collection("help_requests")
      .where("matchedAt", "<=", admin.firestore.Timestamp.fromDate(cutoff))
      .get();

    if (snap.empty) return;

    const staleDocs = snap.docs.filter((doc) => {
      const s = doc.data().status as string;
      return s === "matched" || s === "active";
    });

    if (staleDocs.length === 0) return;

    let withdrawn = 0;

    for (const doc of staleDocs) {
      const data = doc.data();
      const donorId = data.donorId as string | undefined;
      const title = (data.title as string | undefined) ?? "your request";
      const beneficiaryId = data.beneficiaryId as string | undefined;

      // 1. Re-open request to pending so another donor can accept it.
      await doc.ref.update({
        status: "pending",
        donorId: null,
        donorName: null,
        matchedAt: null,
        autoWithdrawnAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. Apply progressive ban to the donor.
      if (donorId) {
        const donorRef = db.collection("users").doc(donorId);

        const banHours = await db.runTransaction(async (tx) => {
          const donorSnap = await tx.get(donorRef);
          const d = donorSnap.data() ?? {};
          const newCount = ((d.autoWithdrawalCount as number) ?? 0) + 1;

          let hours: number;
          if (newCount === 1) hours = 6;
          else if (newCount === 2) hours = 24;
          else hours = 48;

          const banUntil = new Date(Date.now() + hours * 60 * 60 * 1000);
          tx.update(donorRef, {
            autoWithdrawalCount: newCount,
            banUntil: admin.firestore.Timestamp.fromDate(banUntil),
          });
          return hours;
        });

        // 3. Notify donor of withdrawal + ban.
        const donorDoc = await donorRef.get();
        const donorFcm = donorDoc.data()?.fcmToken as string | undefined;
        if (donorFcm) {
          const banText =
            banHours === 6 ? "6 hours" : banHours === 24 ? "1 day" : "2 days";
          await sendPush(
            donorFcm,
            "Request Auto-Withdrawn ⚠️",
            `You were removed from "${title}" for not completing it within 4 hours. You are banned for ${banText}.`,
            { type: "auto_withdrawal", requestId: doc.id }
          );
        }
      }

      // 4. Notify beneficiary that their request is re-opened.
      if (beneficiaryId) {
        const benDoc = await db.collection("users").doc(beneficiaryId).get();
        const benFcm = benDoc.data()?.fcmToken as string | undefined;
        if (benFcm) {
          await sendPush(
            benFcm,
            "Request Re-opened 🔄",
            `Your request "${title}" is available again — the donor did not complete it in time.`,
            { type: "request_reopened", requestId: doc.id }
          );
        }
      }

      withdrawn++;
    }

    console.log(`Auto-withdrew ${withdrawn} stale request(s).`);
  }
);

export const resetPasswordWithOTP = onCall(
  { enforceAppCheck: false, invoker: 'public' },
  async (request) => {
  const { email, code, newPassword } = request.data as {
    email: string;
    code: string;
    newPassword: string;
  };

  if (!email || !code || !newPassword) {
    throw new HttpsError(
      "invalid-argument",
      "email, code, and newPassword are required"
    );
  }
  if (newPassword.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters."
    );
  }

  const normalizedEmail = email.trim().toLowerCase();
  const snap = await db
    .collection("password_reset_otps")
    .doc(normalizedEmail)
    .get();

  if (!snap.exists) {
    throw new HttpsError(
      "not-found",
      "No reset code found. Please request a new one."
    );
  }

  const otp = snap.data()!;

  if (otp.used) {
    throw new HttpsError("already-exists", "This code has already been used.");
  }
  if ((otp.expiresAt as admin.firestore.Timestamp).toDate() < new Date()) {
    throw new HttpsError(
      "deadline-exceeded",
      "Code expired. Please request a new one."
    );
  }
  if (otp.code !== code) {
    throw new HttpsError("unauthenticated", "Incorrect code. Please try again.");
  }

  await admin.auth().updateUser(otp.uid as string, { password: newPassword });
  await snap.ref.update({ used: true });

  return { success: true };
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function sendPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  } catch (err) {
    console.error("FCM send failed:", err);
  }
}

// ─── Request cancelled → notify the other party ─────────────────────────────

export const onRequestCancelled = onDocumentUpdated(
  "help_requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "cancelled") return;

    const title        = (after.title       as string | undefined) ?? "a request";
    const cancelledBy  = (after.cancelledBy as string | undefined) ?? "";
    const beneficiaryId = after.beneficiaryId as string | undefined;
    const donorId       = after.donorId       as string | undefined;

    if (cancelledBy === "beneficiary" && donorId) {
      // Beneficiary cancelled → tell the donor
      const doc = await db.collection("users").doc(donorId).get();
      const fcm = doc.data()?.fcmToken as string | undefined;
      if (fcm) await sendPush(
        fcm,
        "Request Cancelled",
        `The beneficiary has cancelled the request "${title}".`,
        { type: "request_cancelled", requestId: event.params.requestId }
      );
    } else if (beneficiaryId) {
      // Donor or system cancelled → tell the beneficiary
      const doc = await db.collection("users").doc(beneficiaryId).get();
      const fcm = doc.data()?.fcmToken as string | undefined;
      if (fcm) {
        const byDonor = cancelledBy === "donor";
        await sendPush(
          fcm,
          "Request Cancelled",
          byDonor
            ? `Your donor has withdrawn from your request "${title}". It is now open for other donors.`
            : `Your request "${title}" has been cancelled.`,
          { type: "request_cancelled", requestId: event.params.requestId }
        );
      }
    }
  }
);

// ─── Delivery submitted → notify beneficiary to confirm ──────────────────────

export const onDeliverySubmitted = onDocumentUpdated(
  "help_requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "pendingConfirmation") return;

    const beneficiaryId = after.beneficiaryId as string | undefined;
    const title         = (after.title     as string | undefined) ?? "your request";
    const donorName     = (after.donorName as string | undefined) ?? "Your donor";

    if (!beneficiaryId) return;

    const doc = await db.collection("users").doc(beneficiaryId).get();
    const fcm = doc.data()?.fcmToken as string | undefined;
    if (!fcm) return;

    await sendPush(
      fcm,
      "Delivery Submitted 📦",
      `${donorName} has submitted delivery for "${title}". Please confirm receipt or scan the QR code.`,
      { type: "delivery_submitted", requestId: event.params.requestId }
    );
  }
);

// ─── IC verification result → notify user ────────────────────────────────────

export const onICVerificationChanged = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;

    const wasVerified  = before.isICVerified        as boolean | undefined;
    const nowVerified  = after.isICVerified         as boolean | undefined;
    const wasPending   = before.icPendingVerification as boolean | undefined;
    const nowPending   = after.icPendingVerification  as boolean | undefined;
    const fcm          = after.fcmToken as string | undefined;
    const firstName    = ((after.fullName as string | undefined) ?? "").split(" ")[0] || "there";

    if (!fcm) return;

    // ── Approved ─────────────────────────────────────────────────────────────
    if (!wasVerified && nowVerified) {
      await sendPush(
        fcm,
        "IC Verified ✓",
        `Hi ${firstName}! Your IC has been verified. You now have full access to HelpLink.`,
        { type: "ic_verified", userId: event.params.userId }
      );
      return;
    }

    // ── Rejected: was pending, no longer pending, still not verified ──────────
    if (wasPending && !nowPending && !nowVerified) {
      await sendPush(
        fcm,
        "IC Verification Unsuccessful",
        `Hi ${firstName}, your IC could not be verified. Please re-submit a clear photo of your blue Malaysian IC card.`,
        { type: "ic_rejected", userId: event.params.userId }
      );
    }
  }
);

// ─── New chat message → notify receiver ──────────────────────────────────────

export const onChatMessageCreated = onDocumentCreated(
  "help_requests/{requestId}/messages/{messageId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const receiverId = data.receiverId as string | undefined;
    const senderName = (data.senderName as string | undefined) ?? "Someone";
    const messageType = (data.messageType as string | undefined) ?? "text";
    const content = (data.content as string | undefined) ?? "";

    if (!receiverId) return;

    const body =
      messageType === "audio"
        ? `${senderName} sent you a voice message`
        : messageType === "location" || messageType === "liveLocation"
        ? `${senderName} shared their location`
        : `${senderName}: ${content.length > 80 ? content.slice(0, 77) + "…" : content}`;

    const receiverDoc = await db.collection("users").doc(receiverId).get();
    const fcmToken = receiverDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return;

    await sendPush(fcmToken, "New Message", body, {
      type: "chat_message",
      requestId: event.params.requestId,
    });
  }
);

// ─── Emergency request → notify nearby donors ─────────────────────────────────

export const onEmergencyRequestCreated = onDocumentCreated(
  "help_requests/{requestId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (!data.isEmergency || data.status !== "pending") return;

    const { latitude, longitude, title, beneficiaryName, beneficiaryId } = data;
    if (latitude == null || longitude == null) return;

    const donorsSnap = await db.collection("users")
      .where("role", "==", "donor")
      .get();

    const tokens: string[] = [];
    for (const doc of donorsSnap.docs) {
      const d = doc.data();
      if (!d.fcmToken) continue;
      if (d.uid === beneficiaryId) continue;
      if (d.latitude == null || d.longitude == null) continue;
      const dist = haversineKm(latitude, longitude, d.latitude, d.longitude);
      if (dist <= 5) tokens.push(d.fcmToken as string);
    }

    if (tokens.length === 0) return;

    const name = (beneficiaryName as string | undefined) ?? "Someone";
    const requestTitle = (title as string | undefined) ?? "Emergency";

    // FCM sendEach supports up to 500 messages per call
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500).map((token) => ({
        token,
        notification: {
          title: "🚨 Emergency Request Nearby!",
          body: `${name} urgently needs help: "${requestTitle}"`,
        },
        data: {
          type: "emergency_request",
          requestId: event.params.requestId,
        },
        android: { priority: "high" as const },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      }));
      await admin.messaging().sendEach(chunk);
    }

    console.log(`Emergency alert sent to ${tokens.length} nearby donor(s).`);
  }
);

// ─── Request matched → notify beneficiary ────────────────────────────────────

export const onRequestMatched = onDocumentUpdated(
  "help_requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Only fire when status transitions TO "matched"
    if (before.status === "matched" || after.status !== "matched") return;

    const beneficiaryId = after.beneficiaryId as string | undefined;
    const donorName = (after.donorName as string | undefined) ?? "A donor";
    const requestTitle = (after.title as string | undefined) ?? "your request";

    if (!beneficiaryId) return;

    const beneficiaryDoc = await db.collection("users").doc(beneficiaryId).get();
    const fcmToken = beneficiaryDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return;

    await sendPush(
      fcmToken,
      "Request Accepted! 🎉",
      `${donorName} has accepted your request: "${requestTitle}"`,
      {
        type: "request_accepted",
        requestId: event.params.requestId,
      }
    );

    console.log(`Acceptance notification sent to beneficiary ${beneficiaryId}.`);
  }
);
