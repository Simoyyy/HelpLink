import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

class BeneficiaryProfileScreen extends StatefulWidget {
  const BeneficiaryProfileScreen({super.key});

  @override
  State<BeneficiaryProfileScreen> createState() =>
      _BeneficiaryProfileScreenState();
}

class _BeneficiaryProfileScreenState extends State<BeneficiaryProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _icController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _showSuccess = false;
  bool _isUploadingPhoto = false;
  bool _hasPrecachedImage = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _icController = TextEditingController(text: user?.icNumber ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _locationController = TextEditingController(text: user?.location ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrecachedImage) {
      _hasPrecachedImage = true;
      precacheImage(
          ResizeImage(const AssetImage('assets/images/6660.jpg'), width: 800),
          context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final user = authService.userModel;
    if (user == null) return;

    final error = await firestoreService.updateUserProfile(
      userId: user.uid,
      data: {
        'fullName': _nameController.text.trim(),
        'icNumber': _icController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
      },
    );

    await authService.loadUserData();

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (error == null) {
          _isEditing = false;
          _showSuccess = true;
        }
      });
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppTheme.errorRed));
      } else {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSuccess = false);
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final user = authService.userModel;
    if (user == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Change Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryBlue),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryBlue),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    XFile? picked;
    if (source == ImageSource.camera) {
      picked = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        picked = XFile(result.files.single.path!);
      }
    }
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    final oldPhotoUrl = user.profileImageUrl;

    try {
      await firestoreService.uploadProfileImage(
          userId: user.uid, imageFile: File(picked.path));
      if (oldPhotoUrl != null) {
        await CachedNetworkImage.evictFromCache(oldPhotoUrl);
      }
      await authService.loadUserData();
      final newUrl = authService.userModel?.profileImageUrl;
      if (newUrl != null && mounted) {
        await precacheImage(CachedNetworkImageProvider(newUrl), context);
      }
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: AppTheme.successGreen));
      }
    } on FirebaseException catch (e) {
      await authService.loadUserData();
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        final msg = e.code == 'unauthorized'
            ? 'Permission denied. Storage rules may not be deployed yet.'
            : 'Upload failed: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.errorRed));
      }
    } catch (e) {
      await authService.loadUserData();
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.errorRed));
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pwField(
                controller: currentPwController,
                label: 'Current Password',
                obscure: obscureCurrent,
                onToggle: () =>
                    setDialogState(() => obscureCurrent = !obscureCurrent),
              ),
              const SizedBox(height: 12),
              _pwField(
                controller: newPwController,
                label: 'New Password',
                obscure: obscureNew,
                onToggle: () => setDialogState(() => obscureNew = !obscureNew),
              ),
              const SizedBox(height: 12),
              _pwField(
                controller: confirmPwController,
                label: 'Confirm New Password',
                obscure: obscureConfirm,
                onToggle: () =>
                    setDialogState(() => obscureConfirm = !obscureConfirm),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue),
              onPressed: () async {
                if (newPwController.text != confirmPwController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('New passwords do not match.'),
                    backgroundColor: AppTheme.errorRed,
                  ));
                  return;
                }
                if (newPwController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('New password must be at least 6 characters.'),
                    backgroundColor: AppTheme.errorRed,
                  ));
                  return;
                }
                Navigator.pop(ctx);
                final authService =
                    Provider.of<AuthService>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                final error = await authService.changePassword(
                  currentPassword: currentPwController.text,
                  newPassword: newPwController.text,
                );
                if (mounted) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(error ?? 'Password changed successfully!'),
                    backgroundColor: error != null
                        ? AppTheme.errorRed
                        : AppTheme.successGreen,
                  ));
                }
              },
              child:
                  const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon:
              Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.userModel;
    final topPad = MediaQuery.of(context).padding.top;

    if (user == null) {
      return Scaffold(
          body: Center(
              child: Lottie.asset('assets/lottie/loading.json',
                  width: 120, height: 120)));
    }

    final initials = user.fullName.isNotEmpty
        ? user.fullName.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    final memberSince = DateFormat('MMMM yyyy').format(user.createdAt);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // ── Purple gradient header ────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: ResizeImage(
                    const AssetImage('assets/images/6660.jpg'), width: 800),
                fit: BoxFit.cover,
                opacity: 0.7,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.beneficiaryGradientStart,
                  AppTheme.beneficiaryGradientEnd,
                ],
              ),
            ),
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.black, size: 24),
                      ),
                      GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () {
                                if (_isEditing) {
                                  _saveProfile();
                                } else {
                                  setState(() {
                                    _showSuccess = false;
                                    _isEditing = true;
                                  });
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.black.withValues(alpha: 0.5)),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Lottie.asset(
                                      'assets/lottie/loading.json',
                                      fit: BoxFit.contain))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        _isEditing
                                            ? Icons.check
                                            : Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 15),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isEditing ? 'Save' : 'Edit Profile',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tappable avatar
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: _isUploadingPhoto
                              ? Center(
                                  child: Lottie.asset(
                                      'assets/lottie/loading.json',
                                      width: 40,
                                      height: 40))
                              : user.profileImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: user.profileImageUrl!,
                                      fit: BoxFit.cover,
                                      width: 88,
                                      height: 88,
                                      placeholder: (_, __) => Center(
                                          child: Text(initials.toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white))),
                                      errorWidget: (_, __, ___) => Center(
                                          child: Text(initials.toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white))),
                                    )
                                  : Center(
                                      child: Text(initials.toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white))),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Beneficiary',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Success banner
                    if (_showSuccess) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.successGreen.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppTheme.successGreen, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Profile updated successfully!',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.successGreen),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showSuccess = false),
                              child: const Icon(Icons.close,
                                  size: 16, color: AppTheme.successGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Personal Information
                    _sectionTitle('Personal Information'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _profileField(
                            label: 'Full Name *',
                            controller: _nameController,
                            icon: Icons.person_outline,
                            enabled: _isEditing,
                            accentColor: AppTheme.primaryPurple,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          _divider(),
                          _profileField(
                            label: 'IC Number *',
                            controller: _icController,
                            icon: Icons.badge_outlined,
                            enabled: _isEditing,
                            accentColor: AppTheme.primaryPurple,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          _divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('IC Verification',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _fieldIcon(
                                        Icons.verified_user_rounded,
                                        user.isICVerified == true
                                            ? AppTheme.successGreen
                                            : AppTheme.textMuted),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.isICVerified == true
                                                    ? 'Verified ✓'
                                                    : 'Not verified',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: user.isICVerified ==
                                                          true
                                                      ? AppTheme.successGreen
                                                      : AppTheme.warningOrange,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (user.isICVerified != true)
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pushNamed(context,
                                                      '/ic-verification'),
                                              child: const Text('Verify Now'),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _divider(),
                          _profileField(
                            label: 'Email Address',
                            value: user.email,
                            icon: Icons.email_outlined,
                            enabled: false,
                            accentColor: AppTheme.primaryPurple,
                          ),
                          _divider(),
                          _profileField(
                            label: 'Phone Number *',
                            controller: _phoneController,
                            icon: Icons.phone_outlined,
                            enabled: _isEditing,
                            accentColor: AppTheme.primaryPurple,
                            keyboardType: TextInputType.phone,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          _divider(),
                          _profileField(
                            label: 'Location *',
                            controller: _locationController,
                            icon: Icons.location_on_outlined,
                            enabled: _isEditing,
                            accentColor: AppTheme.primaryPurple,
                            isLast: true,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Lottie.asset(
                                      'assets/lottie/loading.json',
                                      fit: BoxFit.contain))
                              : const Text('Save Changes',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Security
                    _sectionTitle('Security'),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showChangePasswordDialog,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.lock_outline,
                                  color: AppTheme.primaryPurple, size: 20),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Change Password',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textDark)),
                                  SizedBox(height: 2),
                                  Text('Update your account password',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Account Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _accountInfoRow('Account Type', 'Beneficiary'),
                          const SizedBox(height: 8),
                          _accountInfoRow('Member Since', memberSince),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark),
      );

  Widget _divider() => const Divider(
      height: 1, thickness: 1, color: Color(0xFFE2E8F0), indent: 16);

  Widget _profileField({
    required String label,
    TextEditingController? controller,
    String? value,
    required IconData icon,
    required bool enabled,
    required Color accentColor,
    bool isLast = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: [
              _fieldIcon(icon, enabled ? accentColor : AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: controller != null
                    ? TextFormField(
                        controller: controller,
                        enabled: enabled,
                        keyboardType: keyboardType,
                        validator: validator,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: accentColor, width: 1),
                          ),
                          disabledBorder: InputBorder.none,
                          errorStyle:
                              const TextStyle(fontSize: 11, height: 0.8),
                        ),
                      )
                    : Text(
                        value ?? '',
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textDark),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _accountInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
      ],
    );
  }
}
