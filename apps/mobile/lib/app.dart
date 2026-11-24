import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/presentation/screens/pingo_login_screen.dart';
import 'features/auth/presentation/state/auth_provider.dart';
import 'features/home/presentation/screens/pingo_home_screen.dart';

/// The root application widget for Pingo Mobile.
class PingoApp extends ConsumerWidget {
  const PingoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    Widget homeScreen;
    if (authState.isInitializing) {
      homeScreen = const Scaffold(
        backgroundColor: AppColors.inkBlack,
        body: SizedBox.expand(),
      );
    } else if (authState.isAuthenticated || authState.isGuest) {
      homeScreen = const PingoHomeScreen();
    } else {
      homeScreen = const PingoLoginScreen();
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: homeScreen,
    );
  }
}
