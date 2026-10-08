import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';

class DocAppointmentsPage extends StatefulWidget {
  final String doctorId;
  final String doctorUid;
  final String doctorName;

  const DocAppointmentsPage({
    super.key,
    this.doctorId = '',
    this.doctorUid = '',
    this.doctorName = '',
  });

  @override
  State<DocAppointmentsPage> createState() => _DocAppointmentsPageState();
}

class _DocAppointmentsPageState extends State<DocAppointmentsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;

  String get _doctorDisplayName {
    final trimmed = widget.doctorName.trim();
    if (trimmed.isEmpty) return 'Doctor';
    if (trimmed.toLowerCase().startsWith('dr.') || trimmed.toLowerCase().startsWith('dr ')) {
      return trimmed;
    }
    return 'Dr. $trimmed';
  }

  bool _isOwnedAppointment(Map<String, dynamic> data) {
    final apptDocId = data['doctorId']?.toString().trim() ?? '';
    final apptDocUid = data['doctorUid']?.toString().trim() ?? '';
    final apptDocName = data['doctorName']?.toString().trim().toLowerCase() ?? '';

    // Match doctorId (Firestore document ID)
    if (widget.doctorId.isNotEmpty && apptDocId == widget.doctorId) {
      return true;
    }

    // Match doctorUid (Firebase Auth UID)
    if (widget.doctorUid.isNotEmpty &&
        (apptDocUid == widget.doctorUid || apptDocId == widget.doctorUid)) {
      return true;
    }

    // Match doctorName (case-insensitive)
    if (widget.doctorName.isNotEmpty) {
      final myName = widget.doctorName.trim().toLowerCase();
      final myDisplayName = _doctorDisplayName.toLowerCase();
      if (apptDocName.isNotEmpty && (apptDocName == myName || apptDocName == myDisplayName)) {
        return true;
      }
    }

    return false;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in-progress':
        return Colors.blue;
      case 'scheduled':
      case 'booked':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('appointments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Unable to load appointments: ${snapshot.error}'),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final myAppointments = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            return _isOwnedAppointment(data);
          }).toList();

          if (myAppointments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No appointments scheduled for $_doctorDisplayName',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: myAppointments.length,
            itemBuilder: (context, index) {
              final doc = myAppointments[index];
              final data = doc.data() as Map<String, dynamic>;
              final patient = data['patientName']?.toString() ??
                  data['patientId']?.toString() ??
                  'Patient';
              final date = data['date']?.toString() ?? 'N/A';
              final time = data['time']?.toString() ?? 'N/A';
              final status = data['status']?.toString() ?? 'Scheduled';
              final specialty = data['specialty']?.toString() ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: const Icon(Icons.person, color: Colors.green),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$date • $time',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            if (specialty.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  specialty,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
