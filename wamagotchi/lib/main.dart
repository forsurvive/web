import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/palette.dart';
import 'services/storage_service.dart';
import 'viewmodels/game_viewmodel.dart';
import 'viewmodels/memo_viewmodel.dart';
import 'views/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await StorageService.init();
  final gameViewModel = GameViewModel(storage);
  final memoViewModel = MemoViewModel(storage);
  await gameViewModel.load();
  await memoViewModel.load();

  runApp(WamagotchiApp(
    gameViewModel: gameViewModel,
    memoViewModel: memoViewModel,
  ));
}

class WamagotchiApp extends StatelessWidget {
  final GameViewModel gameViewModel;
  final MemoViewModel memoViewModel;

  const WamagotchiApp({
    super.key,
    required this.gameViewModel,
    required this.memoViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameViewModel>.value(value: gameViewModel),
        ChangeNotifierProvider<MemoViewModel>.value(value: memoViewModel),
      ],
      child: MaterialApp(
        title: 'Wamagotchi',
        debugShowCheckedModeBanner: false,
        theme: _buildRetroTheme(),
        home: const MainScreen(),
      ),
    );
  }

  /// 레트로 LCD 테마 (Phase 1: 색상만. 픽셀 폰트·에셋은 Phase 2)
  ThemeData _buildRetroTheme() {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Palette.lcdGreen,
      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.lcdDark,
        foregroundColor: Palette.lcdLight,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Palette.lcdDark,
        foregroundColor: Palette.lcdLight,
        // 기획서 6.1: 모서리 둥글림 금지
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Palette.lcdDark,
        displayColor: Palette.lcdDark,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Palette.lcdDark,
        selectionColor: Palette.lcdMid,
        selectionHandleColor: Palette.lcdDark,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Palette.lcdDark,
        contentTextStyle: TextStyle(color: Palette.lcdLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
