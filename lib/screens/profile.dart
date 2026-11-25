import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format.dart';
import '../widget/common.dart';
import 'about.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  /// Refresh the cached user (picture URL, description) from the server.
  Future<void> _sync() async {
    try {
      AuthService.instance.updateUser(await api.getMe());
    } catch (_) {
      // Keep the cached user; the next request will surface real problems.
    }
  }

  Future<void> _changePicture() async {
    final picked = await pickImages(
      context,
      maxCount: 1,
      maxBytes: 2 * 1024 * 1024,
      maxSide: 800,
      multiple: false,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      AuthService.instance.updateUser(await api.setPicture(picked.first));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePicture() async {
    setState(() => _busy = true);
    try {
      await api.removePicture();
      AuthService.instance.updateUser(await api.getMe());
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(User user) async {
    final updated = await showDialog<User>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
    if (updated != null) AuthService.instance.updateUser(updated);
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Anda harus sign in lagi untuk melihat atau melakukan transaksi.',
      confirmLabel: 'Log out',
    );
    if (ok) await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.user;
        if (user == null) return const SizedBox.shrink();
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Stack(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: NetImage(url: user.profilePictureUrl, iconSize: 56),
                          ),
                        ),
                        if (_busy)
                          const Positioned.fill(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: PopupMenuButton<String>(
                            enabled: !_busy,
                            tooltip: 'Foto profil',
                            onSelected: (s) => s == 'change' ? _changePicture() : _removePicture(),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'change', child: Text('Pilih foto')),
                              if (user.profilePictureUrl != null)
                                const PopupMenuItem(value: 'remove', child: Text('Hapus foto')),
                            ],
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(Icons.camera_alt, size: 18, color: theme.colorScheme.onPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('@${user.username}',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Center(child: Text(user.email, style: const TextStyle(color: Colors.grey))),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tentang saya',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            (user.description ?? '').isEmpty
                                ? 'Belum ada deskripsi.'
                                : user.description!,
                            style: (user.description ?? '').isEmpty
                                ? const TextStyle(color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text('Member sejak ${formatDate(user.createdAt).split(',').first}',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit profil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _edit(user),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Transaksi saya'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => AppEvents.selectedTab.value = 1,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Tentang aplikasi'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    title: Text('Log out', style: TextStyle(color: theme.colorScheme.error)),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final User user;
  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username =
      TextEditingController(text: widget.user.username);
  late final TextEditingController _description =
      TextEditingController(text: widget.user.description ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // PATCH only what changed; an emptied description is sent as null.
    final changes = <String, dynamic>{};
    final name = _username.text.trim();
    if (name != widget.user.username) changes['username'] = name;
    final desc = _description.text.trim();
    if (desc != (widget.user.description ?? '')) {
      changes['description'] = desc.isEmpty ? null : desc;
    }
    if (changes.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await api.updateProfile(changes);
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profil'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < 3 || t.length > 30) return 'Username harus memiliki 3-30 karakter';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(t)) {
                      return 'Username hanya boleh memiliki huruf, angka, dan underscore';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Tentang saya',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v ?? '').length > 1000 ? 'Maksimal 1000 karakter' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
