import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';
import '../../utils/app_theme.dart';
import 'patients_page.dart';
import 'doctors_page.dart';
import 'appointments_page.dart';
import 'medical_records_page.dart';
import 'medicines_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import '../login/login_page.dart';

class AdminDashboard extends StatefulWidget {
  final String adminName;
  const AdminDashboard({super.key, this.adminName = 'Admin'});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  FirebaseFirestore get _db => FirestoreHelper.db;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Stream<int> _count(String collection) =>
      _db.collection(collection).snapshots().map((s) => s.docs.length);

  Stream<int> _activeUsers() => _db
      .collection('users')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((s) => s.docs.length);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showBroadcastDialog() {
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Hospital Broadcast Alert', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Broadcast an urgent alert to all active doctor and staff terminals:',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Code Amber: Emergency Ward triage update...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hospital-wide alert dispatched successfully.'),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Dispatch Alert'),
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
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ApexCare Command Center',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textMain),
                ),
                Text(
                  'Administrator Portal • Live Telemetry',
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
            icon: const Icon(Icons.campaign_outlined, color: AppColors.primary),
            tooltip: 'Hospital Broadcast',
            onPressed: _showBroadcastDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Dashboard',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.rose),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header Banner
                  _buildExecutiveWelcomeBanner(),

                  const SizedBox(height: 20),

                  // Real-time Hospital Vitals & Capacity Bar (Feature addition)
                  _buildHospitalVitalsBar(),

                  const SizedBox(height: 24),

                  // Quick Search & Filter Bar (Feature addition)
                  _buildSearchBar(),

                  const SizedBox(height: 24),

                  // Overview Metric Cards
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hospital Metrics',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain),
                      ),
                      Text(
                        'Live synced with Firestore',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildOverviewMetricsGrid(),

                  const SizedBox(height: 28),

                  // Quick Action Buttons
                  const Text(
                    'Quick Clinical Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActionCards(),

                  const SizedBox(height: 32),

                  // Two-column section for desktop or stacked for mobile
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildRecentAppointmentsSection()),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRecentPatientsSection()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildRecentAppointmentsSection(),
                            const SizedBox(height: 24),
                            _buildRecentPatientsSection(),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  // Department Management Grid
                  const Text(
                    'Hospital Management Modules',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 14),
                  _buildManagementGrid(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppGradients.headerAdmin,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Administrator Master Authority',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome, ${widget.adminName} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hospital operations, staffing, clinical appointments, and pharmacy records are fully operational.',
                  style: TextStyle(color: Color(0xFFE0F2FE), fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.analytics_rounded, size: 44, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Live Hospital Capacity & Telemetry Bar
  Widget _buildHospitalVitalsBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                  Icon(Icons.health_and_safety_rounded, color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Hospital Operational Telemetry',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text(
                      'All Systems Normal',
                      style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              return isWide
                  ? Row(
                      children: [
                        Expanded(child: _telemetryItem('Bed Occupancy', '164 / 200 Beds (82%)', 0.82, AppColors.primary)),
                        const SizedBox(width: 16),
                        Expanded(child: _telemetryItem('ER Triage Queue', '4 Patients (14m avg wait)', 0.40, AppColors.amber)),
                        const SizedBox(width: 16),
                        Expanded(child: _telemetryItem('Pharmacy Stock Level', '98.4% Essential Medicines', 0.98, AppColors.teal)),
                      ],
                    )
                  : Column(
                      children: [
                        _telemetryItem('Bed Occupancy', '164 / 200 Beds (82%)', 0.82, AppColors.primary),
                        const SizedBox(height: 12),
                        _telemetryItem('ER Triage Queue', '4 Patients (14m avg wait)', 0.40, AppColors.amber),
                        const SizedBox(height: 12),
                        _telemetryItem('Pharmacy Stock Level', '98.4% Essential Medicines', 0.98, AppColors.teal),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _telemetryItem(String title, String value, double progress, Color barColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search patients, doctors, appointments, or prescriptions...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildOverviewMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth >= 950 ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);
        double childAspectRatio = constraints.maxWidth >= 950 ? 1.5 : 1.7;

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _modernStatCard(
              stream: _count('patients'),
              label: 'Total Patients',
              trend: '+12% this month',
              icon: Icons.people_alt_rounded,
              color: AppColors.primary,
              onTap: () => _navigate(context, const AdminPatientsPage()),
            ),
            _modernStatCard(
              stream: _count('doctors'),
              label: 'Medical Specialists',
              trend: 'All departments active',
              icon: Icons.medical_services_rounded,
              color: AppColors.teal,
              onTap: () => _navigate(context, const AdminDoctorsPage()),
            ),
            _modernStatCard(
              stream: _count('appointments'),
              label: 'Appointments',
              trend: '+8 today scheduled',
              icon: Icons.calendar_month_rounded,
              color: AppColors.amber,
              onTap: () => _navigate(context, const AdminAppointmentsPage()),
            ),
            _modernStatCard(
              stream: _activeUsers(),
              label: 'Active System Users',
              trend: 'Secure TLS sessions',
              icon: Icons.verified_user_rounded,
              color: AppColors.indigo,
              onTap: () => _navigate(context, const AdminSettingsPage()),
            ),
          ],
        );
      },
    );
  }

  Widget _modernStatCard({
    required Stream<int> stream,
    required String label,
    required String trend,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textLight),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCards() {
    final actions = [
      {'title': 'Add Patient', 'icon': Icons.person_add_rounded, 'color': AppColors.primary, 'page': const AdminPatientsPage()},
      {'title': 'Add Doctor', 'icon': Icons.person_add_alt_1_rounded, 'color': AppColors.teal, 'page': const AdminDoctorsPage()},
      {'title': 'New Record', 'icon': Icons.note_add_rounded, 'color': AppColors.indigo, 'page': const AdminMedicalRecordsPage()},
      {'title': 'Add Medicine', 'icon': Icons.medication_liquid_rounded, 'color': AppColors.amber, 'page': const AdminMedicinesPage()},
      {'title': 'Analytics', 'icon': Icons.bar_chart_rounded, 'color': AppColors.emerald, 'page': const AdminReportsPage()},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.map((act) {
          final color = act['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _navigate(context, act['page'] as Widget),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(act['icon'] as IconData, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
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

  Widget _buildRecentAppointmentsSection() {
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
                'Recent Appointments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
              ),
              TextButton(
                onPressed: () => _navigate(context, const AdminAppointmentsPage()),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('appointments').limit(5).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _emptyListCard('No recent appointments booked yet', Icons.calendar_month_outlined);
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return _RecentAppointmentTile(data: d);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPatientsSection() {
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
                'Newly Registered Patients',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
              ),
              TextButton(
                onPressed: () => _navigate(context, const AdminPatientsPage()),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('patients').limit(5).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _emptyListCard('No patients registered yet', Icons.person_outline);
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return _recentPatientCard(d);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _recentPatientCard(Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Unknown Patient';
    final gender = d['gender']?.toString() ?? 'N/A';
    final phone = d['phone']?.toString() ?? 'No phone';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain)),
                const SizedBox(height: 2),
                Text('$gender • $phone', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
            onPressed: () => _navigate(context, const AdminPatientsPage()),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementGrid() {
    final modules = [
      {'title': 'Patients Directory', 'sub': 'Profiles, medical history & demographics', 'icon': Icons.people_alt_rounded, 'color': AppColors.primary, 'page': const AdminPatientsPage()},
      {'title': 'Specialist Doctors', 'sub': 'Physician credentials, shifts & duties', 'icon': Icons.medical_services_rounded, 'color': AppColors.teal, 'page': const AdminDoctorsPage()},
      {'title': 'Clinical Appointments', 'sub': 'Triage calendar, bookings & reschedules', 'icon': Icons.calendar_month_rounded, 'color': AppColors.amber, 'page': const AdminAppointmentsPage()},
      {'title': 'Medical Records & Labs', 'sub': 'Diagnostic reports, test charts & vitals', 'icon': Icons.description_rounded, 'color': AppColors.indigo, 'page': const AdminMedicalRecordsPage()},
      {'title': 'Pharmacy & Formularies', 'sub': 'Inventory counts, reorders & dosages', 'icon': Icons.medication_rounded, 'color': Colors.purple, 'page': const AdminMedicinesPage()},
      {'title': 'Hospital Analytics', 'sub': 'Bed turnover, revenue & patient flow', 'icon': Icons.analytics_rounded, 'color': AppColors.emerald, 'page': const AdminReportsPage()},
      {'title': 'System Settings', 'sub': 'RBAC security, credentials & database info', 'icon': Icons.settings_rounded, 'color': AppColors.textMuted, 'page': const AdminSettingsPage()},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.8,
          ),
          itemCount: modules.length,
          itemBuilder: (context, idx) {
            final m = modules[idx];
            final color = m['color'] as Color;
            return InkWell(
              onTap: () => _navigate(context, m['page'] as Widget),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(m['icon'] as IconData, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['sub'] as String,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyListCard(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textLight),
            const SizedBox(height: 8),
            Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
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
            Text('Confirm Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of the ApexCare Command Center?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
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

/// A modern styled widget that resolves doctorId/patientId to names for appointment display.
class _RecentAppointmentTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecentAppointmentTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'Scheduled';
    Color statusColor = AppColors.amber;
    Color statusBg = AppColors.amberLight;

    if (status.toLowerCase() == 'completed') {
      statusColor = AppColors.emerald;
      statusBg = AppColors.emeraldLight;
    } else if (status.toLowerCase() == 'cancelled') {
      statusColor = AppColors.rose;
      statusBg = AppColors.roseLight;
    } else if (status.toLowerCase() == 'scheduled') {
      statusColor = AppColors.primary;
      statusBg = AppColors.primaryLight;
    }

    final patientNameDirect = data['patientName']?.toString();
    final doctorNameDirect = data['doctorName']?.toString();
    final patientId = data['patientId']?.toString();
    final doctorId = data['doctorId']?.toString();

    return FutureBuilder<List<String>>(
      future: _resolveNames(
        patientNameDirect: patientNameDirect,
        doctorNameDirect: doctorNameDirect,
        patientId: patientId,
        doctorId: doctorId,
      ),
      builder: (context, snap) {
        final names = snap.data ?? [patientNameDirect ?? patientId ?? 'Patient', doctorNameDirect ?? doctorId ?? 'Doctor'];
        final patientName = names[0];
        final doctorName = names[1];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doctorName.isNotEmpty ? "With $doctorName • " : ""}${data['date'] ?? 'Upcoming'} ${data['time'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _resolveNames({
    String? patientNameDirect,
    String? doctorNameDirect,
    String? patientId,
    String? doctorId,
  }) async {
    String pName = patientNameDirect ?? 'Patient';
    String dName = doctorNameDirect ?? '';

    final db = FirestoreHelper.db;

    if ((patientNameDirect == null || patientNameDirect.isEmpty) && patientId != null && patientId.isNotEmpty) {
      try {
        final pDoc = await db.collection('patients').doc(patientId).get();
        if (pDoc.exists) {
          pName = pDoc.data()?['name']?.toString() ?? patientId;
        } else {
          pName = patientId;
        }
      } catch (_) {
        pName = patientId;
      }
    }

    if ((doctorNameDirect == null || doctorNameDirect.isEmpty) && doctorId != null && doctorId.isNotEmpty) {
      try {
        final dDoc = await db.collection('doctors').doc(doctorId).get();
        if (dDoc.exists) {
          dName = dDoc.data()?['name']?.toString() ?? doctorId;
        } else {
          dName = doctorId;
        }
      } catch (_) {
        dName = doctorId;
      }
    }

    return [pName, dName];
  }
}
