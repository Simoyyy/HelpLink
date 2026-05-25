import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/auth/login_screen.dart';
import 'package:helplink/screens/auth/signup_screen.dart';
import 'package:helplink/screens/auth/email_verification_screen.dart';
import 'package:helplink/screens/auth/forgot_password_screen.dart';
import 'package:helplink/screens/donor/donor_dashboard.dart';
import 'package:helplink/screens/beneficiary/beneficiary_dashboard.dart';
import 'package:helplink/screens/beneficiary/beneficiary_profile_screen.dart';
import 'package:helplink/screens/beneficiary/beneficiary_requests_screen.dart';
import 'package:helplink/screens/beneficiary/beneficiary_history_screen.dart';
import 'package:helplink/screens/donor/donor_profile_screen.dart';
import 'package:helplink/screens/donor/donor_history_screen.dart';
import 'package:helplink/screens/donor/donor_ongoing_screen.dart';
import 'package:helplink/screens/donor/set_location_screen.dart';
import 'package:helplink/screens/ic_verification_screen.dart';
import 'package:helplink/utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  runApp(const HelpLinkApp());
}

class HelpLinkApp extends StatelessWidget {
  const HelpLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        title: 'HelpLink',
        debugShowCheckedModeBanner: false,
        theme: HelpLinkTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/verify-email': (context) => const EmailVerificationScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/donor-dashboard': (context) => const DonorDashboard(),
          '/beneficiary-dashboard': (context) => const BeneficiaryDashboard(),
          '/beneficiary-profile': (context) =>
              const BeneficiaryProfileScreen(),
          '/beneficiary-requests': (context) =>
              const BeneficiaryRequestsScreen(),
          '/beneficiary-history': (context) =>
              const BeneficiaryHistoryScreen(),
          '/donor-profile': (context) => const DonorProfileScreen(),
          '/donor-history': (context) => const DonorHistoryScreen(),
          '/donor-ongoing': (context) => const DonorOngoingScreen(),
          '/donor-set-location': (context) => const SetLocationScreen(),
          '/ic-verification': (context) => const ICVerificationScreen(),
        },
        onGenerateRoute: (settings) => null,
      ),
    );
  }
}
