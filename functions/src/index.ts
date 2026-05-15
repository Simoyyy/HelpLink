import { onCall, HttpsError } from "firebase-functions/v2/https";
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
  { secrets: [gmailEmail, gmailPassword] },
  async (request) => {
    const { uid, email, name } = request.data as {
      uid: string;
      email: string;
      name?: string;
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

    try {
      const transport = createTransport(gmailEmail.value(), gmailPassword.value());
      await transport.sendMail({
        from: `"HelpLink" <${gmailEmail.value()}>`,
        to: email,
        subject: "Verify Your HelpLink Email",
        html: verificationTemplate(code, name ?? "there"),
      });
    } catch (err) {
      throw new HttpsError(
        "unavailable",
        "Failed to send verification email. Please try again."
      );
    }

    return { success: true };
  }
);

export const verifyEmailOTP = onCall(async (request) => {
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
  await db.collection("users").doc(uid).update({ isEmailVerified: true });

  return { success: true };
});

export const sendPasswordResetOTP = onCall(
  { secrets: [gmailEmail, gmailPassword] },
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

export const checkPasswordResetCode = onCall(async (request) => {
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

export const resetPasswordWithOTP = onCall(async (request) => {
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
