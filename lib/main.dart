import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? error;
  try {
    const id = String.fromEnvironment('FIREBASE_PROJECT_ID');
    await Firebase.initializeApp(
      options: id.isEmpty
          ? null
          : const FirebaseOptions(
              projectId: id,
              apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
              appId: String.fromEnvironment('FIREBASE_APP_ID'),
              messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
            ),
    );
  } catch (e) {
    error =
        'Firebase setup required. Check the class app configuration and restart.\n$e';
  }
  runApp(
    MaterialApp(
      title: 'Stock Inventory Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff087368),
        scaffoldBackgroundColor: const Color(0xfff4f8f6),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: Inventory(setupError: error),
    ),
  );
}

const categories = ['Electronics', 'Stationery', 'Hardware', 'Grocery'];

class Inventory extends StatefulWidget {
  final String? setupError;
  const Inventory({super.key, this.setupError});
  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  final form = GlobalKey<FormState>();
  final values = <String, dynamic>{};
  late final items = FirebaseFirestore.instance.collection('stockItems');
  late final records = items.snapshots();
  final search = TextEditingController();
  int page = 0;
  String category = 'All';
  bool low = false, ascending = true, saving = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    form.currentState!.save();
    if (widget.setupError != null) {
      message('Configure Firebase before saving.');
      return;
    }
    setState(() => saving = true);
    try {
      await items.add({...values, 'createdAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      form.currentState!.reset();
      message('Item saved to Firestore.');
    } catch (e) {
      if (mounted) message('Save failed: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget field(String key, String label) {
    final numeric = ['quantity', 'unitPrice', 'reorderLevel'].contains(key);
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: key == 'unitPrice')
          : TextInputType.text,
      validator: (raw) {
        final s = raw?.trim() ?? '';
        if (key == 'sku' && !RegExp(r'^STK-[0-9]{3}$').hasMatch(s)) {
          return 'Use STK- followed by three digits.';
        }
        if (key == 'itemName' && s.length < 3) {
          return 'Enter at least three characters.';
        }
        if (key == 'unitPrice') {
          final n = double.tryParse(s);
          if (n == null || !n.isFinite || n <= 0) {
            return 'Enter a price greater than zero.';
          }
        } else if (numeric &&
            (!RegExp(r'^[0-9]+$').hasMatch(s) || int.tryParse(s) == null)) {
          return 'Enter a whole number of zero or more.';
        }
        return null;
      },
      onSaved: (raw) {
        final s = raw!.trim();
        values[key] = key == 'unitPrice'
            ? double.parse(s)
            : numeric
            ? int.parse(s)
            : s;
      },
    );
  }

  String formatCreatedAt(Object? value) {
    if (value is! Timestamp) return 'Awaiting timestamp';
    final malaysiaTime = value.toDate().toUtc().add(const Duration(hours: 8));
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(malaysiaTime);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '$date, ${twoDigits(malaysiaTime.hour)}:${twoDigits(malaysiaTime.minute)}:${twoDigits(malaysiaTime.second)} MYT';
  }

  Widget inventoryList() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: records,
    builder: (context, snap) {
      if (snap.hasError) return Text('Could not load inventory: ${snap.error}');
      if (!snap.hasData) return const LinearProgressIndicator();
      final keyword = search.text.trim().toLowerCase();
      final all = snap.data!.docs;
      final shown =
          all
              .map((doc) => doc.data())
              .where(
                (d) =>
                    (category == 'All' || category == d['category']) &&
                    (!low || d['quantity'] <= d['reorderLevel']) &&
                    [
                      d['itemName'],
                      d['sku'],
                    ].any((s) => s.toString().toLowerCase().contains(keyword)),
              )
              .toList()
            ..sort(
              (a, b) =>
                  (ascending ? 1 : -1) *
                  (a['quantity'] as num).compareTo(b['quantity']),
            );
      if (shown.isEmpty) {
        return Text(
          all.isEmpty
              ? 'Inventory is empty. Save your first item.'
              : 'No items match these filters.',
        );
      }
      return Column(
        children: shown
            .map(
              (d) => Card(
                child: ListTile(
                  title: Text('${d["itemName"]} · ${d["sku"]}'),
                  subtitle: Text(
                    '${d["category"]} · RM ${(d["unitPrice"] as num).toStringAsFixed(2)}\nQuantity ${d["quantity"]} · Reorder level ${d["reorderLevel"]}\nCreated at: ${formatCreatedAt(d["createdAt"])}',
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget pageBody(String title, String description, List<Widget> children) {
    return ListView(
      key: PageStorageKey(title),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(description),
        const SizedBox(height: 18),
        if (widget.setupError != null) Text(widget.setupError!),
        ...children,
      ],
    );
  }

  Widget panel(Widget content) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xffd8e5df)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: content),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xff104c46),
      foregroundColor: Colors.white,
      leading: const Icon(Icons.inventory_2_outlined),
      title: const Text('Stock Inventory Manager'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (index) => setState(() => page = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.note_add_outlined),
          label: 'Stock entry',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Inventory',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: IndexedStack(
          index: page,
          children: [
            pageBody(
              'Stock entry',
              'Enter the item details to add it to your inventory.',
              [
                panel(
                  AbsorbPointer(
                    absorbing: saving,
                    child: Form(
                      key: form,
                      child: Column(
                        spacing: 14,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field('sku', 'SKU'),
                          field('itemName', 'Item name'),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (_) {},
                            onSaved: (v) => values['category'] = v,
                            validator: (v) =>
                                v == null ? 'Choose a category.' : null,
                          ),
                          field('quantity', 'Quantity'),
                          field('unitPrice', 'Unit price (RM)'),
                          field('reorderLevel', 'Reorder level'),
                          FilledButton(
                            onPressed: saving ? null : save,
                            child: Text(saving ? 'Saving…' : 'Save Item'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pageBody(
              'Inventory',
              'Search saved items and check which ones need reordering.',
              [
                panel(
                  Column(
                    spacing: 12,
                    children: [
                      TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          labelText: 'Search name or SKU',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Filter category',
                        ),
                        child: DropdownButton<String>(
                          value: category,
                          items: ['All', ...categories]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => category = v!),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Low stock only'),
                        value: low,
                        onChanged: (v) => setState(() => low = v),
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => ascending = !ascending),
                            child: Text(
                              ascending
                                  ? 'Quantity: ascending'
                                  : 'Quantity: descending',
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              search.clear();
                              category = 'All';
                              low = false;
                              ascending = true;
                            }),
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.setupError == null) inventoryList(),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
