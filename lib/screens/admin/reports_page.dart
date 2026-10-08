import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Summary Statistics'),
            const SizedBox(height: 12),
            _StatSummaryCard(collection: 'patients', label: 'Total Patients', icon: Icons.people_alt, color: Colors.blue),
            const SizedBox(height: 10),
            _StatSummaryCard(collection: 'doctors', label: 'Total Doctors', icon: Icons.medical_services, color: Colors.green),
            const SizedBox(height: 10),
            _StatSummaryCard(collection: 'appointments', label: 'Total Appointments', icon: Icons.calendar_month, color: Colors.orange),
            const SizedBox(height: 10),
            _StatSummaryCard(collection: 'medicines', label: 'Total Medicines', icon: Icons.local_pharmacy, color: Colors.purple),
            const SizedBox(height: 24),

            _sectionTitle('Appointment Status Breakdown'),
            const SizedBox(height: 12),
            _AppointmentStatusChart(),
            const SizedBox(height: 24),

            _sectionTitle('Doctor Availability'),
            const SizedBox(height: 12),
            _DoctorAvailabilityChart(),
            const SizedBox(height: 24),

            _sectionTitle('Medicine Stock Levels'),
            const SizedBox(height: 12),
            _MedicineStockChart(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final String collection;
  final String label;
  final IconData icon;
  final Color color;

  const _StatSummaryCard({
    required this.collection,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreHelper.db.collection(collection).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  radius: 28,
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(label, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppointmentStatusChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreHelper.db.collection('appointments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyCard('No appointment data yet');
        }

        final counts = <String, int>{'Booked': 0, 'Completed': 0, 'Cancelled': 0};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final status = d['status']?.toString() ?? 'Booked';
          counts[status] = (counts[status] ?? 0) + 1;
        }
        final total = docs.length;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _barRow('Booked', counts['Booked'] ?? 0, total, Colors.orange),
                const SizedBox(height: 10),
                _barRow('Completed', counts['Completed'] ?? 0, total, Colors.green),
                const SizedBox(height: 10),
                _barRow('Cancelled', counts['Cancelled'] ?? 0, total, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$count / $total', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _DoctorAvailabilityChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreHelper.db.collection('doctors').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyCard('No doctor data yet');
        }
        int available = 0, unavailable = 0;
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['available'] == true) {
            available++;
          } else {
            unavailable++;
          }
        }
        final total = docs.length;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _barRow('Available', available, total, Colors.green),
                const SizedBox(height: 10),
                _barRow('Unavailable', unavailable, total, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$count / $total', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _MedicineStockChart extends StatelessWidget {
  static const int _lowThreshold = 10;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreHelper.db.collection('medicines').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyCard('No medicine data yet');
        }
        int lowStock = 0, adequate = 0;
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final qty = int.tryParse(d['quantity']?.toString() ?? '0') ?? 0;
          if (qty <= _lowThreshold) {
            lowStock++;
          } else {
            adequate++;
          }
        }
        final total = docs.length;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _barRow('Adequate Stock', adequate, total, Colors.green),
                const SizedBox(height: 10),
                _barRow('Low Stock (≤$_lowThreshold)', lowStock, total, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$count / $total', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

Widget _emptyCard(String message) {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    ),
  );
}
