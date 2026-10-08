import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';

class DocPatientsPage extends StatefulWidget {
  final String doctorId;
  final String doctorUid;
  final String doctorName;

  const DocPatientsPage({
    super.key,
    this.doctorId = '',
    this.doctorUid = '',
    this.doctorName = '',
  });

  @override
  State<DocPatientsPage> createState() => _DocPatientsPageState();
}

class _DocPatientsPageState extends State<DocPatientsPage> {
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

    if (widget.doctorId.isNotEmpty && apptDocId == widget.doctorId) {
      return true;
    }

    if (widget.doctorUid.isNotEmpty &&
        (apptDocUid == widget.doctorUid || apptDocId == widget.doctorUid)) {
      return true;
    }

    if (widget.doctorName.isNotEmpty) {
      final myName = widget.doctorName.trim().toLowerCase();
      final myDisplayName = _doctorDisplayName.toLowerCase();
      if (apptDocName.isNotEmpty && (apptDocName == myName || apptDocName == myDisplayName)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
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
                child: Text('Unable to load patients: ${snapshot.error}'),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final myAppointments = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            return _isOwnedAppointment(data);
          }).toList();

          // Extract distinct patients from this doctor's appointments
          final Map<String, Map<String, dynamic>> patientsMap = {};
          for (final doc in myAppointments) {
            final data = doc.data() as Map<String, dynamic>;
            final patientId = data['patientId']?.toString().trim() ?? '';
            final patientName = data['patientName']?.toString().trim() ?? '';
            final date = data['date']?.toString().trim() ?? '';
            final key = patientId.isNotEmpty ? patientId : patientName;

            if (key.isNotEmpty && !patientsMap.containsKey(key)) {
              patientsMap[key] = {
                'id': patientId.isNotEmpty ? patientId : 'N/A',
                'name': patientName.isNotEmpty ? patientName : 'Unknown Patient',
                'lastVisit': date,
              };
            }
          }

          final patientsList = patientsMap.values.toList();

          if (patientsList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No patients assigned to $_doctorDisplayName yet',
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
            itemCount: patientsList.length,
            itemBuilder: (context, index) {
              final patient = patientsList[index];
              final name = patient['name'] ?? 'Patient';
              final id = patient['id'] ?? 'N/A';
              final lastVisit = patient['lastVisit'] ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: const Icon(Icons.person, color: Colors.green),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    lastVisit.isNotEmpty ? 'ID: $id • Last Visit: $lastVisit' : 'ID: $id',
                    style: TextStyle(color: Colors.grey[600]),
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
