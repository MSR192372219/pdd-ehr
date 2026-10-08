import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../utils/firestore_helper.dart';
import '../../utils/app_theme.dart';
import '../admin/admin_dashboard.dart';
import '../doctor/doctor_portal.dart';
import '../patient/patient_portal.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool _isLoading = false;

  String selectedRole = 'Admin';

  Future<void> login() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final roleSelected = selectedRole.toLowerCase();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both your email address and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // STEP 1: AUTHENTICATE WITH FIREBASE AUTHENTICATION
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Authentication failed: current user is null.',
        );
      }

      final uid = user.uid;
      final authEmail = user.email ?? email;
      final projectId = Firebase.app().options.projectId;

      debugPrint('[LOGIN] Firebase project ID: $projectId');
      debugPrint('[LOGIN] Authenticated email: $authEmail');
      debugPrint('[LOGIN] Authenticated UID: $uid');
      debugPrint('[LOGIN] Selected role: $roleSelected');

      // STEP 2: FIRESTORE PROFILE LOOKUP (users/{UID})
      DocumentSnapshot<Map<String, dynamic>> doc;

      try {
        doc = await FirestoreHelper.getDoc('users', uid);
      } catch (e) {
        debugPrint('[LOGIN] Firestore Exception: $e');

        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        String code = 'unknown';
        String msg = e.toString();
        if (e is FirebaseException) {
          code = e.code;
          msg = e.message ?? 'Failed to read user profile';
        }

        _showError('Firestore Error [$code]: $msg');
        return;
      }

      if (!doc.exists || doc.data() == null) {
        debugPrint('[LOGIN] Profile users/$uid not found.');
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        _showError('Account profile not found for $authEmail. Please contact administrator.');
        return;
      }

      final userData = doc.data()!;
      final firestoreRole = userData['role']?.toString().toLowerCase().trim() ?? '';
      final status = userData['status']?.toString().toLowerCase().trim() ?? '';

      debugPrint('[LOGIN] Retrieved role: $firestoreRole');
      debugPrint('[LOGIN] Retrieved status: $status');

      // STEP 3: ROLE VERIFICATION
      if (firestoreRole != roleSelected) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        String registeredRoleDisplay;
        switch (firestoreRole) {
          case 'admin':
            registeredRoleDisplay = 'Admin';
            break;
          case 'doctor':
            registeredRoleDisplay = 'Doctor';
            break;
          case 'patient':
            registeredRoleDisplay = 'Patient';
            break;
          default:
            registeredRoleDisplay = firestoreRole.isNotEmpty
                ? '${firestoreRole[0].toUpperCase()}${firestoreRole.substring(1)}'
                : 'another role';
        }

        _showError('This account is registered as $registeredRoleDisplay. Switch role tab above.');
        return;
      }

      // STEP 4: STATUS VERIFICATION
      if (status != 'active') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        _showError('Your account is currently disabled or pending review.');
        return;
      }

      // STEP 5: NAVIGATION
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      Widget destination;

      switch (roleSelected) {
        case 'admin':
          destination = AdminDashboard(
            adminName: userData['name']?.toString() ?? 'Admin',
          );
          break;

        case 'doctor':
          destination = DoctorPortal(
            doctorName: userData['name']?.toString() ?? 'Doctor',
            uid: uid,
            email: userData['email']?.toString() ?? authEmail,
            specialization: userData['specialization']?.toString() ?? '',
            doctorId: userData['doctorId']?.toString() ?? '',
          );
          break;

        case 'patient':
          destination = PatientPortal(
            patientName: userData['name']?.toString() ?? 'Patient',
            patientId: userData['patientId']?.toString() ?? '',
            email: userData['email']?.toString() ?? authEmail,
            uid: uid,
          );
          break;

        default:
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showError('Invalid role.');
          return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => destination,
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[LOGIN] FirebaseAuthException code: ${e.code}');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      String message;
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Invalid email or password. Please verify credentials.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again in a few moments.';
          break;
        case 'network-request-failed':
          message = 'Network connection failed. Check your internet.';
          break;
        default:
          message = e.message ?? 'Authentication error [${e.code}]';
      }

      _showError(message);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showError('Firestore Error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.roseLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emergency, color: AppColors.rose),
            ),
            const SizedBox(width: 12),
            const Text('Emergency Hotlines', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Immediate 24/7 hospital emergency triage & ambulance dispatch:',
              style: TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
            const SizedBox(height: 16),
            _hotlineItem(Icons.local_hospital, 'National Emergency Services', '108 / 112 / 911'),
            const SizedBox(height: 10),
            _hotlineItem(Icons.phone_in_talk, 'ApexCare Hospital ER Desk', '+1 (800) 555-CARE'),
            const SizedBox(height: 10),
            _hotlineItem(Icons.medical_services, 'Poison Control Hotline', '+1 (800) 222-1222'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _hotlineItem(IconData icon, String title, String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text(number, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 880;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1100),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.floating,
                border: Border.all(color: AppColors.border.withOpacity(0.8), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: isDesktop
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _buildBrandingHero()),
                          Expanded(flex: 6, child: _buildLoginForm()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildMobileHeader(),
                        _buildLoginForm(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Modern Medical Hero Showcase
  Widget _buildBrandingHero() {
    return Container(
      padding: const EdgeInsets.all(44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF0369A1), // Sky 700
            Color(0xFF0D9488), // Teal 600
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399), // Emerald
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ApexCare Core 2.0 • Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Hospital Logo Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'ApexCare',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Next-Generation Clinical & Hospital Management Platform',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 36),

              // Feature Highlights
              _heroFeature(
                Icons.medical_information_outlined,
                'Centralized Health Records',
                'Fast, interoperable electronic patient charts with audit logs.',
              ),
              const SizedBox(height: 18),
              _heroFeature(
                Icons.calendar_today_rounded,
                'Smart Doctor Scheduling',
                'Automated triage, multi-specialty queues & real-time slot booking.',
              ),
              const SizedBox(height: 18),
              _heroFeature(
                Icons.shield_outlined,
                'HIPAA & HL7 Encrypted',
                'Bank-grade authentication with strict role-based access control.',
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Emergency Hotline Button
          InkWell(
            onTap: _showEmergencyDialog,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '24/7 Emergency Dispatch',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Click to view emergency contacts',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFeature(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        gradient: AppGradients.headerAdmin,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'ApexCare Health',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Smart Healthcare Management Portal',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Interactive Login Form
  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portal Sign In',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select your clinical or patient role to continue',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Emergency Contacts',
                onPressed: _showEmergencyDialog,
                icon: const Icon(Icons.emergency_outlined, color: AppColors.rose),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Role Selector Tabs with Modern Pills
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _roleTabItem('Admin', Icons.admin_panel_settings_rounded, AppColors.primary),
                _roleTabItem('Doctor', Icons.medical_services_rounded, AppColors.teal),
                _roleTabItem('Patient', Icons.person_rounded, AppColors.indigo),
              ],
            ),
          ),


          const SizedBox(height: 24),

          // Email Input
          const Text(
            'Work Email / ID',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBody),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'name@hospital.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 18),

          // Password Input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBody),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please contact your hospital system administrator for credentials.'),
                    ),
                  );
                },
                child: const Text(
                  'Forgot?',
                  style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            obscureText: hidePassword,
            style: const TextStyle(fontSize: 14),
            onSubmitted: (_) => _isLoading ? null : login(),
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    hidePassword = !hidePassword;
                  });
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 28),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIGN IN AS ${selectedRole.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Trust badge footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  'End-to-End Encrypted Session • TLS 1.3',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleTabItem(String role, IconData icon, Color activeColor) {
    final isSelected = selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedRole = role;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                role,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.textMain : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}