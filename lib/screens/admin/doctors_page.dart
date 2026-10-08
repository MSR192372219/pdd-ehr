import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/doctor_service.dart';
import '../../utils/firestore_helper.dart';

class AdminDoctorsPage extends StatefulWidget {
  const AdminDoctorsPage({super.key});

  @override
  State<AdminDoctorsPage> createState() => _AdminDoctorsPageState();
}

class _AdminDoctorsPageState extends State<AdminDoctorsPage> {
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
        title: const Text('Manage Doctors', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.green[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search doctors, email or specialization...',
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
              stream: _db.collection('doctors').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Unable to load doctors. Please try again later.'),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['name']?.toString().toLowerCase() ?? '';
                    final spec = d['specialization']?.toString().toLowerCase() ?? '';
                    final email = d['email']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery) ||
                        spec.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No doctors match your search' : 'No doctors yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Tap + to add the first doctor', style: TextStyle(color: Colors.grey)),
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
                    return _doctorCard(context, doc.id, d);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDoctorDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Doctor'),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  Widget _doctorCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Unknown';
    final specialization = d['specialization']?.toString() ?? 'General';
    final department = d['department']?.toString() ?? '';
    final available = d['available'] == true;
    final phone = d['phone']?.toString() ?? '';
    final email = d['email']?.toString() ?? '';
    final uid = d['uid']?.toString() ?? '';

    final hasAuthAccount = uid.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.green[50],
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'D',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 18),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: available ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                available ? 'Available' : 'Unavailable',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: available ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$specialization${department.isNotEmpty ? ' • $department' : ''}${phone.isNotEmpty ? '\n📞 $phone' : ''}',
            ),
            if (email.isNotEmpty)
              Text(
                '📧 $email',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasAuthAccount ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasAuthAccount ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 12,
                        color: hasAuthAccount ? Colors.green[700] : Colors.orange[800],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasAuthAccount ? 'Auth Account Linked' : 'No Auth Account',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasAuthAccount ? Colors.green[800] : Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasAuthAccount) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showProvisionAuthDialog(context, docId, d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Provision Login',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') _showDoctorDialog(context, docId: docId, existing: d);
            if (val == 'provision' && !hasAuthAccount) _showProvisionAuthDialog(context, docId, d);
            if (val == 'toggle') _toggleAvailability(docId, available);
            if (val == 'delete') _confirmDelete(context, docId, name);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
            ),
            if (!hasAuthAccount)
              const PopupMenuItem(
                value: 'provision',
                child: Row(
                  children: [
                    Icon(Icons.key, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text('Provision Login Account'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(available ? Icons.block : Icons.check_circle, size: 18),
                const SizedBox(width: 8),
                Text(available ? 'Mark Unavailable' : 'Mark Available'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
        onTap: () => _showDoctorDetails(context, docId, d),
      ),
    );
  }

  void _showDoctorDetails(BuildContext context, String docId, Map<String, dynamic> d) {
    final available = d['available'] == true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green[100],
                  child: Text(
                    (d['name']?.toString() ?? 'D').substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 22, color: Colors.green[700], fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['name']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(d['specialization']?.toString() ?? 'General', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow(Icons.badge, 'Doctor ID', docId),
            _detailRow(Icons.fingerprint, 'Firebase UID', d['uid']?.toString() ?? 'Not Linked'),
            _detailRow(Icons.email, 'Email', d['email']?.toString() ?? 'N/A'),
            _detailRow(Icons.phone, 'Phone', d['phone']?.toString() ?? 'N/A'),
            _detailRow(Icons.business, 'Department', d['department']?.toString() ?? 'N/A'),
            _detailRow(Icons.work, 'Experience', '${d['experience'] ?? 'N/A'} years'),
            _detailRow(Icons.event_available, 'Availability', available ? 'Available' : 'Unavailable'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green[700]),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// Provision Auth account for existing doctor record
  void _showProvisionAuthDialog(BuildContext context, String docId, Map<String, dynamic> existing) {
    final emailCtrl = TextEditingController(text: existing['email'] ?? '');
    final passwordCtrl = TextEditingController(text: 'Doctor@123');
    bool isLoading = false;
    bool hidePass = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Provision Login for ${existing['name'] ?? "Doctor"}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This doctor record does not have a Firebase Auth account linked. Provisioning will create an authentication account so the doctor can log in to the Doctor Portal.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _field(emailCtrl, 'Doctor Email *', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: hidePass,
                  decoration: InputDecoration(
                    labelText: 'Temporary Password *',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(hidePass ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setStateDialog(() => hidePass = !hidePass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email and password are required.')),
                        );
                        return;
                      }

                      setStateDialog(() => isLoading = true);

                      try {
                        final result = await DoctorService.provisionAuthForExistingDoctor(
                          doctorDocId: docId,
                          email: emailCtrl.text,
                          password: passwordCtrl.text,
                          existingData: existing,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (context.mounted) {
                          _showAccountConfirmationModal(
                            context,
                            result: result,
                            temporaryPassword: passwordCtrl.text.trim(),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to provision account: $e'),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Provision Auth Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Prominent Account Confirmation Dialog
  void _showAccountConfirmationModal(
    BuildContext context, {
    required DoctorAccountResult result,
    required String temporaryPassword,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 54),
            const SizedBox(height: 10),
            const Text(
              'Doctor Account Created Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _confirmRow('Doctor Name', result.name),
                    _confirmRow('Doctor ID', result.doctorId, isBold: true),
                    _confirmRow('Email', result.email),
                    _confirmRow('Specialization', result.specialization),
                    _confirmRow('Role', 'doctor'),
                    _confirmRow('Status', result.status.toUpperCase()),
                    _confirmRow('Firebase UID', result.uid),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.amber[900], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Doctor Login Credentials',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('• Email: ${result.email}', style: const TextStyle(fontSize: 13)),
                    Text('• Password: $temporaryPassword', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      'Provide these credentials to the doctor. They can log in immediately on the Doctor Login screen. No plaintext password is saved in Firestore. Please advise the doctor to change their password securely after first login.',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Doctor Name: ${result.name}\nDoctor ID: ${result.doctorId}\nEmail: ${result.email}\nPassword: $temporaryPassword\nRole: Doctor',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credentials copied to clipboard!')),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 16),
                SizedBox(width: 4),
                Text('Copy Credentials'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAvailability(String docId, bool current) async {
    await _db.collection('doctors').doc(docId).update({'available': !current});
  }

  void _showDoctorDialog(BuildContext context, {String? docId, Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final specCtrl = TextEditingController(text: existing?['specialization'] ?? '');
    final deptCtrl = TextEditingController(text: existing?['department'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final expCtrl = TextEditingController(text: existing?['experience']?.toString() ?? '');
    bool available = existing?['available'] ?? true;
    final isEdit = docId != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Doctor' : 'Add Doctor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Full Name', Icons.person),
                const SizedBox(height: 10),
                _field(specCtrl, 'Specialization', Icons.medical_services),
                const SizedBox(height: 10),
                _field(deptCtrl, 'Department', Icons.business),
                const SizedBox(height: 10),
                _field(phoneCtrl, 'Phone', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _field(emailCtrl, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(expCtrl, 'Experience (years)', Icons.work, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: available,
                  onChanged: (v) => setStateDialog(() => available = v),
                  title: const Text('Available'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                final data = {
                  'name': nameCtrl.text.trim(),
                  'specialization': specCtrl.text.trim(),
                  'department': deptCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim().toLowerCase(),
                  'experience': expCtrl.text.trim(),
                  'available': available,
                  if (!isEdit) 'createdAt': FieldValue.serverTimestamp(),
                };
                try {
                  if (isEdit) {
                    await DoctorService.updateDoctor(
                      docId: docId,
                      data: data,
                      linkedUid: existing?['uid']?.toString(),
                    );
                  } else {
                    await _db.collection('doctors').add(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Doctor updated!' : 'Doctor added!')),
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
        title: const Text('Delete Doctor'),
        content: Text('Are you sure you want to delete "$name"? This cannot be undone.'),
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
        await _db.collection('doctors').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
