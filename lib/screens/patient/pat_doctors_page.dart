import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';
import 'pat_appointments_page.dart';

class PatDoctorsPage extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const PatDoctorsPage({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<PatDoctorsPage> createState() => _PatDoctorsPageState();
}

class _PatDoctorsPageState extends State<PatDoctorsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSpecialty = 'All';

  String _resolvedPatientName = 'Patient';
  String _resolvedPatientEmail = '';

  @override
  void initState() {
    super.initState();
    _loadPatientInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _resolvedPatientEmail = user.email ?? '';

    if (widget.patientName != null && widget.patientName!.isNotEmpty) {
      _resolvedPatientName = widget.patientName!;
      return;
    }

    try {
      // Check patients/{uid}
      final pDoc = await _db.collection('patients').doc(user.uid).get();
      if (pDoc.exists && pDoc.data() != null) {
        final d = pDoc.data()!;
        if (mounted) {
          setState(() {
            _resolvedPatientName = d['name']?.toString() ?? user.displayName ?? 'Patient';
          });
        }
        return;
      }

      // Check users/{uid}
      final uDoc = await _db.collection('users').doc(user.uid).get();
      if (uDoc.exists && uDoc.data() != null) {
        final d = uDoc.data()!;
        if (mounted) {
          setState(() {
            _resolvedPatientName = d['name']?.toString() ?? user.displayName ?? 'Patient';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        title: const Text(
          'Find Doctors',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header search banner
          Container(
            color: Colors.teal[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by doctor name or specialty...',
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
              ],
            ),
          ),

          // Doctors stream list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('doctors').snapshots(),
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
                            'Unable to load doctors list',
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

                // Collect available specialties for filter chips
                final Set<String> specialtiesSet = {'All'};
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final spec = data['specialization']?.toString().trim();
                  if (spec != null && spec.isNotEmpty) {
                    specialtiesSet.add(spec);
                  }
                }
                final specialtiesList = specialtiesSet.toList();

                // Apply text search
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toString().toLowerCase() ?? '';
                    final spec = data['specialization']?.toString().toLowerCase() ?? '';
                    final dept = data['department']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery) ||
                        spec.contains(_searchQuery) ||
                        dept.contains(_searchQuery);
                  }).toList();
                }

                // Apply specialty filter
                if (_selectedSpecialty != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['specialization']?.toString() == _selectedSpecialty;
                  }).toList();
                }

                return Column(
                  children: [
                    // Specialty filter chips
                    if (specialtiesList.length > 2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: specialtiesList.map((spec) {
                              final isSelected = _selectedSpecialty == spec;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(spec),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _selectedSpecialty = spec),
                                  selectedColor: Colors.teal[600],
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : Colors.teal[800],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  backgroundColor: Colors.teal[50],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // Empty state
                    if (docs.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _selectedSpecialty != 'All'
                                    ? 'No doctors match your criteria'
                                    : 'No doctors currently registered',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try clearing your search or filter',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Doctor cards
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildDoctorCard(context, doc.id, data);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Doctor';
    final specialization = d['specialization']?.toString() ?? 'General Physician';
    final department = d['department']?.toString() ?? '';
    final phone = d['phone']?.toString() ?? '';
    final email = d['email']?.toString() ?? '';
    final isAvailable = d['available'] == true || d['available'] == null;

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.teal[50],
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: isAvailable ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    color: isAvailable ? Colors.green[700] : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialization,
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (department.isNotEmpty)
                        Text(
                          department,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      if (phone.isNotEmpty || email.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (phone.isNotEmpty) ...[
                              Icon(Icons.phone, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (email.isNotEmpty) ...[
                              Icon(Icons.email, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDoctorDetails(context, d),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal[700],
                    side: BorderSide(color: Colors.teal[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isAvailable
                      ? () => _showBookAppointmentSheet(context, docId, d)
                      : null,
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Book Appointment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDoctorDetails(BuildContext context, Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Doctor';
    final specialization = d['specialization']?.toString() ?? 'General Physician';
    final department = d['department']?.toString() ?? 'General';
    final phone = d['phone']?.toString() ?? 'N/A';
    final email = d['email']?.toString() ?? 'N/A';
    final isAvailable = d['available'] == true || d['available'] == null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.teal[50],
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'D',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        specialization,
                        style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Department: $department',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _infoRow(Icons.check_circle_outline, 'Availability', isAvailable ? 'Available for appointments' : 'Currently Unavailable'),
            _infoRow(Icons.phone_outlined, 'Phone', phone),
            _infoRow(Icons.email_outlined, 'Email', email),
            _infoRow(Icons.schedule, 'Consultation Hours', '09:00 AM - 05:00 PM (Mon-Sat)'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAvailable
                    ? () {
                        Navigator.pop(ctx);
                        _showBookAppointmentSheet(context, d['id'] ?? '', d);
                      }
                    : null,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Book Appointment with Doctor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.teal[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateSlotId(String doctorId, String date, String time) {
    final cleanDoc = doctorId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cleanDate = date.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cleanTime = time.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'slot_${cleanDoc}_${cleanDate}_$cleanTime';
  }

  void _showBookAppointmentSheet(
    BuildContext context,
    String doctorDocId,
    Map<String, dynamic> doctorData,
  ) {
    final doctorName = doctorData['name']?.toString() ?? 'Doctor';
    final specialization = doctorData['specialization']?.toString() ?? 'General';
    final reasonController = TextEditingController();
    final notesController = TextEditingController();

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedTime = '10:00 AM';
    bool isSubmitting = false;
    Set<String> bookedSlots = {};
    bool initialSlotsLoaded = false;

    final List<String> timeSlots = [
      '09:00 AM',
      '10:00 AM',
      '11:00 AM',
      '11:30 AM',
      '02:00 PM',
      '03:00 PM',
      '04:00 PM',
      '05:00 PM',
    ];

    Future<void> fetchBookedSlots(
      DateTime date,
      void Function(void Function()) setSheetState,
    ) async {
      try {
        final formattedDate =
            '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
        final snap = await _db
            .collection('appointment_slots')
            .where('doctorId', isEqualTo: doctorDocId)
            .where('date', isEqualTo: formattedDate)
            .get();
        final booked = snap.docs.map((d) => d.data()['time']?.toString() ?? '').toSet();
        setSheetState(() {
          bookedSlots = booked;
        });
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!initialSlotsLoaded) {
              initialSlotsLoaded = true;
              fetchBookedSlots(selectedDate, setSheetState);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.event_note, color: Colors.teal[700]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Book Appointment',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$doctorName • $specialization',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Date picker section
                    const Text(
                      'Select Date',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                          fetchBookedSlots(picked, setSheetState);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Colors.teal[700]),
                            const SizedBox(width: 10),
                            Text(
                              '${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Text(
                              'Change',
                              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time slots section
                    const Text(
                      'Select Time Slot',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timeSlots.map((slot) {
                        final isSlotSelected = selectedTime == slot;
                        final isBooked = bookedSlots.contains(slot);
                        return ChoiceChip(
                          label: Text(isBooked ? '$slot (Booked)' : slot),
                          selected: isSlotSelected && !isBooked,
                          onSelected: isBooked ? null : (_) => setSheetState(() => selectedTime = slot),
                          selectedColor: Colors.teal[700],
                          disabledColor: Colors.grey[200],
                          labelStyle: TextStyle(
                            color: isBooked
                                ? Colors.grey[400]
                                : (isSlotSelected ? Colors.white : Colors.black87),
                            fontWeight: isSlotSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                            decoration: isBooked ? TextDecoration.lineThrough : null,
                          ),
                          backgroundColor: Colors.grey[100],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Reason for visit
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason for Visit / Symptoms *',
                        hintText: 'e.g. Regular health checkup, headache, fever...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.edit_note),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Additional notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        hintText: 'Any allergies, past medication, or special requests...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.notes),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final reason = reasonController.text.trim();
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a reason for the visit')),
                                  );
                                  return;
                                }

                                if (bookedSlots.contains(selectedTime)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('This time slot is no longer available. Please select another time.'),
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);

                                try {
                                  final currentUser = FirebaseAuth.instance.currentUser;
                                  if (currentUser == null) {
                                    throw Exception('User authentication session expired. Please log in again.');
                                  }
                                  final authUid = currentUser.uid;
                                  final patientEmail = currentUser.email ?? _resolvedPatientEmail;
                                  final patientName = _resolvedPatientName.isNotEmpty
                                      ? _resolvedPatientName
                                      : (currentUser.displayName ?? 'Patient');

                                  final formattedDate =
                                      '${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}';

                                  final slotId = _generateSlotId(doctorDocId, formattedDate, selectedTime);
                                  final slotDocRef = _db.collection('appointment_slots').doc(slotId);
                                  final apptDocRef = _db.collection('appointments').doc();

                                  // SERVER-AUTHORITATIVE ATOMIC TRANSACTION:
                                  // Atomically reserves the slot lock and creates the appointment.
                                  // If another transaction claimed this slot first, this transaction aborts cleanly.
                                  await _db.runTransaction((transaction) async {
                                    final slotSnapshot = await transaction.get(slotDocRef);
                                    if (slotSnapshot.exists) {
                                      throw Exception('This time slot is no longer available. Please select another time.');
                                    }

                                    // 1. Establish the atomic slot reservation
                                    transaction.set(slotDocRef, {
                                      'doctorId': doctorDocId,
                                      'doctorName': doctorName,
                                      'date': formattedDate,
                                      'time': selectedTime,
                                      'patientId': authUid,
                                      'appointmentId': apptDocRef.id,
                                      'status': 'active',
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    // 2. Establish the appointment record
                                    transaction.set(apptDocRef, {
                                      'doctorId': doctorDocId,
                                      'doctorName': doctorName,
                                      'specialty': specialization,
                                      'patientId': authUid,
                                      'patientName': patientName,
                                      'patientEmail': patientEmail,
                                      'date': formattedDate,
                                      'time': selectedTime,
                                      'reason': reason,
                                      'notes': notesController.text.trim(),
                                      'status': 'Scheduled',
                                      'slotId': slotId,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                  });

                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Appointment booked with $doctorName!'),
                                        backgroundColor: Colors.teal[700],
                                        action: SnackBarAction(
                                          label: 'View',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PatAppointmentsPage(
                                                  patientId: authUid,
                                                  patientName: patientName,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  final errorStr = e.toString();
                                  final isSlotTaken = errorStr.contains('no longer available');
                                  final userMsg = isSlotTaken
                                      ? 'This time slot is no longer available. Please select another time.'
                                      : 'Booking failed: $e';

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(userMsg),
                                        backgroundColor: Colors.red[700],
                                      ),
                                    );
                                  }
                                  fetchBookedSlots(selectedDate, setSheetState);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Confirm & Book Appointment',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    );
  }
}
