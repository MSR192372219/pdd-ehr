import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';

  // Caches for resolved names
  final Map<String, String> _patientNames = {};
  final Map<String, String> _doctorNames = {};

  final List<String> _statuses = ['All', 'Scheduled', 'Booked', 'Completed', 'Cancelled'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Resolves a patientId to a name, using cache
  Future<String> _resolvePatientName(String? id) async {
    if (id == null || id.isEmpty) return 'Unknown Patient';
    if (_patientNames.containsKey(id)) return _patientNames[id]!;
    try {
      final doc = await _db.collection('patients').doc(id).get();
      final name = doc.exists ? (doc.data()?['name']?.toString() ?? id) : id;
      _patientNames[id] = name;
      return name;
    } catch (_) {
      return id;
    }
  }

  /// Resolves a doctorId to a name, using cache
  Future<String> _resolveDoctorName(String? id) async {
    if (id == null || id.isEmpty) return 'Unknown Doctor';
    if (_doctorNames.containsKey(id)) return _doctorNames[id]!;
    try {
      final doc = await _db.collection('doctors').doc(id).get();
      final name = doc.exists ? (doc.data()?['name']?.toString() ?? id) : id;
      _doctorNames[id] = name;
      return name;
    } catch (_) {
      return id;
    }
  }

  /// Gets the best patient name from the document — direct name or resolved from ID
  Future<String> _getPatientName(Map<String, dynamic> d) async {
    final direct = d['patientName']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return _resolvePatientName(d['patientId']?.toString());
  }

  /// Gets the best doctor name from the document
  Future<String> _getDoctorName(Map<String, dynamic> d) async {
    final direct = d['doctorName']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return _resolveDoctorName(d['doctorId']?.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.orange[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by patient or doctor...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white70),
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
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((s) {
                      final selected = _filterStatus == s;
                      return GestureDetector(
                        onTap: () => setState(() => _filterStatus = s),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              color: selected
                                  ? Colors.orange[700]
                                  : Colors.white,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('appointments').snapshots(),
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
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load appointments',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];

                if (_filterStatus != 'All') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['status']?.toString() == _filterStatus;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No appointments found',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
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
                    return _AppointmentCard(
                      docId: doc.id,
                      data: d,
                      searchQuery: _searchQuery,
                      onUpdateStatus: (newStatus) =>
                          _updateStatus(context, doc.id, newStatus),
                      getPatientName: () => _getPatientName(d),
                      getDoctorName: () => _getDoctorName(d),
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

  Future<void> _updateStatus(
      BuildContext context, String docId, String newStatus) async {
    try {
      final doc = await _db.collection('appointments').doc(docId).get();
      final slotId = doc.data()?['slotId']?.toString();

      await _db.runTransaction((transaction) async {
        transaction.update(_db.collection('appointments').doc(docId), {
          'status': newStatus,
          if (newStatus == 'Cancelled') 'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (newStatus == 'Cancelled' && slotId != null && slotId.isNotEmpty) {
          final slotDocRef = _db.collection('appointment_slots').doc(slotId);
          transaction.delete(slotDocRef);
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment marked as $newStatus')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update appointment status')),
        );
      }
    }
  }
}

class _AppointmentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String searchQuery;
  final void Function(String newStatus) onUpdateStatus;
  final Future<String> Function() getPatientName;
  final Future<String> Function() getDoctorName;

  const _AppointmentCard({
    required this.docId,
    required this.data,
    required this.searchQuery,
    required this.onUpdateStatus,
    required this.getPatientName,
    required this.getDoctorName,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'Scheduled';
    Color statusColor = Colors.orange;
    if (status == 'Completed') statusColor = Colors.green;
    if (status == 'Cancelled') statusColor = Colors.red;
    if (status == 'Scheduled') statusColor = Colors.blue;

    return FutureBuilder<List<String>>(
      future: Future.wait([getPatientName(), getDoctorName()]),
      builder: (context, snap) {
        final patientName = snap.data?[0] ?? 'Loading...';
        final doctorName = snap.data?[1] ?? 'Loading...';

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          if (!patientName.toLowerCase().contains(searchQuery) &&
              !doctorName.toLowerCase().contains(searchQuery)) {
            return const SizedBox.shrink();
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange[50],
                      child: const Icon(Icons.person, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            doctorName,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_month,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(data['date']?.toString() ?? '',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(data['time']?.toString() ?? '',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'Booked' || status == 'Scheduled') ...[
                      OutlinedButton(
                        onPressed: () => onUpdateStatus('Cancelled'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => onUpdateStatus('Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Complete',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ],
                    if (status == 'Cancelled')
                      ElevatedButton(
                        onPressed: () => onUpdateStatus('Scheduled'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Re-Book',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    if (status == 'Completed')
                      const Text(
                        '✓ Completed',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
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
