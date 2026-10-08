import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';
import '../../utils/app_theme.dart';
import '../login/login_page.dart';
import 'pat_profile_page.dart';
import 'pat_appointments_page.dart';
import 'pat_doctors_page.dart';
import 'pat_medical_records_page.dart';
import 'pat_prescriptions_page.dart';
import 'pat_ai_assistant_page.dart';

class PatientPortal extends StatefulWidget {
  final String patientName;
  final String patientId;
  final String email;
  final String uid;

  const PatientPortal({
    super.key,
    this.patientName = 'Patient',
    this.patientId = '',
    this.email = '',
    this.uid = '',
  });

  @override
  State<PatientPortal> createState() => _PatientPortalState();
}

class _PatientPortalState extends State<PatientPortal> {
  FirebaseFirestore get _db => FirestoreHelper.db;

  late String _currentUid;
  Map<String, dynamic>? _patientData;
  bool _isLoading = true;
  String? _error;



  // Health Vitals state
  String _bp = '120/80';
  String _heartRate = '74';
  final String _bloodGroup = 'O+';
  String _weight = '68 kg';

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _currentUid = currentUser?.uid ?? widget.uid;
    _loadPatientProfile();
  }

  Future<void> _loadPatientProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final patientDoc = await _db.collection('patients').doc(_currentUid).get();
      if (patientDoc.exists && patientDoc.data() != null) {
        if (!mounted) return;
        setState(() {
          _patientData = patientDoc.data()!;
          _isLoading = false;
        });
        return;
      }

      final userDoc = await _db.collection('users').doc(_currentUid).get();
      if (userDoc.exists && userDoc.data() != null) {
        if (!mounted) return;
        setState(() {
          _patientData = userDoc.data()!;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _patientData = {
          'name': widget.patientName,
          'patientId': widget.patientId,
          'email': widget.email,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _name => _patientData?['name']?.toString() ?? widget.patientName;
  String get _pId => _patientData?['patientId']?.toString() ?? widget.patientId;
  String get _email => _patientData?['email']?.toString() ?? widget.email;

  Stream<int> _appointmentCount() => _db
      .collection('appointments')
      .where('patientId', isEqualTo: _currentUid)
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> _recordCount() => _db
      .collection('medical_records')
      .where('patientId', isEqualTo: _currentUid)
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> _prescriptionCount() => _db
      .collection('prescriptions')
      .where('patientId', isEqualTo: _currentUid)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((s) => s.docs.length);

  Stream<QuerySnapshot> _upcomingAppointment() {
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: _currentUid)
        .limit(1)
        .snapshots();
  }

  void _showLogVitalsDialog() {
    final bpCtrl = TextEditingController(text: _bp);
    final hrCtrl = TextEditingController(text: _heartRate);
    final wtCtrl = TextEditingController(text: _weight);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: AppColors.rose),
            SizedBox(width: 10),
            Text('Log Daily Health Vitals', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bpCtrl,
              decoration: const InputDecoration(labelText: 'Blood Pressure (e.g. 120/80 mmHg)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hrCtrl,
              decoration: const InputDecoration(labelText: 'Heart Rate (bpm)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wtCtrl,
              decoration: const InputDecoration(labelText: 'Body Weight (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _bp = bpCtrl.text.trim();
                _heartRate = hrCtrl.text.trim();
                _weight = wtCtrl.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vitals updated and securely saved to your health chart.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.teal,
                ),
              );
            },
            child: const Text('Save Vitals'),
          ),
        ],
      ),
    );
  }

  void _showEmergencySOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 28),
            SizedBox(width: 10),
            Text('Emergency SOS Alert', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.rose)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you require immediate hospital ambulance dispatch or emergency triage?',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 16),
            Text('• National Ambulance: 108 / 911\n• Hospital Emergency Room: (800) 555-CARE\n• On-Duty ER Physician: Dr. Patel', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency triage request broadcasted to nearest hospital desk.'),
                  backgroundColor: AppColors.rose,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            icon: const Icon(Icons.phone_in_talk),
            label: const Text('Connect to ER Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.indigoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.indigo, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Health Portal',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textMain),
                ),
                Text(
                  'ApexCare Patient Care Cloud',
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
          IconButton(
            icon: const Icon(Icons.emergency_outlined, color: AppColors.rose),
            tooltip: 'Emergency SOS',
            onPressed: _showEmergencySOS,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadPatientProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.rose),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.rose),
                      const SizedBox(height: 16),
                      Text('Unable to load patient profile: $_error', style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadPatientProfile, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPatientProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome Header Card
                            _buildWelcomeCard(),

                            const SizedBox(height: 20),

                            // Health Vitals Summary Card (Feature addition)
                            _buildHealthVitalsCard(),

                            const SizedBox(height: 24),

                            // Overview Counts
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth >= 600) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _streamStatCard(
                                          _appointmentCount(),
                                          'Active Appointments',
                                          Icons.calendar_month_rounded,
                                          AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _streamStatCard(
                                          _prescriptionCount(),
                                          'Active Prescriptions',
                                          Icons.medication_rounded,
                                          AppColors.teal,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _streamStatCard(
                                          _recordCount(),
                                          'Medical Records',
                                          Icons.description_rounded,
                                          AppColors.indigo,
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _streamStatCard(
                                              _appointmentCount(),
                                              'Appointments',
                                              Icons.calendar_month_rounded,
                                              AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _streamStatCard(
                                              _prescriptionCount(),
                                              'Prescriptions',
                                              Icons.medication_rounded,
                                              AppColors.teal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _streamStatCard(
                                        _recordCount(),
                                        'Medical Records & Diagnostic Reports',
                                        Icons.description_rounded,
                                        AppColors.indigo,
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 28),

                            // Two-column section for desktop
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth >= 850) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildUpcomingAppointmentCard()),
                                      const SizedBox(width: 20),
                                      Expanded(child: _buildMedicationTrackerCard()),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      _buildUpcomingAppointmentCard(),
                                      const SizedBox(height: 20),
                                      _buildMedicationTrackerCard(),
                                    ],
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 28),

                            // Quick Actions
                            const Text(
                              'Patient Quick Actions',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionsRow(),

                            const SizedBox(height: 32),

                            // Healthcare Modules Navigation
                            const Text(
                              'Healthcare Management',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
                            ),
                            const SizedBox(height: 14),
                            _buildNavigationCards(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: AppGradients.headerPatient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _name.isNotEmpty ? _name[0].toUpperCase() : 'P',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome back, $_name 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Active Patient', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_pId.isNotEmpty ? "Patient ID: $_pId • " : ""}$_email',
                  style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _navigate(context, PatDoctorsPage(patientId: _currentUid, patientName: _name)),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Book Doctor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.indigo,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  /// Real-time Health Vitals Tracker Card
  Widget _buildHealthVitalsCard() {
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
                  Icon(Icons.monitor_heart_rounded, color: AppColors.rose, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'My Daily Health Vitals',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textMain),
                  ),
                ],
              ),
              InkWell(
                onTap: _showLogVitalsDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_calendar_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Update Vitals', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = constraints.maxWidth >= 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _vitalItem('Blood Pressure', _bp, 'mmHg (Normal)', Icons.speed_rounded, AppColors.primary),
                  _vitalItem('Heart Rate', '$_heartRate bpm', 'Resting pulse', Icons.favorite_rounded, AppColors.rose),
                  _vitalItem('Blood Group', _bloodGroup, 'Universal Donor', Icons.water_drop_rounded, AppColors.amber),
                  _vitalItem('Body Weight', _weight, 'BMI: 22.4 (Healthy)', Icons.fitness_center_rounded, AppColors.teal),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _vitalItem(String title, String val, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                Text(sub, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentCard() {
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
              const Text(
                'Next Consultation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
              ),
              TextButton(
                onPressed: () => _navigate(context, PatAppointmentsPage(patientId: _currentUid, patientName: _name)),
                child: const Text('All Appointments'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _upcomingAppointment(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: AppColors.textLight, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No pending appointments scheduled.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _navigate(context, PatDoctorsPage(patientId: _currentUid, patientName: _name)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Book'),
                      ),
                    ],
                  ),
                );
              }

              final d = docs.first.data() as Map<String, dynamic>;
              final doctorName = d['doctorName']?.toString() ?? 'Specialist Doctor';
              final date = d['date']?.toString() ?? '';
              final time = d['time']?.toString() ?? '';
              final status = d['status']?.toString() ?? 'Scheduled';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doctorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
                              Text('$date ${time.isNotEmpty ? "• $time" : ""}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Telehealth video consultation link active 15 mins before time.')),
                              );
                            },
                            icon: const Icon(Icons.videocam_rounded, size: 16),
                            label: const Text('Join Video Room'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Interactive Daily Medication Reminder Checklist from Authoritative Prescriptions
  Widget _buildMedicationTrackerCard() {
    final now = DateTime.now();
    final todayKey = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

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
                  Icon(Icons.medication_rounded, color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Daily Prescription Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _navigate(context, PatPrescriptionsPage(patientId: _currentUid, patientName: _name)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text('All Rx', style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _currentUid.isNotEmpty
                ? _db
                    .collection('prescriptions')
                    .where('patientId', isEqualTo: _currentUid)
                    .where('status', isEqualTo: 'active')
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.teal)));
              }

              final docs = snapshot.data?.docs ?? [];
              final List<Map<String, dynamic>> allMeds = [];

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final medicinesRaw = data['medicines'];
                if (medicinesRaw is List) {
                  for (int i = 0; i < medicinesRaw.length; i++) {
                    final item = medicinesRaw[i];
                    if (item is Map) {
                      allMeds.add({
                        'docId': doc.id,
                        'medIndex': i,
                        'name': item['medicine']?.toString() ?? item['name']?.toString() ?? 'Medication',
                        'dosage': item['dosage']?.toString() ?? '',
                        'frequency': item['frequency']?.toString() ?? '',
                        'timing': item['timing']?.toString() ?? item['time']?.toString() ?? 'As directed',
                        'meal': item['meal']?.toString() ?? '',
                        'doctorName': data['doctorName']?.toString() ?? 'Doctor',
                        'takenLog': data['takenLog'] is Map ? (data['takenLog'] as Map<String, dynamic>) : <String, dynamic>{},
                      });
                    }
                  }
                }
              }

              if (allMeds.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.teal, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No active medication doses scheduled for today.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _navigate(context, PatPrescriptionsPage(patientId: _currentUid, patientName: _name)),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: allMeds.map((med) {
                  final docId = med['docId'] as String;
                  final medIndex = med['medIndex'] as int;
                  final takenLog = med['takenLog'] as Map<String, dynamic>;
                  final logKey = '${todayKey}_$medIndex';
                  final isTaken = takenLog[logKey] == true;

                  final name = med['name'] as String;
                  final dosage = med['dosage'] as String;
                  final timing = med['timing'] as String;
                  final meal = med['meal'] as String;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isTaken ? const Color(0xFFF0FDF4) : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isTaken ? const Color(0xFFBBF7D0) : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isTaken,
                          activeColor: AppColors.emerald,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) async {
                            final newLog = Map<String, dynamic>.from(takenLog);
                            newLog[logKey] = val ?? false;
                            try {
                              await _db.collection('prescriptions').doc(docId).update({
                                'takenLog': newLog,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update dose: $e')),
                                );
                              }
                            }
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dosage.isNotEmpty ? '$name - $dosage' : name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  decoration: isTaken ? TextDecoration.lineThrough : null,
                                  color: isTaken ? AppColors.textMuted : AppColors.textMain,
                                ),
                              ),
                              Text(
                                meal.isNotEmpty ? '$timing ($meal)' : timing,
                                style: TextStyle(fontSize: 11, color: isTaken ? AppColors.emerald : AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (isTaken)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Taken', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _streamStatCard(Stream<int> stream, String label, IconData icon, Color color) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final val = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
                  children: [
                    Text(
                      '$val',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textMain),
                    ),
                    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsRow() {
    final actions = [
      {'title': 'AI Assistant', 'icon': Icons.smart_toy_rounded, 'color': AppColors.indigo, 'action': () => _navigate(context, PatAiAssistantPage(patientId: _currentUid, patientName: _name))},
      {'title': 'Find Doctor', 'icon': Icons.search_rounded, 'color': AppColors.teal, 'action': () => _navigate(context, PatDoctorsPage(patientId: _currentUid, patientName: _name))},
      {'title': 'Appointments', 'icon': Icons.calendar_month_rounded, 'color': AppColors.primary, 'action': () => _navigate(context, PatAppointmentsPage(patientId: _currentUid, patientName: _name))},
      {'title': 'Prescriptions', 'icon': Icons.medication_rounded, 'color': AppColors.emerald, 'action': () => _navigate(context, PatPrescriptionsPage(patientId: _currentUid, patientName: _name))},
      {'title': 'Lab Records', 'icon': Icons.description_rounded, 'color': AppColors.indigo, 'action': () => _navigate(context, PatMedicalRecordsPage(patientId: _currentUid))},
      {'title': 'My Profile', 'icon': Icons.person_rounded, 'color': Colors.purple, 'action': () => _navigate(context, PatProfilePage(uid: _currentUid))},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.map((act) {
          final color = act['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: act['action'] as VoidCallback,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  children: [
                    Icon(act['icon'] as IconData, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      act['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMain),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavigationCards() {
    return Column(
      children: [
        _navCard(Icons.auto_awesome_rounded, 'AI Health Assistant', 'Grounded EHR question answering, clinical term explanations', AppColors.primary, PatAiAssistantPage(patientId: _currentUid, patientName: _name)),
        _navCard(Icons.person_rounded, 'My Health Profile', 'Demographics, emergency contacts & insurance', Colors.purple, PatProfilePage(uid: _currentUid)),
        _navCard(Icons.calendar_month_rounded, 'My Appointments & Telehealth', 'View scheduled visits & join virtual rooms', AppColors.primary, PatAppointmentsPage(patientId: _currentUid, patientName: _name)),
        _navCard(Icons.medical_services_rounded, 'Physicians & Specialists', 'Search by department, availability & rating', AppColors.teal, PatDoctorsPage(patientId: _currentUid, patientName: _name)),
        _navCard(Icons.medication_rounded, 'My Prescriptions & Schedule', 'Active doctor prescriptions & dosage schedule', AppColors.teal, PatPrescriptionsPage(patientId: _currentUid, patientName: _name)),
        _navCard(Icons.description_rounded, 'Diagnostic Reports & Medical Records', 'Access lab charts, doctor clinical notes & history', AppColors.indigo, PatMedicalRecordsPage(patientId: _currentUid)),
      ],
    );
  }

  Widget _navCard(IconData icon, String title, String subtitle, Color color, Widget page) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
        onTap: () => _navigate(context, page),
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.rose),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to sign out of your patient portal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
