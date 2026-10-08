import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';
import '../../widgets/blockchain_verification_dialog.dart';
import '../../widgets/ai_dialogs.dart';

class PatMedicalRecordsPage extends StatefulWidget {
  final String patientId;

  const PatMedicalRecordsPage({
    super.key,
    this.patientId = '',
  });

  @override
  State<PatMedicalRecordsPage> createState() => _PatMedicalRecordsPageState();
}

class _PatMedicalRecordsPageState extends State<PatMedicalRecordsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  late String _currentUid;
  String _permanentPatientId = '';
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _currentUid = user?.uid ?? widget.patientId;
    _loadPatientProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientProfile() async {
    if (_currentUid.isEmpty) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final pDoc = await _db.collection('patients').doc(_currentUid).get();
      if (pDoc.exists && pDoc.data() != null) {
        final d = pDoc.data()!;
        _permanentPatientId = d['patientId']?.toString() ?? '';
      } else {
        final uDoc = await _db.collection('users').doc(_currentUid).get();
        if (uDoc.exists && uDoc.data() != null) {
          final d = uDoc.data()!;
          _permanentPatientId = d['patientId']?.toString() ?? '';
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FA),
      appBar: AppBar(
        title: const Text(
          'My Medical Records',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar banner
                Container(
                  color: Colors.indigo[700],
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search records by diagnosis or doctor...',
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                // Records stream list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _currentUid.isNotEmpty
                        ? _db
                            .collection('medical_records')
                            .where('patientId', isEqualTo: _currentUid)
                            .snapshots()
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 54, color: Colors.red[300]),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unable to load medical records',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      var docs = snapshot.data?.docs ?? [];

                      // If no records found under UID and permanent patientId exists, also check permanent ID if different
                      // Note: We can filter in memory if needed
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final diag = d['diagnosis']?.toString().toLowerCase() ?? '';
                          final doctor = d['doctorName']?.toString().toLowerCase() ?? '';
                          final presc = d['prescription']?.toString().toLowerCase() ?? '';
                          final date = d['date']?.toString().toLowerCase() ?? '';
                          return diag.contains(_searchQuery) ||
                              doctor.contains(_searchQuery) ||
                              presc.contains(_searchQuery) ||
                              date.contains(_searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: 64, color: Colors.indigo[200]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching records found'
                                      : 'No medical records yet',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching with a different term'
                                      : 'Your medical records, prescriptions, and lab results provided by your doctor will appear here.',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildRecordCard(context, doc.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecordCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final title = d['diagnosis']?.toString().isNotEmpty == true
        ? d['diagnosis']!.toString()
        : (d['title']?.toString() ?? 'Medical Consultation');
    final doctorName = d['doctorName']?.toString() ?? 'Attending Doctor';
    final date = d['date']?.toString() ?? 'Date N/A';
    final prescription = d['prescription']?.toString() ?? '';
    final notes = d['notes']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showRecordDetails(context, docId, d),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.description, color: Colors.indigo[700], size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.medical_services_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Dr. $doctorName',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      date,
                      style: TextStyle(
                        color: Colors.indigo[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (prescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.medication, size: 16, color: Colors.brown),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prescription: $prescription',
                          style: const TextStyle(
                            color: Colors.brown,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => BlockchainVerificationDialog.show(
                          context,
                          recordId: docId,
                          recordTitle: title,
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 14),
                        label: const Text('Verify Integrity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo.shade700,
                          side: BorderSide(color: Colors.indigo.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => AISummaryDialog.show(
                          context,
                          recordId: docId,
                          recordTitle: title,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.purple),
                        label: const Text('AI Summary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.purple.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Details →',
                    style: TextStyle(
                      color: Colors.indigo[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(BuildContext context, String docId, Map<String, dynamic> d) {
    final title = d['diagnosis']?.toString().isNotEmpty == true
        ? d['diagnosis']!.toString()
        : 'Medical Record';
    final doctorName = d['doctorName']?.toString() ?? 'Attending Doctor';
    final date = d['date']?.toString() ?? 'Date N/A';
    final prescription = d['prescription']?.toString() ?? 'No prescription recorded';
    final notes = d['notes']?.toString() ?? 'No additional clinical notes recorded';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.description, color: Colors.indigo[700], size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Medical Record Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Date: $date',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              _detailItem(Icons.health_and_safety, 'Diagnosis / Condition', title),
              _detailItem(Icons.person, 'Attending Doctor', 'Dr. $doctorName'),
              _detailItem(Icons.medication, 'Prescription & Medication', prescription),
              _detailItem(Icons.notes, 'Clinical Notes & Advice', notes),

              if (_permanentPatientId.isNotEmpty)
                _detailItem(Icons.badge, 'Patient ID', _permanentPatientId),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    AISummaryDialog.show(
                      context,
                      recordId: docId,
                      recordTitle: title,
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Generate AI Clinical Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    BlockchainVerificationDialog.show(
                      context,
                      recordId: docId,
                      recordTitle: title,
                    );
                  },
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  label: const Text('Verify Record Integrity on Blockchain'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.indigo[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
