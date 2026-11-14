import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

import 'package:pingo_mobile/features/profile/presentation/screens/pingo_edit_profile_screen.dart';

/// Screen implementing '7. Profile.png'.
class PingoProfileScreen extends StatefulWidget {
  const PingoProfileScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PingoProfileScreen()),
    );
  }

  @override
  State<PingoProfileScreen> createState() => _PingoProfileScreenState();
}

class _PingoProfileScreenState extends State<PingoProfileScreen> {
  String _userName = 'Pingo User';
  String _userEmail = 'user@pingo.app';
  String _userPhone = '+880 1700-000000';
  bool _dailySummary = true;
  bool _appLock = true;
  bool _cloudBackup = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;
    final mutedColor = isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Top Bar
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
                  'Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // User Info Card (Tapping opens Edit Profile & Photo Upload)
            InkWell(
              onTap: () {
                PingoEditProfileScreen.open(
                  context,
                  initialName: _userName,
                  initialEmail: _userEmail,
                  initialPhone: _userPhone,
                  onSave: (newName, newEmail, newPhone) {
                    setState(() {
                      _userName = newName.isNotEmpty ? newName : _userName;
                      _userEmail = newEmail.isNotEmpty ? newEmail : _userEmail;
                      _userPhone = newPhone.isNotEmpty ? newPhone : _userPhone;
                    });
                  },
                );
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEDEBFD),
                          ),
                          child: Center(
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.pingoPurple,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.pingoPurple,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _userEmail,
                            style: TextStyle(fontSize: 14, color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEBFD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pingoPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Settings Table
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Column(
                children: [
                  _navRow('Language', 'English + Bangla', textColor, mutedColor),
                  Divider(color: borderColor, height: 1),
                  _navRow('Morning reminder time', '8:00 AM', textColor, mutedColor),
                  Divider(color: borderColor, height: 1),
                  _navRow('Notification sound', 'Ping', textColor, mutedColor),
                  Divider(color: borderColor, height: 1),
                  _switchRow('Daily summary', _dailySummary, (val) => setState(() => _dailySummary = val), textColor),
                  Divider(color: borderColor, height: 1),
                  _switchRow('App lock', _appLock, (val) => setState(() => _appLock = val), textColor),
                  Divider(color: borderColor, height: 1),
                  _switchRow('Cloud backup', _cloudBackup, (val) => setState(() => _cloudBackup = val), textColor),
                  Divider(color: borderColor, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                        Row(
                          children: const [
                            Icon(Icons.circle, color: AppColors.success, size: 8),
                            SizedBox(width: 6),
                            Text(
                              'Working',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Log Out Button
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out safely')),
                );
              },
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                  color: cardBg,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Delete Account Link
            Center(
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Delete my account and data',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: mutedColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _navRow(String label, String value, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          Text(value, style: TextStyle(fontSize: 14, color: mutedColor)),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          Switch(
            value: value,
            activeThumbColor: AppColors.pingoPurple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
