import 'package:flutter/material.dart';

void main() => runApp(const TemujanjiApp());

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

  void _hantar() {
    if (_nama.text.isEmpty || _telefon.text.isEmpty || _tarikh == null || _masa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila lengkapkan semua maklumat')),
      );
      return;
    }
    final t = '${_tarikh!.day}/${_tarikh!.month}/${_tarikh!.year}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Temujanji Disimpan'),
        content: Text('${_nama.text}\n$t, $_masa'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tempah Temujanji')),
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
            label: Text(_tarikh == null ? 'Pilih tarikh' : '${_tarikh!.day}/${_tarikh!.month}/${_tarikh!.year}'),
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