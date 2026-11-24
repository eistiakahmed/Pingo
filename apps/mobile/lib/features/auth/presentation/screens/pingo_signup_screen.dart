import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/auth/presentation/state/auth_provider.dart';
import 'package:pingo_mobile/features/home/presentation/screens/pingo_home_screen.dart';
import 'package:pingo_mobile/features/home/presentation/state/pingo_chat_provider.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/tech_canvas_background.dart';

/// Pingo Sign Up Screen — Faithful Dark-Theme Adaptation of '6. Sign up.png'
/// featuring circular back button + Penguin badge, bold 'Create your account',
/// spacious 16px rounded inputs, 'I speak: English / বাংলা / Both' pills,
/// privacy agreement checkbox, and full-width stadium 'Create account' CTA.
class PingoSignupScreen extends ConsumerStatefulWidget {
  const PingoSignupScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PingoSignupScreen()),
    );
  }

  @override
  ConsumerState<PingoSignupScreen> createState() => _PingoSignupScreenState();
}

class _PingoSignupScreenState extends ConsumerState<PingoSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _agreedToPrivacy = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    ref.read(authProvider.notifier).clearError();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    if (!_agreedToPrivacy) {
      HapticFeedback.lightImpact();
      final isBangla = ref.read(pingoChatProvider).language == 'bn';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.inkSurface,
          content: Text(
            isBangla
                ? 'অনুগ্রহ করে শর্তাবলী এবং গোপনীয়তা নীতিতে সম্মতি দিন'
                : 'Please agree to the Terms and Privacy Policy to continue.',
            style: const TextStyle(color: AppColors.paperWhite),
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    TextInput.finishAutofillContext();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    ref.read(pingoChatProvider.notifier).setLanguage('en');

    final success = await ref.read(authProvider.notifier).register(
          email: email,
          password: password,
          name: name.isEmpty ? null : name,
        );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isBangla =
        ref.watch(pingoChatProvider.select((s) => s.language)) == 'bn';

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: TechCanvasBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top Bar: Circular Back Button + Penguin Mascot Pill ──
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.inkCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.inkBorderActive,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 24,
                                  color: AppColors.paperWhite,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inkCard,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.inkBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.asset(
                                      'assets/images/penguin_avatar.png',
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Pingo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.paperWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Headline & Subtitle (Matches '6. Sign up.png') ──
                        Text(
                          isBangla
                              ? 'অ্যাকাউন্ট তৈরি করুন'
                              : 'Create your account',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.paperWhite,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isBangla
                              ? 'এক মিনিটেরও কম সময় লাগবে।'
                              : 'It takes less than a minute.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppColors.paperMuted,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Inline Error Banner ──
                        if (authState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inkCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.overdue,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.overdue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.paperWhite,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── 1. Your Name Field (56dp rounded input) ──
                        TextFormField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_emailFocus);
                          },
                          style: const TextStyle(
                            color: AppColors.paperWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: _inputDecoration(
                            hintText: isBangla ? 'আপনার নাম' : 'Your name',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── 2. Email Field (56dp rounded input) ──
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) =>
                              ref.read(authProvider.notifier).clearError(),
                          onFieldSubmitted: (_) {
                            FocusScope.of(context)
                                .requestFocus(_passwordFocus);
                          },
                          style: const TextStyle(
                            color: AppColors.paperWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: _inputDecoration(
                            hintText: isBangla
                                ? 'ইমেইল ঠিকানা'
                                : 'Email address',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) {
                              return isBangla
                                  ? 'ইমেইল ঠিকানা আবশ্যক'
                                  : 'Email address is required';
                            }
                            if (!v.contains('@') || !v.contains('.')) {
                              return isBangla
                                  ? 'সঠিক ইমেইল ঠিকানা লিখুন'
                                  : 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // ── 3. Password Field (56dp rounded input) ──
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) =>
                              ref.read(authProvider.notifier).clearError(),
                          onFieldSubmitted: (_) => _handleSignup(),
                          style: const TextStyle(
                            color: AppColors.paperWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: _inputDecoration(
                            hintText: isBangla
                                ? 'পাসওয়ার্ড (কমপক্ষে ৮ অক্ষর)'
                                : 'Password (8+ characters)',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? (isBangla
                                      ? 'পাসওয়ার্ড দেখুন'
                                      : 'Show password')
                                  : (isBangla
                                      ? 'পাসওয়ার্ড লুকান'
                                      : 'Hide password'),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.paperSubtle,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return isBangla
                                  ? 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে'
                                  : 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        // ── Terms & Privacy Checkbox Row (Matches '6. Sign up.png') ──
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _agreedToPrivacy = !_agreedToPrivacy;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: _agreedToPrivacy
                                        ? AppColors.signalAmber
                                        : AppColors.inkCard,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _agreedToPrivacy
                                          ? AppColors.signalAmber
                                          : AppColors.inkBorderActive,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _agreedToPrivacy
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: AppColors.inkBlack,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isBangla
                                        ? 'আমি শর্তাবলী এবং গোপনীয়তা নীতিতে সম্মত। আমার রিমাইন্ডার এবং ডকুমেন্ট সম্পূর্ণ গোপন থাকবে।'
                                        : 'I agree to the Terms and the Privacy Policy. My reminders and documents stay private.',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.paperMuted,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Primary Pill CTA: "Create account" (54dp stadium) ──
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                authState.isLoading ? null : _handleSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.paperWhite,
                              foregroundColor: AppColors.inkBlack,
                              disabledBackgroundColor: AppColors.inkSurface,
                              disabledForegroundColor: AppColors.paperSubtle,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppColors.inkBlack,
                                    ),
                                  )
                                : Text(
                                    isBangla
                                        ? 'অ্যাকাউন্ট তৈরি করুন'
                                        : 'Create account',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkBlack,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── Bottom Link: "Already have an account? Log in" ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isBangla
                                  ? 'ইতিমধ্যে অ্যাকাউন্ট আছে? '
                                  : 'Already have an account? ',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.paperMuted,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                ref.read(authProvider.notifier).clearError();
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Text(
                                  isBangla ? 'লগ ইন করুন' : 'Log in',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.signalAmber,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.inkCard,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.paperSubtle,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(
          prefixIcon,
          size: 20,
          color: AppColors.paperSubtle,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.inkBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.inkBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.signalAmber, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.overdue, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.overdue, width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: AppColors.overdue,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
