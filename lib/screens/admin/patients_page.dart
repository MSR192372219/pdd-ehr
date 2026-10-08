import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/patient_service.dart';
import '../../utils/firestore_helper.dart';

class AdminPatientsPage extends StatefulWidget {
  const AdminPatientsPage({super.key});

  @override
  State<AdminPatientsPage> createState() => _AdminPatientsPageState();
}

class _AdminPatientsPageState extends State<AdminPatientsPage> {
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
        title: const Text('Manage Patients', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.blue[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search patients by name, email or phone...',
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
              stream: _db.collection('patients').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Unable to load patients. Please try again later.'),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['name']?.toString().toLowerCase() ?? '';
                    final email = d['email']?.toString().toLowerCase() ?? '';
                    final phone = d['phone']?.toString().toLowerCase() ?? '';
                    final pId = d['patientId']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery) ||
                        pId.contains(_searchQuery);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No patients match your search' : 'No patients yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Tap + Add Patient to register a patient',
                            style: TextStyle(color: Colors.grey),
                          ),
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
                    return _patientCard(context, doc.id, d);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPatientDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  Widget _patientCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Unknown';
    final patientId = d['patientId']?.toString() ?? 'Pending';
    final age = d['age']?.toString() ?? 'N/A';
    final phone = d['phone']?.toString() ?? '';
    final email = d['email']?.toString() ?? '';
    final blood = d['bloodGroup']?.toString() ?? '';
    final gender = d['gender']?.toString() ?? '';
    final uid = d['uid']?.toString() ?? '';
    final status = d['status']?.toString() ?? 'active';

