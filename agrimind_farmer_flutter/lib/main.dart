import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/farmer_chat_screen.dart';
import 'screens/missing_data_form_screen.dart';

void main() {
  runApp(const AgriMindFarmerApp());
}

class AgriMindFarmerApp extends StatelessWidget {
  const AgriMindFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMind – Farmer Portal',
      debugShowCheckedModeBanner: false,
      theme: AgriTheme.dark,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        // Check if route is /form?token=...
        if (uri.path == '/form' || uri.queryParameters.containsKey('token')) {
          final token = uri.queryParameters['token'] ?? '';
          return MaterialPageRoute(
            builder: (ctx) => MissingDataFormScreen(token: token),
            settings: settings,
          );
        }

        // Default to Farmer Chat
        return MaterialPageRoute(
          builder: (ctx) => const FarmerChatScreen(),
          settings: settings,
        );
      },
    );
  }
}
