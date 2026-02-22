import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/screens/auth/login_screen.dart';
import 'package:helplink/screens/donor/donor_dashboard.dart';
import 'package:helplink/screens/beneficiary/beneficiary_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder(
            future: authService.fetchUserData(),
            builder: (context, _) {
              final userModel = authService.userModel;

              if (userModel == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userModel.role == UserRole.donor) {
                return const DonorDashboard();
              } else {
                return const BeneficiaryDashboard();
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
