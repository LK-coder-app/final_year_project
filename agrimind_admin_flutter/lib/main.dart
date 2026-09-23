import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/admin_dashboard_screen.dart';

void main() {
  runApp(const AgriMindAdminApp());
}

class AgriMindAdminApp extends StatelessWidget {
  const AgriMindAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMind – Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark,
      home: const AdminDashboardScreen(),
    );
  }
}
