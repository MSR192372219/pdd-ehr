import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/firestore_helper.dart';
import 'utils/app_theme.dart';
import 'screens/login/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirestoreHelper.initialize();

  final dbDefault = FirestoreHelper.db;

  debugPrint('[FIRESTORE DEBUG] projectId = ${dbDefault.app.options.projectId}');
  debugPrint('[FIRESTORE DEBUG] databaseId = ${dbDefault.databaseId}');

  runApp(const HealthcareApp());
}

class HealthcareApp extends StatelessWidget {
  const HealthcareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ApexCare | Smart Healthcare Management',
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}