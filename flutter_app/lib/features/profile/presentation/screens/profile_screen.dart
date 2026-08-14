import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startEditing(Map<String, dynamic> profile) {
    _nameController.text = (profile['full_name'] ?? '') as String;
    _emailController.text = (profile['email'] ?? '') as String;
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            profileAsync.maybeWhen(
              data: (profile) => IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _startEditing(profile),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(profileProvider)),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _isEditing ? _buildEditForm() : _buildViewMode(context, profile),
        ),
      ),
    );
  }

  Widget _buildViewMode(BuildContext context, Map<String, dynamic> profile) {
    final role = profile['role'] as String? ?? '';
    final userCode = profile['user_code'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF0F9D58),
            child: Text(
              (profile['full_name'] as String? ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            profile['full_name'] as String? ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Chip(label: Text(role[0].toUpperCase() + role.substring(1))),
          ),
        ),
        const SizedBox(height: 28),

        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Unique ID',
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share this so others can reach you correctly.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userCode,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Color(0xFF0F9D58),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF0F9D58)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: userCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        _InfoRow(icon: Icons.phone, label: 'Phone', value: profile['phone'] as String? ?? ''),
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: (profile['email'] as String?)?.isNotEmpty == true ? profile['email'] as String : 'Not set',
        ),
        _InfoRow(
          icon: Icons.language,
          label: 'Language',
          value: profile['preferred_language'] == 'te' ? 'Telugu' : 'English',
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        AppTextField(label: 'Full Name', controller: _nameController, prefixIcon: Icons.person),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Email (optional)',
          controller: _emailController,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save Changes', onPressed: _save, isLoading: _isSaving),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _isEditing = false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 22),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}