import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

/// Edit Profile & Photo Upload screen matching Pingo Design System.
class PingoEditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPhone;
  final Function(String name, String email, String phone)? onSave;

  const PingoEditProfileScreen({
    super.key,
    this.initialName = 'Rahim Ahmed',
    this.initialEmail = 'rahim@email.com',
    this.initialPhone = '+880 1711-000000',
    this.onSave,
  });

  static void open(BuildContext context, {
    String initialName = 'Rahim Ahmed',
    String initialEmail = 'rahim@email.com',
    String initialPhone = '+880 1711-000000',
    Function(String, String, String)? onSave,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PingoEditProfileScreen(
          initialName: initialName,
          initialEmail: initialEmail,
          initialPhone: initialPhone,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<PingoEditProfileScreen> createState() => _PingoEditProfileScreenState();
}

class _PingoEditProfileScreenState extends State<PingoEditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  String? _selectedAvatarAsset; // If custom photo picked
  String _selectedLanguage = 'English + Bangla';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showPhotoOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.pingoPurpleLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.pingoPurple, size: 20),
                ),
                title: Text('Take a photo', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                subtitle: const Text('Use camera to take a new picture', style: TextStyle(fontSize: 12.5)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedAvatarAsset = 'camera_captured');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo captured from camera')),
                  );
                },
              ),

              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFFD97706), size: 20),
                ),
                title: Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                subtitle: const Text('Pick from your photos or files', style: TextStyle(fontSize: 12.5)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedAvatarAsset = 'gallery_picked');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo selected from gallery')),
                  );
                },
              ),

              if (_selectedAvatarAsset != null)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  title: const Text('Remove photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  subtitle: const Text('Revert to initial initials avatar', style: TextStyle(fontSize: 12.5)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _selectedAvatarAsset = null);
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (widget.onSave != null) {
      widget.onSave!(name, email, phone);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back | Title | Save Check
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                            color: isDark ? AppColors.darkSurface : Colors.white,
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),

                  // Save Check Button
                  InkWell(
                    onTap: _save,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pingoPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  const SizedBox(height: 12),

                  // Avatar & Photo Upload Trigger
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showPhotoOptions,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFEDEBFD),
                              border: Border.all(color: AppColors.pingoPurpleLight, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.pingoPurple.withValues(alpha: 0.15),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _selectedAvatarAsset != null
                                  ? const Icon(Icons.person, color: AppColors.pingoPurple, size: 58)
                                  : const Text(
                                      'RA',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.pingoPurple,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Camera Upload Badge
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.pingoPurple,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Center(
                    child: TextButton(
                      onPressed: _showPhotoOptions,
                      child: const Text(
                        'Upload new photo',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pingoPurple,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Fields
                  _fieldLabel('Full name', textColor),
                  _inputField(_nameController, 'Your full name', cardBg, textColor),

                  const SizedBox(height: 18),

                  _fieldLabel('Email address', textColor),
                  _inputField(_emailController, 'Your email', cardBg, textColor, keyboardType: TextInputType.emailAddress),

                  const SizedBox(height: 18),

                  _fieldLabel('Phone number', textColor),
                  _inputField(_phoneController, 'Your phone number', cardBg, textColor, keyboardType: TextInputType.phone),

                  const SizedBox(height: 22),

                  _fieldLabel('Preferred language', textColor),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      _langOption('English', textColor, borderColor),
                      const SizedBox(width: 10),
                      _langOption('বাংলা', textColor, borderColor),
                      const SizedBox(width: 10),
                      _langOption('English + Bangla', textColor, borderColor),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Bottom Save Changes Button
                  InkWell(
                    onTap: _save,
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: AppColors.pingoPurple,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pingoPurple.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Save changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String hint,
    Color cardBg,
    Color textColor, {
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _langOption(String label, Color textColor, Color borderColor) {
    final isSelected = _selectedLanguage == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = label),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.pingoPurple : borderColor,
              width: isSelected ? 1.8 : 1.2,
            ),
            color: isSelected ? AppColors.pingoPurpleSubtle : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.pingoPurple : textColor,
            ),
          ),
        ),
      ),
    );
  }
}
