import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ai_dialogs.dart';

class PatPrescriptionsPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatPrescriptionsPage({
    super.key,
    this.patientId = '',
    this.patientName = 'Patient',
  });

  @override
  State<PatPrescriptionsPage> createState() => _PatPrescriptionsPageState();
}

class _PatPrescriptionsPageState extends State<PatPrescriptionsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  late String _currentUid;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _currentUid = user?.uid ?? widget.patientId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Prescriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: AppColors.teal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: ['All', 'Active', 'Completed'].map((status) {
                final isSelected = _filter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filter = status),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white24,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.teal : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    checkmarkColor: AppColors.teal,
                  ),
                );
              }).toList(),
            ),
          ),

          // Prescriptions list stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _currentUid.isNotEmpty
                  ? _db
                      .collection('prescriptions')
                      .where('patientId', isEqualTo: _currentUid)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.teal));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 54, color: AppColors.rose),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load prescriptions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                if (_filter != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status']?.toString().toLowerCase() ?? 'active';
                    return status == _filter.toLowerCase();
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No Prescriptions Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filter == 'All'
                                ? 'Your licensed doctor has not issued any prescriptions yet.'
                                : 'No $_filter prescriptions on record.',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildPrescriptionCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final doctorName = data['doctorName']?.toString() ?? 'Attending Physician';
    final diagnosis = data['diagnosis']?.toString() ?? 'General Consultation';
    final date = data['date']?.toString() ?? '';
    final notes = data['notes']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'Active';
    final List<dynamic> medicinesRaw = data['medicines'] is List ? data['medicines'] : [];

    final Map<String, dynamic> takenLog = data['takenLog'] is Map ? (data['takenLog'] as Map<String, dynamic>) : {};
    final now = DateTime.now();
    final todayKey = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    final isActive = status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tealLight.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.teal,
                  radius: 20,
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                      ),
                      Text(
                        'Diagnosis: $diagnosis',
                        style: const TextStyle(fontSize: 12, color: AppColors.tealDark, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.emeraldLight : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.emerald : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Medicines Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medication_rounded, size: 16, color: AppColors.teal),
                    SizedBox(width: 6),
                    Text(
                      'Prescribed Medicines',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...medicinesRaw.asMap().entries.map((entry) {
                  final medIdx = entry.key;
                  final med = entry.value;
                  if (med is! Map) return const SizedBox.shrink();
                  final name = med['medicine']?.toString() ?? med['name']?.toString() ?? '';
                  final dosage = med['dosage']?.toString() ?? '';
                  final freq = med['frequency']?.toString() ?? '';
                  final timing = med['timing']?.toString() ?? '';
                  final meal = med['meal']?.toString() ?? '';
                  final sDate = med['startDate']?.toString() ?? '';
                  final eDate = med['endDate']?.toString() ?? '';
                  final instructions = med['instructions']?.toString() ?? '';

                  final logKey = '${todayKey}_$medIdx';
                  final isTaken = takenLog[logKey] == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isTaken ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isTaken ? const Color(0xFFBBF7D0) : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: isTaken ? TextDecoration.lineThrough : null,
                                color: isTaken ? AppColors.textMuted : AppColors.textMain,
                              ),
                            ),
                            if (dosage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.tealLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dosage,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tealDark),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (freq.isNotEmpty)
                          Text(
                            'Frequency: $freq',
                            style: const TextStyle(fontSize: 12, color: AppColors.textBody, fontWeight: FontWeight.w500),
                          ),
                        if (timing.isNotEmpty)
                          Text(
                            '⏰ Timings: $timing ${meal.isNotEmpty ? "• $meal" : ""}',
                            style: const TextStyle(fontSize: 12, color: AppColors.tealDark),
                          ),
                        if (sDate.isNotEmpty && eDate.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '📅 Duration: $sDate to $eDate',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ),
                        if (instructions.isNotEmpty && instructions != meal)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '💡 Note: $instructions',
                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => AIPrescriptionExplanationDialog.show(
                                context,
                                prescriptionId: docId,
                                medicineName: name,
                                dosage: dosage,
                                frequency: freq,
                                instructions: instructions,
                                diagnosis: diagnosis,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 12, color: Colors.teal),
                                    SizedBox(width: 4),
                                    Text(
                                      'Explain with AI',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isActive)
                              InkWell(
                                onTap: () async {
                                  final newLog = Map<String, dynamic>.from(takenLog);
                                  newLog[logKey] = !isTaken;
                                  try {
                                    await _db.collection('prescriptions').doc(docId).update({
                                      'takenLog': newLog,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Could not update status: $e')),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isTaken ? AppColors.emeraldLight : Colors.white,
                                    border: Border.all(color: isTaken ? AppColors.emerald : AppColors.border),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isTaken ? Icons.check_circle_rounded : Icons.circle_outlined,
                                        size: 14,
                                        color: isTaken ? AppColors.emerald : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isTaken ? 'Taken Today' : 'Mark as Taken',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isTaken ? AppColors.emerald : AppColors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Doctor\'s Advice: $notes',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMain),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Issued on: $date',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
                        SizedBox(width: 4),
                        Text(
                          'Verified Doctor Rx • Read Only',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
