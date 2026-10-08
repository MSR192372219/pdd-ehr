import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';
import '../../utils/app_theme.dart';
import '../login/login_page.dart';
import 'doc_appointments_page.dart';
import 'doc_patients_page.dart';
import 'doc_medical_records_page.dart';
import '../../widgets/doctor_prescription_dialog.dart';

class DoctorPortal extends StatefulWidget {
  final String? doctorName;
  final String? uid;
  final String? email;
  final String? specialization;
  final String? doctorId;

  const DoctorPortal({
    super.key,
    this.doctorName,
    this.uid,
    this.email,
    this.specialization,
    this.doctorId,
  });

  @override
  State<DoctorPortal> createState() => _DoctorPortalState();
}

class _DoctorPortalState extends State<DoctorPortal> {
  bool _isLoading = true;
  String? _errorMessage;

  String _resolvedName = '';
  String _resolvedUid = '';
  String _resolvedEmail = '';
  String _resolvedSpecialization = '';
  String _resolvedDepartment = '';
  String _resolvedDoctorId = '';
  String _resolvedPhone = '';

  // Feature: On-Duty status toggle
  bool _isOnDuty = true;

  @override
  void initState() {
    super.initState();
    _resolveDoctorIdentity();
  }

  Future<void> _resolveDoctorIdentity() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No authenticated user found. Please log in.';
        });
        return;
      }

      final authUid = currentUser.uid;
      final authEmail = currentUser.email ?? widget.email ?? '';
      _resolvedUid = authUid;
      _resolvedEmail = authEmail;

      // 1. Fetch users/{AUTH_UID}
      final userDoc = await FirestoreHelper.getDoc('users', authUid);
      if (!userDoc.exists || userDoc.data() == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Doctor profile could not be found for this account.';
        });
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role']?.toString().toLowerCase().trim() ?? '';
      if (role != 'doctor') {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Account is not registered as a doctor.';
        });
        return;
      }

      // Authoritative attributes from authenticated user profile
      String doctorDocId = '';
      String name = userData['name']?.toString().trim() ?? '';
      String spec = userData['specialization']?.toString().trim() ?? '';
      String dept = userData['department']?.toString().trim() ?? '';
      String phone = userData['phone']?.toString().trim() ?? '';

      Map<String, dynamic>? doctorData;

      // 1. PRIMARY RESOLUTION: Search doctors collection by authenticated Firebase UID
      final uidMatch = await FirestoreHelper.getCollection(
        'doctors',
        whereField: 'uid',
        isEqualTo: authUid,
        limit: 1,
      );
      if (uidMatch.docs.isNotEmpty) {
        final matched = uidMatch.docs.first;
        doctorDocId = matched.id;
        doctorData = matched.data();
      }

      // 2. SECONDARY RESOLUTION: Check doctors/{authUid} directly
      if (doctorData == null) {
        final directDoc = await FirestoreHelper.getDoc('doctors', authUid);
        if (directDoc.exists && directDoc.data() != null) {
          doctorDocId = authUid;
          doctorData = directDoc.data();
        }
      }

      // 3. TERTIARY RESOLUTION: Search doctors collection by authenticated email
      if (doctorData == null && authEmail.isNotEmpty) {
        final emailMatch = await FirestoreHelper.getCollection(
          'doctors',
          whereField: 'email',
          isEqualTo: authEmail.toLowerCase(),
          limit: 1,
        );
        if (emailMatch.docs.isNotEmpty) {
          final matched = emailMatch.docs.first;
          doctorDocId = matched.id;
          doctorData = matched.data();

          // Link authenticated UID to doctor record if missing
          if (doctorData['uid'] == null || doctorData['uid'].toString().isEmpty) {
            try {
              await FirestoreHelper.db.collection('doctors').doc(doctorDocId).update({
                'uid': authUid,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }
        }
      }

      // 4. QUATERNARY CHECK: Check userData['doctorId'], but verify identity ownership
      final candidateDocId = userData['doctorId']?.toString().trim() ?? '';
      if (doctorData == null && candidateDocId.isNotEmpty) {
        final docSnapshot = await FirestoreHelper.getDoc('doctors', candidateDocId);
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final candidateData = docSnapshot.data()!;
          final candidateEmail = candidateData['email']?.toString().trim().toLowerCase() ?? '';
          final candidateUid = candidateData['uid']?.toString().trim() ?? '';

          // Only adopt if email or UID matches the authenticated doctor
          final isOwner = (candidateEmail.isNotEmpty && candidateEmail == authEmail.toLowerCase()) ||
              (candidateUid.isNotEmpty && candidateUid == authUid) ||
              (candidateEmail.isEmpty && candidateUid.isEmpty);

          if (isOwner) {
            doctorDocId = candidateDocId;
            doctorData = candidateData;
          } else {
            debugPrint('[DOCTOR_PORTAL] Rejected mismatched doctorId reference "$candidateDocId" (belongs to $candidateEmail, authenticated as $authEmail)');
          }
        }
      }

      // 5. Extract authoritative profile attributes
      if (doctorData != null) {
        final docName = doctorData['name']?.toString().trim() ?? '';
        if (docName.isNotEmpty) name = docName;

        final docSpec = doctorData['specialization']?.toString().trim() ?? '';
        if (docSpec.isNotEmpty) spec = docSpec;

        final docDept = doctorData['department']?.toString().trim() ?? '';
        if (docDept.isNotEmpty) dept = docDept;

        final docPhone = doctorData['phone']?.toString().trim() ?? '';
        if (docPhone.isNotEmpty) phone = docPhone;
      } else {
        // Fallback doctor doc ID is the authenticated UID to maintain isolation
        if (doctorDocId.isEmpty) {
          doctorDocId = authUid;
        }
      }

      // Fallback name from auth if not in records
      if (name.isEmpty) {
        name = currentUser.displayName ?? (authEmail.contains('@') ? authEmail.split('@').first : 'Doctor');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _resolvedName = name;
          _resolvedDoctorId = doctorDocId;
          _resolvedSpecialization = spec;
          _resolvedDepartment = dept;
          _resolvedPhone = phone;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading doctor profile: $e';
        });
      }
    }
  }

  String get _displayName {
    final trimmed = _resolvedName.trim();
    if (trimmed.isEmpty) return 'Doctor';
    if (trimmed.toLowerCase().startsWith('dr.') || trimmed.toLowerCase().startsWith('dr ')) {
      return trimmed;
    }
    return 'Dr. $trimmed';
  }

  Stream<int> _appointmentCount() {
    final db = FirestoreHelper.db;
    if (_resolvedDoctorId.isNotEmpty) {
      return db
          .collection('appointments')
          .where('doctorId', isEqualTo: _resolvedDoctorId)
          .snapshots()
          .map((s) => s.docs.length);
    }
    return db
        .collection('appointments')
        .where('doctorUid', isEqualTo: _resolvedUid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _patientCount() =>
      FirestoreHelper.db.collection('patients').snapshots().map((s) => s.docs.length);

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _showQuickRxDialog({String? patientId, String? patientName, String? problem}) {
    DoctorPrescriptionDialog.show(
      context,
      doctorName: _displayName,
      doctorUid: _resolvedUid,
      doctorId: _resolvedDoctorId,
      prefilledPatientId: patientId,
      prefilledPatientName: patientName,
      prefilledProblem: problem,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Portal')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.teal),
              SizedBox(height: 16),
              Text('Verifying doctor credentials & loading clinical workspace...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Doctor Portal'),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.rose),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services_rounded, color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ApexCare Physician Console',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textMain),
                ),
                Text(
                  'Clinical Workspace • Ambulatory Care',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
        actions: [
          // On-Duty Shift Toggle (Feature addition)
          Row(
            children: [
              Text(
                _isOnDuty ? 'On Duty' : 'On Break',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isOnDuty ? AppColors.emerald : AppColors.amber,
                ),
              ),
              Switch(
                value: _isOnDuty,
                activeColor: AppColors.emerald,
                onChanged: (val) {
                  setState(() {
                    _isOnDuty = val;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isOnDuty ? 'Shift status: On Duty (Accepting Triage)' : 'Shift status: In Surgery / Break'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _resolveDoctorIdentity),
          IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.rose), tooltip: 'Logout', onPressed: _logout),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Header Hero Banner
                _buildDoctorHeroBanner(),

                const SizedBox(height: 20),

                // Clinical Metrics Grid
                _buildDoctorMetrics(),

                const SizedBox(height: 24),

                // Clinical Queue & Quick Rx Section
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 850) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildTodayQueueCard()),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: _buildClinicalToolsCard()),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildTodayQueueCard(),
                          const SizedBox(height: 20),
                          _buildClinicalToolsCard(),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 28),

                // Primary Clinical Modules Navigation
                const Text(
                  'Clinical Practice Modules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
                ),
                const SizedBox(height: 12),
                _buildPracticeModules(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: AppGradients.headerDoctor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome, $_displayName 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isOnDuty ? '🟢 On Shift' : '🟡 Inactive',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    _resolvedSpecialization.isNotEmpty ? _resolvedSpecialization : 'General Medicine',
                    _resolvedDepartment.isNotEmpty ? _resolvedDepartment : 'Outpatient Department',
                    _resolvedEmail,
                    if (_resolvedPhone.isNotEmpty) _resolvedPhone,
                  ].join(' • '),
                  style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int cols = constraints.maxWidth >= 750 ? 3 : 1;
        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: constraints.maxWidth >= 750 ? 2.2 : 2.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _docStatItem(
              stream: _appointmentCount(),
              title: 'Scheduled Consultations',
              trend: 'Today & Upcoming',
              icon: Icons.calendar_month_rounded,
              color: AppColors.teal,
              onTap: () => _openAppointments(),
            ),
            _docStatItem(
              stream: _patientCount(),
              title: 'Patients in Hospital Registry',
              trend: 'All Wards Active',
              icon: Icons.people_alt_rounded,
              color: AppColors.primary,
              onTap: () => _openPatients(),
            ),
            _staticDocStatItem(
              title: 'Electronic Prescriptions',
              value: '18 Issued',
              sub: 'Zero dispensary errors',
              icon: Icons.medication_rounded,
              color: AppColors.indigo,
              onTap: _showQuickRxDialog,
            ),
          ],
        );
      },
    );
  }

  Widget _docStatItem({
    required Stream<int> stream,
    required String title,
    required String trend,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final val = snapshot.data ?? 0;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$val', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textMain)),
                      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      Text(trend, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _staticDocStatItem({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain)),
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayQueueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.queue_rounded, color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Clinical Queue & Next Patient',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('2 in Lobby', style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Text('SJ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sarah Jenkins (Female, 34)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                      SizedBox(height: 2),
                      Text('Routine Cardiology Followup • 10:30 AM Slot', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling patient to Consultation Room 4.')),
                    );
                  },
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text('Call In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalToolsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Physician Fast Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
          ),
          const SizedBox(height: 12),
          _toolRowItem(Icons.edit_note_rounded, 'Issue E-Prescription', 'Send directly to pharmacy', AppColors.teal, _showQuickRxDialog),
          const SizedBox(height: 8),
          _toolRowItem(Icons.video_call_rounded, 'Start Telehealth Room', 'Launch secure HIPAA video consultation', AppColors.primary, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Telehealth video consultation room initialized.')),
            );
          }),
        ],
      ),
    );
  }

  Widget _toolRowItem(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                  Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeModules() {
    return Column(
      children: [
        _moduleTile(
          icon: Icons.calendar_month_rounded,
          title: 'My Clinical Schedule & Appointments',
          subtitle: 'Review booking queues, approve time slots, and mark completed',
          color: AppColors.teal,
          onTap: () => _openAppointments(),
        ),
        _moduleTile(
          icon: Icons.people_alt_rounded,
          title: 'My Assigned Patients Directory',
          subtitle: 'Access patient medical histories, clinical charts, and allergies',
          color: AppColors.primary,
          onTap: () => _openPatients(),
        ),
        _moduleTile(
          icon: Icons.description_rounded,
          title: 'Medical Records, Labs & Prescriptions',
          subtitle: 'Create diagnostic test requests, review labs, and update SOAP notes',
          color: AppColors.indigo,
          onTap: () => _openRecords(),
        ),
      ],
    );
  }

  Widget _moduleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textMain)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
        onTap: onTap,
      ),
    );
  }

  void _openAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocAppointmentsPage(
          doctorId: _resolvedDoctorId,
          doctorUid: _resolvedUid,
          doctorName: _resolvedName,
        ),
      ),
    );
  }

  void _openPatients() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocPatientsPage(
          doctorId: _resolvedDoctorId,
          doctorUid: _resolvedUid,
          doctorName: _resolvedName,
        ),
      ),
    );
  }

  void _openRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocMedicalRecordsPage(
          doctorId: _resolvedDoctorId,
          doctorUid: _resolvedUid,
          doctorName: _resolvedName,
        ),
      ),
    );
  }
}
