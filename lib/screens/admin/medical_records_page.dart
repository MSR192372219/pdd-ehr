import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';

class AdminMedicalRecordsPage extends StatefulWidget {
  const AdminMedicalRecordsPage({super.key});

  @override
  State<AdminMedicalRecordsPage> createState() => _AdminMedicalRecordsPageState();
}

class _AdminMedicalRecordsPageState extends State<AdminMedicalRecordsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.indigo[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Unable to load records. Please try again later.'),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['patientName']?.toString().toLowerCase() ?? '';
                    final diag = d['diagnosis']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery) || diag.contains(_searchQuery);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No records match your search' : 'No medical records yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Tap + to add the first record', style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data() as Map<String, dynamic>;
                    return _recordCard(context, doc.id, d);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
        backgroundColor: Colors.indigo[700],
      ),
    );
  }

  Widget _recordCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final patientName = d['patientName']?.toString() ?? 'Unknown';
    final diagnosis = d['diagnosis']?.toString() ?? '';
    final doctorName = d['doctorName']?.toString() ?? '';
    final date = d['date']?.toString() ?? '';


    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[50],
          child: Icon(Icons.description, color: Colors.indigo[700]),
        ),
        title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${diagnosis.isNotEmpty ? 'Diagnosis: $diagnosis' : ''}'
          '${doctorName.isNotEmpty ? '\nDr. $doctorName' : ''}'
          '${date.isNotEmpty ? ' • $date' : ''}',
        ),
        isThreeLine: doctorName.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'view') _showRecordDetails(context, d);
            if (val == 'edit') _showRecordDialog(context, docId: docId, existing: d);
            if (val == 'delete') _confirmDelete(context, docId, patientName);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('View Details')])),
            PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
            PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
          ],
        ),
        onTap: () => _showRecordDetails(context, d),
      ),
    );
  }

  void _showRecordDetails(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(
                d['patientName']?.toString() ?? 'Medical Record',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text('Medical Record Details', style: TextStyle(color: Colors.grey[600])),
              const Divider(height: 24),
              _detail('Diagnosis', d['diagnosis']),
              _detail('Prescription', d['prescription']),
              _detail('Doctor', d['doctorName']),
              _detail('Date', d['date']),
              _detail('Notes', d['notes']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  void _showRecordDialog(BuildContext context, {String? docId, Map<String, dynamic>? existing}) {
    final patientCtrl = TextEditingController(text: existing?['patientName'] ?? '');
    final doctorCtrl = TextEditingController(text: existing?['doctorName'] ?? '');
    final diagCtrl = TextEditingController(text: existing?['diagnosis'] ?? '');
    final prescCtrl = TextEditingController(text: existing?['prescription'] ?? '');
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    final dateCtrl = TextEditingController(text: existing?['date'] ?? '');
    final isEdit = docId != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Record' : 'Add Medical Record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(patientCtrl, 'Patient Name', Icons.person),
              const SizedBox(height: 10),
              _field(doctorCtrl, 'Doctor Name', Icons.medical_services),
              const SizedBox(height: 10),
              _field(diagCtrl, 'Diagnosis', Icons.health_and_safety),
              const SizedBox(height: 10),
              _field(prescCtrl, 'Prescription', Icons.medication),
              const SizedBox(height: 10),
              _field(dateCtrl, 'Date (DD-MM-YYYY)', Icons.calendar_month),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: const Icon(Icons.notes, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (patientCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient name is required')));
                return;
              }
              String patientId = existing?['patientId']?.toString() ?? '';
              if (patientId.isEmpty) {
                try {
                  final matchName = await _db
                      .collection('patients')
                      .where('name', isEqualTo: patientCtrl.text.trim())
                      .limit(1)
                      .get();
                  if (matchName.docs.isNotEmpty) {
                    patientId = matchName.docs.first.id;
                  } else {
                    final matchUser = await _db
                        .collection('users')
                        .where('name', isEqualTo: patientCtrl.text.trim())
                        .limit(1)
                        .get();
                    if (matchUser.docs.isNotEmpty) {
                      patientId = matchUser.docs.first.id;
                    }
                  }
                } catch (_) {}
              }

              final data = {
                'patientName': patientCtrl.text.trim(),
                if (patientId.isNotEmpty) 'patientId': patientId,
                'doctorName': doctorCtrl.text.trim(),
                'diagnosis': diagCtrl.text.trim(),
                'prescription': prescCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'date': dateCtrl.text.trim(),
                if (!isEdit) 'createdAt': FieldValue.serverTimestamp(),
              };
              try {
                if (isEdit) {
                  await _db.collection('medical_records').doc(docId).update(data);
                } else {
                  await _db.collection('medical_records').add(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Record updated!' : 'Record added!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Delete medical record for "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _db.collection('medical_records').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