    final hasAuthAccount = uid.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: status == 'active' ? Colors.blue[50] : Colors.grey[200],
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: status == 'active' ? Colors.blue[700] : Colors.grey[600],
                fontSize: 18,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  patientId,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
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
                'Age: $age${gender.isNotEmpty ? ' • $gender' : ''}${blood.isNotEmpty ? ' • $blood' : ''}',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              if (email.isNotEmpty)
                Text(
                  '📧 $email',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              if (phone.isNotEmpty)
                Text(
                  '📞 $phone',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              const SizedBox(height: 4),
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
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Provision Login',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'edit') _showEditPatientDialog(context, docId: docId, existing: d);
              if (val == 'provision' && !hasAuthAccount) _showProvisionAuthDialog(context, docId, d);
              if (val == 'delete') _confirmDelete(context, docId, name, uid);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Details')]),
              ),
              if (!hasAuthAccount)
                const PopupMenuItem(
                  value: 'provision',
                  child: Row(children: [Icon(Icons.key, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Provision Login Account')]),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete Patient', style: TextStyle(color: Colors.red))]),
              ),
            ],
          ),
          onTap: () => _showPatientDetails(context, d),
        ),
      ),
    );
  }

  void _showPatientDetails(BuildContext context, Map<String, dynamic> d) {
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
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    (d['name']?.toString() ?? 'P').substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 22, color: Colors.blue[700], fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['name']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Patient ID: ${d['patientId'] ?? 'N/A'}', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow(Icons.fingerprint, 'Firebase UID', d['uid']?.toString() ?? 'Not Linked'),
            _detailRow(Icons.email, 'Email', d['email']?.toString() ?? 'N/A'),
            _detailRow(Icons.phone, 'Phone', d['phone']?.toString() ?? 'N/A'),
            _detailRow(Icons.cake, 'Age', d['age']?.toString() ?? 'N/A'),
            _detailRow(Icons.person, 'Gender', d['gender']?.toString() ?? 'N/A'),
            _detailRow(Icons.bloodtype, 'Blood Group', d['bloodGroup']?.toString() ?? 'N/A'),
            _detailRow(Icons.location_on, 'Address', d['address']?.toString() ?? 'N/A'),
            _detailRow(Icons.verified_user, 'Account Status', d['status']?.toString() ?? 'active'),
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
          Icon(icon, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// Dialog to CREATE a new patient (with Firebase Auth user + Firestore profile)
  void _showAddPatientDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Patient@123'); // Default suggested temporary password
    final phoneCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final bloodCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String gender = 'Male';
    bool isLoading = false;
    bool hidePass = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 10),
              Text('Add New Patient'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Creates Firebase Auth account & Firestore profile automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                _field(nameCtrl, 'Full Name *', Icons.person),
                const SizedBox(height: 10),
                _field(emailCtrl, 'Email Address *', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: hidePass,
                  decoration: InputDecoration(
                    labelText: 'Initial Temporary Password *',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(hidePass ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setStateDialog(() => hidePass = !hidePass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                _field(phoneCtrl, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _field(ageCtrl, 'Age', Icons.cake, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                const Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: ['Male', 'Female', 'Other'].map((g) => ChoiceChip(
                    label: Text(g),
                    selected: gender == g,
                    onSelected: (_) => setStateDialog(() => gender = g),
                  )).toList(),
                ),
                const SizedBox(height: 10),
                _field(bloodCtrl, 'Blood Group (e.g. O+)', Icons.bloodtype),
                const SizedBox(height: 10),
                _field(addressCtrl, 'Address', Icons.location_on),
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
                      if (nameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          passwordCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name, email, and password are required.')),
                        );
                        return;
                      }

                      setStateDialog(() => isLoading = true);

                      try {
                        final result = await PatientService.createPatientWithAuth(
                          name: nameCtrl.text,
                          email: emailCtrl.text,
                          password: passwordCtrl.text,
                          phone: phoneCtrl.text,
                          age: ageCtrl.text,
                          gender: gender,
                          bloodGroup: bloodCtrl.text,
                          address: addressCtrl.text,
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
                              content: Text('Failed to create patient: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '')}'),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Patient Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Provision Auth account for existing patient records (srinu, Rahul Kumar, varun)
  void _showProvisionAuthDialog(BuildContext context, String docId, Map<String, dynamic> existing) {
    final emailCtrl = TextEditingController(text: existing['email'] ?? '');
    final passwordCtrl = TextEditingController(text: 'Patient@123');
    bool isLoading = false;
    bool hidePass = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Provision Login for ${existing['name'] ?? "Patient"}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This patient record does not have a Firebase Auth account linked. Provisioning will create an authentication account so the patient can log in.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _field(emailCtrl, 'Patient Email *', Icons.email, keyboardType: TextInputType.emailAddress),
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
                        final result = await PatientService.provisionAuthForExistingPatient(
                          existingDocId: docId,
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
    required PatientAccountResult result,
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
              'Patient Account Created Successfully',
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
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _confirmRow('Patient Name', result.name),
                    _confirmRow('Patient ID', result.patientId, isBold: true),
                    _confirmRow('Email', result.email),
                    _confirmRow('Role', 'patient'),
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
                          'Patient Login Credentials',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('• Email: ${result.email}', style: const TextStyle(fontSize: 13)),
                    Text('• Password: $temporaryPassword', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      'Provide these credentials to the patient. They can log in immediately on the Patient Login screen. No plaintext password is saved in Firestore.',
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
                text: 'Patient Name: ${result.name}\nPatient ID: ${result.patientId}\nEmail: ${result.email}\nPassword: $temporaryPassword',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
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

  void _showEditPatientDialog(BuildContext context, {required String docId, required Map<String, dynamic> existing}) {
    final nameCtrl = TextEditingController(text: existing['name'] ?? '');
    final ageCtrl = TextEditingController(text: existing['age']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing['email'] ?? '');
    final bloodCtrl = TextEditingController(text: existing['bloodGroup'] ?? '');
    final addressCtrl = TextEditingController(text: existing['address'] ?? '');
    String gender = existing['gender'] ?? 'Male';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Edit Patient Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Full Name', Icons.person),
                const SizedBox(height: 10),
                _field(ageCtrl, 'Age', Icons.cake, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['Male', 'Female', 'Other'].map((g) => ChoiceChip(
                    label: Text(g),
                    selected: gender == g,
                    onSelected: (_) => setStateDialog(() => gender = g),
                  )).toList(),
                ),
                _field(phoneCtrl, 'Phone', Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _field(emailCtrl, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(bloodCtrl, 'Blood Group', Icons.bloodtype),
                const SizedBox(height: 10),
                _field(addressCtrl, 'Address', Icons.location_on),
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

                final updatedData = {
                  'name': nameCtrl.text.trim(),
                  'age': ageCtrl.text.trim(),
                  'gender': gender,
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'bloodGroup': bloodCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                };

                try {
                  await PatientService.updatePatient(
                    docId: docId,
                    data: updatedData,
                    linkedUid: existing['uid']?.toString(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Patient updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating patient: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
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

  Future<void> _confirmDelete(BuildContext context, String docId, String name, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text('Are you sure you want to delete "$name"? If medical records or appointments exist, the account will be safely archived (marked inactive) to preserve history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete / Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PatientService.safeDeletePatient(docId, uid: uid.isNotEmpty ? uid : null);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient status updated / deleted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
