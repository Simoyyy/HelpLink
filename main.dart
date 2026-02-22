import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/auth/login_screen.dart';
import 'package:helplink/screens/auth/signup_screen.dart';
import 'package:helplink/screens/auth/email_verification_screen.dart';
import 'package:helplink/screens/donor/donor_dashboard.dart';
import 'package:helplink/screens/beneficiary/beneficiary_dashboard.dart';
import 'package:helplink/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
          '/donor-dashboard': (context) => const DonorDashboard(),
          '/beneficiary-dashboard': (context) => const BeneficiaryDashboard(),
        },
      ),
    );
  }
}
