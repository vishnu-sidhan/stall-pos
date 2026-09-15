import 'package:flutter/material.dart';
import 'src/controllers/counter_controller.dart';
import 'src/controllers/theme_controller.dart';
import 'src/storage/app_storage.dart';
import 'src/views/main_navigation_screen.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = CounterController(
    storageService: AppStorage.instance.counterStorage,
  );
  await controller.init();
  await ThemeController.instance.init();

  runApp(StallPosApp(controller: controller));
}

/// Main application widget for StallPOS.
class StallPosApp extends StatelessWidget {
  final CounterController controller;
  final ThemeController? themeController;
  final int initialIndex;
  final List<Widget>? extraActions;

  const StallPosApp({
    super.key,
    required this.controller,
    this.themeController,
    this.initialIndex = 1,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final themeCtrl = themeController ?? ThemeController.instance;

    return ListenableBuilder(
      listenable: themeCtrl,
      builder: (context, _) {
        return MaterialApp(
          title: 'StallPOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeCtrl.themeMode,
          home: MainNavigationScreen(
            controller: controller,
            initialIndex: initialIndex,
            extraActions: extraActions,
          ),
        );
      },
    );
  }
}
