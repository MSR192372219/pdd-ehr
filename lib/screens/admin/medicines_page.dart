import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/firestore_helper.dart';

class AdminMedicinesPage extends StatefulWidget {
  const AdminMedicinesPage({super.key});

  @override
  State<AdminMedicinesPage> createState() => _AdminMedicinesPageState();
}

class _AdminMedicinesPageState extends State<AdminMedicinesPage> {
  FirebaseFirestore get _db => FirestoreHelper.db;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const int _lowStockThreshold = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.purple[700],
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search medicines or category...',
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
              stream: _db.collection('medicines').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Unable to load medicines. Please try again later.'),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['name']?.toString().toLowerCase() ?? '';
                    final category = d['category']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery) || category.contains(_searchQuery);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_pharmacy_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No medicines match your search' : 'No medicines yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Tap + to add the first medicine', style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  );
                }

                final lowStockCount = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final qty = int.tryParse(d['quantity']?.toString() ?? '') ?? 0;
                  return qty <= _lowStockThreshold;
                }).length;

                return Column(
                  children: [
                    if (lowStockCount > 0)
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.red),
                            const SizedBox(width: 10),
                            Text(
                              '$lowStockCount medicine${lowStockCount > 1 ? 's' : ''} with low stock (≤$_lowStockThreshold)',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final d = doc.data() as Map<String, dynamic>;
                          return _medicineCard(context, doc.id, d);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMedicineDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
        backgroundColor: Colors.purple[700],
      ),
    );
  }

  Widget _medicineCard(BuildContext context, String docId, Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? 'Unknown';
    final category = d['category']?.toString() ?? '';
    final quantity = int.tryParse(d['quantity']?.toString() ?? '0') ?? 0;
    final expiry = d['expiryDate']?.toString() ?? '';
    final isLowStock = quantity <= _lowStockThreshold;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isLowStock ? Colors.red[50] : Colors.purple[50],
          child: Icon(
            Icons.medication,
            color: isLowStock ? Colors.red : Colors.purple[700],
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (isLowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Low Stock',
                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${category.isNotEmpty ? 'Category: $category\n' : ''}Stock: $quantity units${expiry.isNotEmpty ? ' • Expiry: $expiry' : ''}',
        ),
        isThreeLine: category.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') _showMedicineDialog(context, docId: docId, existing: d);
            if (val == 'delete') _confirmDelete(context, docId, name);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
            PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  void _showMedicineDialog(BuildContext context, {String? docId, Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final categoryCtrl = TextEditingController(text: existing?['category'] ?? '');
    final quantityCtrl = TextEditingController(text: existing?['quantity']?.toString() ?? '');
    final expiryCtrl = TextEditingController(text: existing?['expiryDate'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final isEdit = docId != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameCtrl, 'Medicine Name', Icons.medication),
              const SizedBox(height: 10),
              _field(categoryCtrl, 'Category (e.g. Antibiotic)', Icons.category),
              const SizedBox(height: 10),
              _field(quantityCtrl, 'Quantity / Stock', Icons.inventory_2, keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _field(expiryCtrl, 'Expiry Date (MM/YYYY)', Icons.calendar_month),
              const SizedBox(height: 10),
              _field(descCtrl, 'Description / Notes', Icons.notes),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine name is required')));
                return;
              }
              final data = {
                'name': nameCtrl.text.trim(),
                'category': categoryCtrl.text.trim(),
                'quantity': int.tryParse(quantityCtrl.text.trim()) ?? 0,
                'expiryDate': expiryCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                if (!isEdit) 'createdAt': FieldValue.serverTimestamp(),
              };
              try {
                if (isEdit) {
                  await _db.collection('medicines').doc(docId).update(data);
                } else {
                  await _db.collection('medicines').add(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Medicine updated!' : 'Medicine added!')),
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
        title: const Text('Delete Medicine'),
        content: Text('Delete "$name"? This cannot be undone.'),
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
        await _db.collection('medicines').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
