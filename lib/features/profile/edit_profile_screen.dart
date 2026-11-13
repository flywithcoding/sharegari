import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/profile/data/profile_models.dart';
import 'package:sharegari/features/profile/data/profile_repository.dart';
import 'package:sharegari/features/profile/providers/profile_providers.dart';

/// Screen for updating profile details: full name, phone number, and avatar photo.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  bool _initialized = false;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;

  // Selected avatar pending upload
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarExt;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _initFields(UserProfile? profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile?.fullName ?? '';
    _phoneCtrl.text = profile?.phone ?? '';
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Picks an image from the device gallery, compressing to max 512px.
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final safeExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';

      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarExt = safeExt;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick image: $e');
    }
  }

  /// Validates Bangladeshi phone numbers: 01XXXXXXXXX (11 digits, starts with 01)
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional in profile
    }
    final clean = value.trim();
    // Allow +8801XXXXXXXXX or 01XXXXXXXXX
    final bdRegex = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');
    if (!bdRegex.hasMatch(clean)) {
      return 'Enter valid 11-digit Bangladeshi number (01XXXXXXXXX)';
    }
    return null;
  }

  Future<void> _submit(UserProfile? currentProfile) async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _errorMessage = 'Not authenticated');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(profileRepositoryProvider);
      String? uploadedUrl;

      // 1. Upload photo if selected
      if (_pendingAvatarBytes != null && _pendingAvatarExt != null) {
        uploadedUrl = await repo.uploadAvatar(
          userId: user.id,
          bytes: _pendingAvatarBytes!,
          fileExtension: _pendingAvatarExt!,
        );
      }

      // Format phone as 01XXXXXXXXX or standard +880...
      String? phoneToSave = _phoneCtrl.text.trim();
      if (phoneToSave.isEmpty) {
        phoneToSave = null;
      } else if (phoneToSave.startsWith('+88')) {
        phoneToSave = phoneToSave.substring(3);
      }

      // 2. Save updates to database
      await repo.updateProfile(
        userId: user.id,
        fullName: _nameCtrl.text.trim(),
        phone: phoneToSave,
        avatarUrl: uploadedUrl ?? currentProfile?.avatarUrl,
      );

      // Invalidate profile cache so UI updates across the entire app
      ref.invalidate(profileProvider);

      if (!mounted) return;
      setState(() {
        _saving = false;
        _successMessage = 'Profile updated successfully!';
      });

      // Brief delay so user sees the success message, then return
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _goBack();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Could not update profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _initFields(profile);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Photo Picker ──────────────────────────────────────
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: _AvatarPreview(
                              pendingBytes: _pendingAvatarBytes,
                              remoteUrl: profile?.avatarUrl,
                              initials: profile?.initials ?? 'U',
                              size: 104,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.background, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _pickImage,
                        child: const Text('Change Profile Photo'),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Success Message ────────────────────────────────────
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: tt.bodySmall?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Error Message ──────────────────────────────────────
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorTint,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: tt.bodySmall?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Full Name Input ───────────────────────────────────
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Phone Input ───────────────────────────────────────
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Phone number (11 digits)',
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 32),

                    // ── Save Button ───────────────────────────────────────
                    ElevatedButton(
                      onPressed: _saving ? null : () => _submit(profile),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load profile: $e',
                  style: TextStyle(color: AppColors.error)),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.pendingBytes,
    required this.remoteUrl,
    required this.initials,
    this.size = 96,
  });

  final Uint8List? pendingBytes;
  final String? remoteUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (pendingBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.memory(
          pendingBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          remoteUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }

    return _initials();
  }

  Widget _initials() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
