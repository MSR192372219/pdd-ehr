import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';
import '../../widgets/blockchain_verification_dialog.dart';
import '../../widgets/ai_dialogs.dart';

class DocMedicalRecordsPage extends StatefulWidget {
  final String doctorId;
  final String doctorUid;
  final String doctorName;

  const DocMedicalRecordsPage({
    super.key,
    this.doctorId = '',
    this.doctorUid = '',
    this.doctorName = '',
  });

  @override
  State<DocMedicalRecordsPage> createState() => _DocMedicalRecordsPageState();
}

class _DocMedicalRecordsPageState extends State<DocMedicalRecordsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _doctorDisplayName {
    final trimmed = widget.doctorName.trim();
    if (trimmed.isEmpty) return 'Doctor';
    if (trimmed.toLowerCase().startsWith('dr.') || trimmed.toLowerCase().startsWith('dr ')) {
      return trimmed;
    }
    return 'Dr. $trimmed';
  }

  bool _isOwnedRecord(Map<String, dynamic> data) {
    final recordDocId = data['doctorId']?.toString().trim() ?? '';
    final recordDocUid = data['doctorUid']?.toString().trim() ?? '';
    final recordDocName = data['doctorName']?.toString().trim().toLowerCase() ?? '';

    if (widget.doctorId.isNotEmpty && recordDocId == widget.doctorId) {
      return true;
    }

    if (widget.doctorUid.isNotEmpty &&
        (recordDocUid == widget.doctorUid || recordDocId == widget.doctorUid)) {
      return true;
    }

    if (widget.doctorName.isNotEmpty) {
      final myName = widget.doctorName.trim().toLowerCase();
      final myDisplayName = _doctorDisplayName.toLowerCase();
      if (recordDocName.isNotEmpty && (recordDocName == myName || recordDocName == myDisplayName)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Medical Records'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.green[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase().trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by patient or diagnosis...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('medical_records').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Unable to load medical records: ${snapshot.error}'),
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                var records = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  return _isOwnedRecord(data);
                }).toList();

                if (_searchQuery.isNotEmpty) {
                  records = records.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final patient = d['patientName']?.toString().toLowerCase() ?? '';
                    final diag = d['diagnosis']?.toString().toLowerCase() ?? '';
                    final notes = d['notes']?.toString().toLowerCase() ?? '';
                    return patient.contains(_searchQuery) ||
                        diag.contains(_searchQuery) ||
                        notes.contains(_searchQuery);
                  }).toList();
                }

                if (records.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No medical records match your search'
                                : 'No medical records found for $_doctorDisplayName',
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
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final data = records[index].data() as Map<String, dynamic>;
                    final patientName = data['patientName']?.toString() ?? 'Patient';
                    final diagnosis = data['diagnosis']?.toString() ?? 'No diagnosis recorded';
                    final prescription = data['prescription']?.toString() ?? '';
                    final notes = data['notes']?.toString() ?? '';
                    final date = data['date']?.toString() ?? 'N/A';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    patientName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  date,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.medical_information, size: 18, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Diagnosis: $diagnosis',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (prescription.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Rx: $prescription',
                                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                              ),
                            ],
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Notes: $notes',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => AISummaryDialog.show(
                                    context,
                                    recordId: records[index].id,
                                    recordTitle: '$patientName — $diagnosis',
                                  ),
                                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                                  label: const Text('AI Summary', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.indigo.shade700,
                                    side: BorderSide(color: Colors.indigo.shade200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => BlockchainVerificationDialog.show(
                                    context,
                                    recordId: records[index].id,
                                    recordTitle: diagnosis,
                                  ),
                                  icon: const Icon(Icons.shield_outlined, size: 14),
                                  label: const Text('Verify Integrity', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueGrey.shade800,
                                    side: BorderSide(color: Colors.blueGrey.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => BlockchainProofCreationDialog.show(
                                    context,
                                    recordId: records[index].id,
                                    patientName: patientName,
                                    diagnosis: diagnosis,
                                  ),
                                  icon: const Icon(Icons.link, size: 14),
                                  label: const Text('Anchor Proof', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
