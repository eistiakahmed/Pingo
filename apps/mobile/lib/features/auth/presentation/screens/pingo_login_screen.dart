import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/auth/presentation/screens/pingo_signup_screen.dart';
import 'package:pingo_mobile/features/auth/presentation/state/auth_provider.dart';
import 'package:pingo_mobile/features/home/presentation/screens/pingo_home_screen.dart';
import 'package:pingo_mobile/features/home/presentation/state/pingo_chat_provider.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/tech_canvas_background.dart';

/// Pingo Login Screen — Faithful Dark-Theme Adaptation of '5. Log in.png'
/// featuring the Headphone Penguin Mascot badge, spacious rounded inputs (16px),
/// full-width stadium pill buttons, 'Continue with Google', and 'Continue without an account'.
class PingoLoginScreen extends ConsumerStatefulWidget {
  const PingoLoginScreen({super.key});

  @override
  ConsumerState<PingoLoginScreen> createState() => _PingoLoginScreenState();
}

class _PingoLoginScreenState extends ConsumerState<PingoLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    ref.read(authProvider.notifier).clearError();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.mediumImpact();
    TextInput.finishAutofillContext();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authProvider.notifier).login(
          email: email,
          password: password,
        );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
        (route) => false,
      );
    }
  }

  void _handleGoogleSignIn(bool isBangla) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.inkSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        content: Text(
          isBangla
              ? 'ইমেইল ও পাসওয়ার্ড দিয়ে লগ ইন করুন অথবা নিচে অতিথি হিসেবে চালিয়ে যান'
              : 'Use email & password above, or continue without an account below.',
          style: const TextStyle(color: AppColors.paperWhite, fontSize: 13),
        ),
      ),
    );
  }

  void _handleContinueAsGuest() {
    HapticFeedback.selectionClick();
    ref.read(authProvider.notifier).continueAsGuest();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
      (route) => false,
    );
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
                        // ── Top Row: 64x64 Penguin Hero Badge ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFADEAFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.inkBorderActive,
                                  width: 1.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/images/penguin_avatar.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Bold Headline & Subtitle (Matches '5. Log in.png') ──
                        Text(
                          isBangla ? 'আবার স্বাগতম' : 'Welcome back',
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
                              ? 'যেকোনো ফোনে আপনার রিমাইন্ডার দেখতে লগ ইন করুন।'
                              : 'Log in to see your reminders on any phone.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppColors.paperMuted,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 28),

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

                        // ── Email Field (56dp spacious rounded input) ──
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
                                  ? 'ইমেইল ঠিকানা লিখুন'
                                  : 'Enter your email address';
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

                        // ── Password Field (56dp spacious rounded input) ──
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onChanged: (_) =>
                              ref.read(authProvider.notifier).clearError(),
                          onFieldSubmitted: (_) => _handleLogin(),
                          style: const TextStyle(
                            color: AppColors.paperWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: _inputDecoration(
                            hintText: isBangla ? 'পাসওয়ার্ড' : 'Password',
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
                            if (value == null || value.isEmpty) {
                              return isBangla
                                  ? 'পাসওয়ার্ড লিখুন'
                                  : 'Enter your password';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Helper Caption (Matches '5. Log in.png')
                        Text(
                          isBangla
                              ? 'আপনার রিমাইন্ডার ও ভল্ট এন্ড-টু-এন্ড সুরক্ষিত থাকবে।'
                              : 'Your reminders and vault stay synced and private.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.paperSubtle,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Primary Pill CTA: "Continue" (54dp height, stadium shape) ──
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                authState.isLoading ? null : _handleLogin,
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
                                    isBangla ? 'এগিয়ে যান' : 'Continue',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkBlack,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── "or" Divider Row (Matches '5. Log in.png') ──
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: AppColors.inkBorder,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                isBangla ? 'অথবা' : 'or',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.paperSubtle,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: AppColors.inkBorder,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // ── Secondary Pill Button: "Continue with Google" ──
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () => _handleGoogleSignIn(isBangla),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.inkCard,
                              side: const BorderSide(
                                color: AppColors.inkBorderActive,
                                width: 1,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.paperWhite,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: AppColors.inkBlack,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isBangla
                                      ? 'Google দিয়ে চালিয়ে যান'
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.paperWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 44),

                        // ── Bottom Links: "New to Pingo? Sign up" ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isBangla ? 'পিঙ্গোতে নতুন? ' : 'New to Pingo? ',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.paperMuted,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                ref.read(authProvider.notifier).clearError();
                                PingoSignupScreen.open(context);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Text(
                                  isBangla ? 'সাইন আপ করুন' : 'Sign up',
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

                        const SizedBox(height: 12),

                        // ── "Continue without an account" (Matches '5. Log in.png') ──
                        Center(
                          child: TextButton(
                            onPressed: _handleContinueAsGuest,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.paperMuted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              isBangla
                                  ? 'অ্যাকাউন্ট ছাড়াই চালিয়ে যান'
                                  : 'Continue without an account',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.paperSubtle,
                              ),
                            ),
                          ),
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
