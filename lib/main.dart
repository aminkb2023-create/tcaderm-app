// pubspec.yaml -> dependencies:
//   http: ^1.2.0
//   flutter_secure_storage: ^9.2.2
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// Emulator Android: 10.0.2.2 = localhost PC. Telefon sebenar: guna URL HTTPS server.
const String baseUrl = 'http://10.0.2.2:3000';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static const _storage = FlutterSecureStorage();

  static Future<String?> get token => _storage.read(key: 'token');

  static Future<Map<String, dynamic>> _post(String path, Map body) async {
    try {
      final t = await token;
      final res = await http
          .post(Uri.parse('$baseUrl$path'),
              headers: {
                'Content-Type': 'application/json',
                if (t != null) 'Authorization': 'Bearer $t',
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw ApiException(data['error'] ?? 'Ralat');
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Tidak dapat sambung ke server');
    }
  }

  static Future<void> register(
      String nama, String ic, String telefon, String password) async {
    await _post('/register',
        {'nama': nama, 'ic': ic, 'telefon': telefon, 'password': password});
  }

  static Future<String> login(String ic, String password) async {
    final data = await _post('/login', {'ic': ic, 'password': password});
    await _storage.write(key: 'token', value: data['token']);
    return data['nama'] ?? '';
  }

  static Future<List<dynamic>> appointments() async {
    final res = await http.get(Uri.parse('$baseUrl/appointments'),
        headers: {'Authorization': 'Bearer ${await token}'});
    if (res.statusCode == 401) throw ApiException('Sila login semula');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<List<dynamic>> requests() async {
    final res = await http.get(Uri.parse('$baseUrl/requests'),
        headers: {'Authorization': 'Bearer ${await token}'});
    if (res.statusCode == 401) throw ApiException('Sila login semula');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<void> submitRequest(String ic, String sebab) async {
    await _post('/requests', {'ic': ic, 'sebab': sebab});
  }

  static Future<void> logout() => _storage.delete(key: 'token');
}

void main() => runApp(const TemujanjiApp());

class TemujanjiApp extends StatelessWidget {
  const TemujanjiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Temujanji Pesakit',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const AuthGate(),
      );
}

// Semak token tersimpan: kalau ada terus ke Home, kalau tiada ke Login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: Api.token,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return snap.data == null ? const LoginScreen() : const HomeScreen();
        },
      );
}

String? _validateIc(String? v) =>
    (v ?? '').replaceAll(RegExp(r'\D'), '').length == 12
        ? null
        : 'No. IC mesti 12 digit';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ic = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hide = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.login(_ic.text, _password.text);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  const Icon(Icons.local_hospital, size: 64),
                  const SizedBox(height: 8),
                  Text('Temujanji Pesakit',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _ic,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'No. IC (tanpa -)',
                        border: OutlineInputBorder()),
                    validator: _validateIc,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    decoration: InputDecoration(
                      labelText: 'Kata laluan',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Masukkan kata laluan' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Login'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen())),
                    child: const Text('Belum ada akaun? Daftar'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _ic = TextEditingController();
  final _telefon = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.register(_nama.text.trim(), _ic.text, _telefon.text.trim(),
          _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pendaftaran berjaya. Sila login.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(String label, TextEditingController c,
          {TextInputType? type,
          bool obscure = false,
          String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          obscureText: obscure,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          validator: validator ??
              (v) => (v ?? '').trim().isEmpty ? 'Ruangan ini wajib' : null,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Daftar Akaun')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _field('Nama penuh', _nama),
                _field('No. IC (tanpa -)', _ic,
                    type: TextInputType.number, validator: _validateIc),
                _field('No. telefon', _telefon, type: TextInputType.phone),
                _field('Kata laluan (min. 6 aksara)', _password,
                    obscure: true,
                    validator: (v) => (v ?? '').length < 6
                        ? 'Minimum 6 aksara'
                        : null),
                _field('Sahkan kata laluan', _confirm,
                    obscure: true,
                    validator: (v) =>
                        v != _password.text ? 'Kata laluan tidak sama' : null),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Daftar'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

// Skrin utama: temujanji + status permohonan
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<List<dynamic>>> _data = _load();

  Future<List<List<dynamic>>> _load() =>
      Future.wait([Api.appointments(), Api.requests()]);

  Future<void> _refresh() async {
    setState(() {
      _data = _load();
    });
    try {
      await _data;
    } catch (_) {}
  }

  Future<void> _openRequest() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const RequestScreen()));
    _refresh();
  }

  String _statusLabel(String s) => switch (s) {
        'menunggu' => 'Menunggu admin',
        'diluluskan' => 'Diluluskan',
        'ditolak' => 'Ditolak',
        _ => s,
      };

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Temujanji Saya'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Api.logout();
                if (!context.mounted) return;
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openRequest,
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Mohon temujanji baharu'),
        ),
        body: FutureBuilder<List<List<dynamic>>>(
          future: _data,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}'),
                  TextButton(
                      onPressed: _refresh, child: const Text('Cuba lagi')),
                ]),
              );
            }
            final appts = snap.data![0];
            final reqs = snap.data![1];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  _header('Temujanji'),
                  if (appts.isEmpty)
                    const ListTile(title: Text('Tiada temujanji')),
                  for (final a in appts)
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: Text('${a['tarikh']}  ${a['masa']}'),
                      subtitle: Text('${a['clinic_type']} • ${a['status']}'),
                    ),
                  _header('Permohonan temujanji baharu'),
                  if (reqs.isEmpty)
                    const ListTile(title: Text('Tiada permohonan')),
                  for (final r in reqs)
                    ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: Text(r['sebab'] == 'tukar'
                          ? 'Tukar temujanji'
                          : 'Terlepas temujanji'),
                      subtitle: Text('${r['dibuat_pada']}'),
                      trailing: Chip(label: Text(_statusLabel('${r['status']}'))),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ic = TextEditingController();
  String _sebab = 'terlepas';
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.submitRequest(_ic.text, _sebab);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permohonan dihantar. Sila tunggu admin.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mohon Temujanji Baharu')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(children: [
                const Text(
                    'Masukkan no. IC anda. Admin akan beri tarikh temujanji baharu dalam app.'),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _sebab,
                  decoration: const InputDecoration(
                      labelText: 'Sebab', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'terlepas', child: Text('Terlepas temujanji')),
                    DropdownMenuItem(
                        value: 'tukar', child: Text('Nak tukar temujanji')),
                  ],
                  onChanged: (v) => setState(() => _sebab = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ic,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'No. IC (tanpa -)',
                      border: OutlineInputBorder()),
                  validator: _validateIc,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Hantar permohonan'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}