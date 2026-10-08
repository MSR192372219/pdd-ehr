import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helper.dart';
import '../utils/app_theme.dart';

class DoctorPrescriptionDialog {
  static Future<void> show(
    BuildContext context, {
    required String doctorName,
    required String doctorUid,
    required String doctorId,
    String? prefilledPatientId,
    String? prefilledPatientName,
    String? prefilledProblem,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PrescriptionDialogContent(
        doctorName: doctorName,
        doctorUid: doctorUid,
        doctorId: doctorId,
        prefilledPatientId: prefilledPatientId,
        prefilledPatientName: prefilledPatientName,
        prefilledProblem: prefilledProblem,
      ),
    );
  }
}

class _PrescriptionDialogContent extends StatefulWidget {
  final String doctorName;
  final String doctorUid;
  final String doctorId;
  final String? prefilledPatientId;
  final String? prefilledPatientName;
  final String? prefilledProblem;

  const _PrescriptionDialogContent({
    required this.doctorName,
    required this.doctorUid,
    required this.doctorId,
    this.prefilledPatientId,
    this.prefilledPatientName,
    this.prefilledProblem,
  });

  @override
  State<_PrescriptionDialogContent> createState() => _PrescriptionDialogContentState();
}

class _PrescriptionDialogContentState extends State<_PrescriptionDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _diagController = TextEditingController();
  final _notesController = TextEditingController();

  // Medication items list
  final List<Map<String, dynamic>> _medications = [];

  // Controllers for adding an item
  final _medNameController = TextEditingController();
  final _dosageController = TextEditingController(text: '1 Tablet (500mg)');
  String _frequency = 'Twice Daily (Morning & Night)';
  final DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 5));
  final _instructionsController = TextEditingController();

  bool _takeMorning = true;
  bool _takeAfternoon = false;
  bool _takeNight = true;
  String _mealInstruction = 'Post Breakfast / Meal';
  String _duration = '5 Days';

  // Selected patient
  String? _selectedPatientUid;
  String? _selectedPatientName;

  bool _isLoadingPatients = false;
  List<Map<String, String>> _patientsList = [];
  bool _isSubmitting = false;

  final List<String> _quickProblems = [
    'Viral Bronchitis & Cough',
    'Seasonal Flu & Fever',
    'Hypertension Stage 1',
    'Type 2 Diabetes Care',
    'Acute Gastritis & Acidity',
    'Migraine & Tension Headache',
    'Allergic Rhinitis',
  ];

  final List<String> _quickMeds = [
    'Amoxicillin 500mg',
    'Paracetamol 650mg',
    'Azithromycin 500mg',
    'Pantoprazole 40mg',
    'Cetirizine 10mg',
    'Amlodipine 5mg',
    'Metformin 500mg',
    'Cough Syrup 10ml',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledProblem != null && widget.prefilledProblem!.isNotEmpty) {
      _diagController.text = widget.prefilledProblem!;
    }
    if (widget.prefilledPatientId != null && widget.prefilledPatientId!.isNotEmpty) {
      _selectedPatientUid = widget.prefilledPatientId;
      _selectedPatientName = widget.prefilledPatientName ?? 'Patient';
    } else {
      _loadPatients();
    }
    // Clean start - no fake prescription data
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final snap = await FirestoreHelper.db.collection('patients').get();
      final List<Map<String, String>> list = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = data['name']?.toString().trim() ?? 'Unknown Patient';
        final pid = data['patientId']?.toString().trim() ?? '';
        list.add({
          'uid': doc.id,
          'name': name,
          'patientId': pid,
          'display': pid.isNotEmpty ? '$name ($pid)' : name,
        });
      }
      if (list.isEmpty) {
        // Also check users collection
        final uSnap = await FirestoreHelper.db
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .get();
        for (final doc in uSnap.docs) {
          final data = doc.data();
          final name = data['name']?.toString().trim() ?? 'Unknown Patient';
          final pid = data['patientId']?.toString().trim() ?? '';
          list.add({
            'uid': doc.id,
            'name': name,
            'patientId': pid,
            'display': pid.isNotEmpty ? '$name ($pid)' : name,
          });
        }
      }
      if (mounted) {
        setState(() {
          _patientsList = list;
          _isLoadingPatients = false;
          if (_selectedPatientUid == null && list.isNotEmpty) {
            _selectedPatientUid = list.first['uid'];
            _selectedPatientName = list.first['name'];
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  void _addMedicationItem() {
    final medName = _medNameController.text.trim();
    if (medName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter medication name & strength')),
      );
      return;
    }

    final dosage = _dosageController.text.trim();
    if (dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter dosage (e.g. 1 Tablet or 500mg)')),
      );
      return;
    }

    if (!_takeMorning && !_takeAfternoon && !_takeNight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one schedule time (Morning, Afternoon, or Night)')),
      );
      return;
    }

    final startStr = '${_startDate.day.toString().padLeft(2, '0')}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.year}';
    final endStr = '${_endDate.day.toString().padLeft(2, '0')}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.year}';

    final List<String> timings = [];
    if (_takeMorning) timings.add('08:00 AM (Morning)');
    if (_takeAfternoon) timings.add('01:00 PM (Afternoon)');
    if (_takeNight) timings.add('09:00 PM (Night)');

    final customInstructions = _instructionsController.text.trim();
    final fullInstructions = customInstructions.isNotEmpty ? customInstructions : _mealInstruction;

    setState(() {
      _medications.add({
        'name': '$medName - $dosage',
        'medicine': medName,
        'dosage': dosage,
        'frequency': _frequency,
        'startDate': startStr,
        'endDate': endStr,
        'duration': _duration,
        'meal': _mealInstruction,
        'timing': timings.join(', '),
        'timings': timings,
        'instructions': fullInstructions,
      });

      _medNameController.clear();
      _instructionsController.clear();
      _takeMorning = true;
      _takeAfternoon = false;
      _takeNight = true;
    });
  }

  Future<void> _submitPrescription() async {
    if (_selectedPatientUid == null || _selectedPatientUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify a patient')),
      );
      return;
    }

    final diag = _diagController.text.trim();
    if (diag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the patient\'s problem / diagnosis')),
      );
      return;
    }

    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medication to the schedule')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Build formatted prescription text for medical_records
      final List<String> formattedLines = [];
      for (final med in _medications) {
        final name = med['medicine'] ?? med['name'] ?? '';
        final dosage = med['dosage'] ?? '';
        final freq = med['frequency'] ?? '';
        final timing = med['timing'] ?? '';
        final meal = med['meal'] ?? '';
        final sDate = med['startDate'] ?? '';
        final eDate = med['endDate'] ?? '';
        formattedLines.add('$name ($dosage) - $freq [$sDate to $eDate] | $timing ($meal)');
      }
      final prescriptionText = formattedLines.join('\n');

      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

      // 1. Authoritative Electronic Prescription in 'prescriptions' collection
      final prescriptionData = {
        'patientId': _selectedPatientUid,
        'patientName': _selectedPatientName ?? 'Patient',
        'doctorId': widget.doctorId,
        'doctorUid': widget.doctorUid,
        'doctorName': widget.doctorName,
        'diagnosis': diag,
        'medicines': _medications,
        'notes': _notesController.text.trim(),
        'date': dateStr,
        'status': 'active',
        'takenLog': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreHelper.db.collection('prescriptions').add(prescriptionData);

      // 2. Clinical Medical Record in 'medical_records' collection
      final recordData = {
        'patientId': _selectedPatientUid,
        'patientName': _selectedPatientName ?? 'Patient',
        'doctorId': widget.doctorId,
        'doctorUid': widget.doctorUid,
        'doctorName': widget.doctorName,
        'diagnosis': diag,
        'prescription': prescriptionText,
        'medicines': _medications,
        'notes': _notesController.text.trim(),
        'date': dateStr,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      await FirestoreHelper.db.collection('medical_records').add(recordData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prescription issued for $_selectedPatientName! Daily schedule updated.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save prescription: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _diagController.dispose();
    _notesController.dispose();
    _medNameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: AppGradients.headerDoctor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issue Clinical Prescription',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Prescribing as ${widget.doctorName} • Daily Schedule Generator',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Patient Selection
                      const Text(
                        '1. Target Patient',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 8),
                      if (widget.prefilledPatientName != null && widget.prefilledPatientName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, color: AppColors.teal, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                widget.prefilledPatientName!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.tealLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Consultation Patient', style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else if (_isLoadingPatients)
                        const LinearProgressIndicator(color: AppColors.teal)
                      else if (_patientsList.isEmpty)
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Patient Name',
                            hintText: 'Enter patient full name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) {
                            _selectedPatientName = val;
                            _selectedPatientUid = val;
                          },
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedPatientUid,
                          decoration: InputDecoration(
                            labelText: 'Select Registered Patient',
                            prefixIcon: const Icon(Icons.person_search_rounded, color: AppColors.teal),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: _patientsList.map((p) {
                            return DropdownMenuItem<String>(
                              value: p['uid'],
                              child: Text(p['display'] ?? 'Patient', style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedPatientUid = val;
                              final match = _patientsList.firstWhere((p) => p['uid'] == val, orElse: () => {});
                              _selectedPatientName = match['name'] ?? 'Patient';
                            });
                          },
                        ),

                      const SizedBox(height: 20),

                      // Section 2: Patient Problem / Diagnosis
                      const Row(
                        children: [
                          Text(
                            '2. Diagnosed Condition / Patient Problem',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                          ),
                          SizedBox(width: 4),
                          Text('*', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _diagController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Acute Bronchitis & Productive Cough',
                          prefixIcon: const Icon(Icons.health_and_safety_rounded, color: AppColors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Quick Problem Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickProblems.map((prob) {
                          return ActionChip(
                            label: Text(prob, style: const TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.add, size: 13, color: AppColors.teal),
                            backgroundColor: AppColors.surfaceSubtle,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onPressed: () {
                              setState(() => _diagController.text = prob);
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),

                      // Section 3: Daily Prescription Medication Schedule
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '3. Daily Medication Schedule',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                              ),
                              SizedBox(width: 4),
                              Text('*', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('Will sync to Patient Portal', style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Add medication box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _medNameController,
                              decoration: InputDecoration(
                                hintText: 'Medicine & Strength (e.g. Amoxicillin 500mg)',
                                prefixIcon: const Icon(Icons.medication_liquid_outlined, color: AppColors.teal),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Quick med chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _quickMeds.map((med) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text(med, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      onPressed: () {
                                        setState(() => _medNameController.text = med);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Dosage and Frequency Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _dosageController,
                                    decoration: InputDecoration(
                                      labelText: 'Dosage / Strength',
                                      hintText: 'e.g. 500mg, 1 Tab, 10ml',
                                      prefixIcon: const Icon(Icons.scale_rounded, size: 16, color: AppColors.teal),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _frequency,
                                    decoration: InputDecoration(
                                      labelText: 'Frequency',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Once Daily (Morning)', child: Text('Once Daily (AM)', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'Once Daily (Night)', child: Text('Once Daily (PM)', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'Twice Daily (Morning & Night)', child: Text('Twice Daily (BID)', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'Three Times Daily', child: Text('Thrice Daily (TID)', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'Every 8 Hours', child: Text('Every 8 Hours', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'As Needed (PRN)', child: Text('As Needed (PRN)', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _frequency = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Timing pills
                            const Text('Daily Schedule Timings:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBody)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                FilterChip(
                                  label: const Text('Morning (08:00 AM)', style: TextStyle(fontSize: 12)),
                                  selected: _takeMorning,
                                  selectedColor: AppColors.tealLight,
                                  checkmarkColor: AppColors.teal,
                                  onSelected: (val) => setState(() => _takeMorning = val),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('Afternoon (01:00 PM)', style: TextStyle(fontSize: 12)),
                                  selected: _takeAfternoon,
                                  selectedColor: AppColors.tealLight,
                                  checkmarkColor: AppColors.teal,
                                  onSelected: (val) => setState(() => _takeAfternoon = val),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('Night (09:00 PM)', style: TextStyle(fontSize: 12)),
                                  selected: _takeNight,
                                  selectedColor: AppColors.tealLight,
                                  checkmarkColor: AppColors.teal,
                                  onSelected: (val) => setState(() => _takeNight = val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _instructionsController,
                              decoration: InputDecoration(
                                hintText: 'Timing / Instructions (e.g. Take with warm water after food)',
                                prefixIcon: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.teal),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _mealInstruction,
                                    decoration: InputDecoration(
                                      labelText: 'Meal Instruction',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Post Breakfast / Meal', child: Text('After Food', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'Before Food (Empty Stomach)', child: Text('Before Food', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'With Food', child: Text('With Food', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'Before Bed', child: Text('Before Bed', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _mealInstruction = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _duration,
                                    decoration: InputDecoration(
                                      labelText: 'Duration',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: '3 Days', child: Text('3 Days', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '5 Days', child: Text('5 Days', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '7 Days', child: Text('7 Days', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '14 Days', child: Text('14 Days', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '30 Days', child: Text('30 Days', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _duration = val;
                                          final days = int.tryParse(val.split(' ').first) ?? 5;
                                          _endDate = _startDate.add(Duration(days: days));
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _addMedicationItem,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Dose'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Current Scheduled List
                      if (_medications.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.amber, size: 18),
                              SizedBox(width: 8),
                              Text('No medications scheduled yet. Add at least one above.', style: TextStyle(fontSize: 12, color: AppColors.textBody)),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _medications.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.teal, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain),
                                        ),
                                        Text(
                                          '⏰ ${item['timing']} • ${item['meal'] ?? ''}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.tealDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                                    onPressed: () {
                                      setState(() => _medications.removeAt(idx));
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 20),

                      // Section 4: Clinical Instructions
                      const Text(
                        '4. Doctor\'s Clinical Advice / Instructions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Drink warm fluids, avoid cold exposure, and follow up in 5 days if fever persists.',
                          prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_medications.length} doses scheduled',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitPrescription,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_isSubmitting ? 'Issuing...' : 'Save & Issue Prescription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
