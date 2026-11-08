import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TemujanjiApp());

String formatTarikh(DateTime d) => '${d.day}/${d.month}/${d.year}';

class TemujanjiApp extends StatelessWidget {
  const TemujanjiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temujanji Pesakit',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const TempahPage(),
    );
  }
}

class TempahPage extends StatefulWidget {
  const TempahPage({super.key});

  @override
  State<TempahPage> createState() => _TempahPageState();
}

class _TempahPageState extends State<TempahPage> {
  final _nama = TextEditingController();
  final _telefon = TextEditingController();
  DateTime? _tarikh;
  String? _masa;
  final _slot = ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];

  Future<void> _pilihTarikh() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _tarikh = d);
  }

  Future<void> _hantar() async {
    if (_nama.text.isEmpty || _telefon.text.isEmpty || _tarikh == null || _masa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila lengkapkan semua maklumat')),
      );
      return;
    }
    final nama = _nama.text;
    final masa = _masa;
    final t = formatTarikh(_tarikh!);

    final prefs = await SharedPreferences.getInstance();
    final senarai = prefs.getStringList('temujanji') ?? [];
    senarai.add(jsonEncode({
      'nama': nama,
      'telefon': _telefon.text,
      'tarikh': _tarikh!.toIso8601String(),
      'masa': masa,
    }));
    await prefs.setStringList('temujanji', senarai);

    if (!mounted) return;
    _nama.clear();
    _telefon.clear();
    setState(() {
      _tarikh = null;
      _masa = null;
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Temujanji Disimpan'),
        content: Text('$nama\n$t, $masa\n\nJumlah tersimpan: ${senarai.length}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tempah Temujanji'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Senarai temujanji',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SenaraiPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nama, decoration: const InputDecoration(labelText: 'Nama pesakit', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _telefon, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. telefon', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pilihTarikh,
            icon: const Icon(Icons.calendar_today),
            label: Text(_tarikh == null ? 'Pilih tarikh' : formatTarikh(_tarikh!)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _masa,
            decoration: const InputDecoration(labelText: 'Masa', border: OutlineInputBorder()),
            items: _slot.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _masa = v),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _hantar, child: const Text('Tempah')),
        ],
      ),
    );
  }
}

class SenaraiPage extends StatefulWidget {
  const SenaraiPage({super.key});

  @override
  State<SenaraiPage> createState() => _SenaraiPageState();
}

class _SenaraiPageState extends State<SenaraiPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('temujanji') ?? [];
    final items = raw.map((r) {
      final m = jsonDecode(r) as Map<String, dynamic>;
      m['raw'] = r;
      return m;
    }).toList();
    items.sort((a, b) {
      final c = (a['tarikh'] as String).compareTo(b['tarikh'] as String);
      return c != 0 ? c : (a['masa'] as String).compareTo(b['masa'] as String);
    });
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _padam(Map<String, dynamic> item) async {
    final sah = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Padam temujanji?'),
        content: Text('${item['nama']}\n${formatTarikh(DateTime.parse(item['tarikh']))}, ${item['masa']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Padam')),
        ],
      ),
    );
    if (sah != true) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('temujanji') ?? [];
    raw.remove(item['raw']);
    await prefs.setStringList('temujanji', raw);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Senarai Temujanji (${_items.length})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Tiada temujanji lagi'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    final t = formatTarikh(DateTime.parse(it['tarikh']));
                    return ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(it['nama']),
                      subtitle: Text('$t, ${it['masa']}\n${it['telefon']}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _padam(it),
                      ),
                    );
                  },
                ),
    );
  }
}