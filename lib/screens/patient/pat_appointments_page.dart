import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';
import 'pat_doctors_page.dart';

class PatAppointmentsPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatAppointmentsPage({
    super.key,
    this.patientId = '',
    this.patientName = 'Patient',
  });

  @override
  State<PatAppointmentsPage> createState() => _PatAppointmentsPageState();
}

class _PatAppointmentsPageState extends State<PatAppointmentsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;

  late String _currentUid;
  String _filterStatus = 'All';

  final List<String> _statuses = ['All', 'Scheduled', 'Booked', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _currentUid = currentUser?.uid ?? widget.patientId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FA),
      appBar: AppBar(
        title: const Text(
          'My Appointments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatDoctorsPage(
                patientId: _currentUid,
                patientName: widget.patientName,
              ),
            ),
          );
        },
        backgroundColor: Colors.purple[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Book Appointment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            color: Colors.purple[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((status) {
                  final isSelected = _filterStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _filterStatus = status),
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white24,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.purple[700] : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      checkmarkColor: Colors.purple[700],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Appointments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _currentUid.isNotEmpty
                  ? _db
                      .collection('appointments')
                      .where('patientId', isEqualTo: _currentUid)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load appointments',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                // Apply status filter
                if (_filterStatus != 'All') {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['status']?.toString() == _filterStatus;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 64, color: Colors.purple[200]),
                        const SizedBox(height: 16),
                        Text(
                          _filterStatus == 'All'
                              ? 'No appointments found'
                              : 'No $_filterStatus appointments',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "+ Book Appointment" to schedule a visit',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    return _appointmentCard(context, docs[index].id, d);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final doctorName = d['doctorName']?.toString() ?? 'Doctor';
    final specialty = d['specialty']?.toString() ?? d['department']?.toString() ?? '';
    final date = d['date']?.toString() ?? 'Date TBD';
    final time = d['time']?.toString() ?? '';
    final status = d['status']?.toString() ?? 'Scheduled';
    final reason = d['reason']?.toString() ?? '';

    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.schedule;
    switch (status) {
      case 'Completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Booked':
        statusColor = Colors.orange;
        statusIcon = Icons.event;
        break;
      case 'Scheduled':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAppointmentDetails(context, docId, d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.medical_services, color: Colors.purple[700]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (specialty.isNotEmpty)
                      Text(
                        specialty,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '$date${time.isNotEmpty ? ' • $time' : ''}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
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

  void _showAppointmentDetails(BuildContext context, String docId, Map<String, dynamic> d) {
    final doctorName = d['doctorName']?.toString() ?? 'Doctor';
    final specialty = d['specialty']?.toString() ?? d['department']?.toString() ?? 'N/A';
    final date = d['date']?.toString() ?? 'N/A';
    final time = d['time']?.toString() ?? 'N/A';
    final status = d['status']?.toString() ?? 'Scheduled';
    final reason = d['reason']?.toString() ?? 'N/A';
    final notes = d['notes']?.toString() ?? '';

    final canCancel = status == 'Scheduled' || status == 'Booked';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Padding(
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
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Appointment Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.purple[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.medical_services, 'Doctor', doctorName),
            _detailRow(Icons.local_hospital, 'Specialty', specialty),
            _detailRow(Icons.calendar_today, 'Date', date),
            _detailRow(Icons.access_time, 'Time', time),
            _detailRow(Icons.note, 'Reason for Visit', reason),
            if (notes.isNotEmpty) _detailRow(Icons.notes, 'Notes', notes),
            const SizedBox(height: 16),

              if (canCancel) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    _confirmCancelAppointment(
                      context,
                      docId,
                      doctorName,
                      date,
                      d['slotId']?.toString(),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Cancel This Appointment', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(bottomSheetContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelAppointment(
    BuildContext context,
    String docId,
    String doctorName,
    String date,
    String? slotId,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text('Are you sure you want to cancel your appointment with $doctorName on $date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final apptDocRef = _db.collection('appointments').doc(docId);

                await _db.runTransaction((transaction) async {
                  transaction.update(apptDocRef, {
                    'status': 'Cancelled',
                    'cancelledAt': FieldValue.serverTimestamp(),
                  });

                  if (slotId != null && slotId.isNotEmpty) {
                    final slotDocRef = _db.collection('appointment_slots').doc(slotId);
                    transaction.delete(slotDocRef);
                  }
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment has been cancelled')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel appointment: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.purple[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
