export type UserRole = "donor" | "beneficiary";

export interface AppUser {
  uid: string;
  fullName: string;
  email: string;
  role: UserRole;
  isEmailVerified: boolean;
  createdAt: Date;
  profileImageUrl?: string;
  location?: string;
  latitude?: number;
  longitude?: number;
  icNumber?: string;
  phoneNumber?: string;
  isICVerified: boolean;
  icVerifiedAt?: Date;
  icPendingVerification: boolean;
  isPhoneVerified: boolean;
  cancellationStrikes: number;
  strikeWindowStart?: Date;
  banUntil?: Date;
  autoWithdrawalCount: number;
  authDeleted: boolean;
  duplicateEmail: boolean;
}

export type RequestStatus =
  | "pending"
  | "matched"
  | "active"
  | "pendingConfirmation"
  | "completed"
  | "cancelled";

export type RequestCategory =
  | "food"
  | "medical"
  | "education"
  | "transportation"
  | "housing"
  | "other";

export interface HelpRequest {
  id: string;
  beneficiaryId: string;
  beneficiaryName: string;
  title: string;
  description: string;
  category: RequestCategory;
  status: RequestStatus;
  isAnonymous: boolean;
  location?: string;
  latitude?: number;
  longitude?: number;
  donorId?: string;
  donorName?: string;
  createdAt: Date;
  matchedAt?: Date;
  completedAt?: Date;
  isEmergency: boolean;
  donorFeedbackGiven: boolean;
  beneficiaryFeedbackGiven: boolean;
  cancellationReason?: string;
  cancelledBy?: string;
  autoWithdrawnAt?: Date;
  completionToken?: string;
  completionPhotoUrl?: string;
  completionMethod?: string;
  deliveredAt?: Date;
}

export type ReportType = "app" | "request";

export type ReportStatus = "pending" | "reviewed" | "resolved" | "dismissed";

export interface Report {
  id: string;
  reporterId: string;
  reporterRole: string;
  type: ReportType;
  targetId?: string;
  category: string;
  description: string;
  photoUrl?: string;
  status: ReportStatus;
  createdAt: Date;
}
