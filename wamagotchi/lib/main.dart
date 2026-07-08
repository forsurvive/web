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

  /// v2 "라이팅 퍼스트" 테마: 종이·잉크 기조, 게임 그린은 액션·칩에만.
  ThemeData _buildRetroTheme() {
    // 'Galmuri' 패밀리는 pubspec에서 폰트를 활성화하면 자동 적용된다.
    // 아직 폰트를 넣지 않았다면 등록되지 않은 패밀리로 취급되어 조용히 fallback 된다(에러 없음).
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Galmuri',
      fontFamilyFallback: const [
        'Malgun Gothic', // Windows 한글
        'Apple SD Gothic Neo', // macOS/iOS 한글
        'Noto Sans KR',
        'sans-serif',
      ],
    );
    return base.copyWith(
      scaffoldBackgroundColor: Palette.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: Palette.accent,
        surface: Palette.surface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Palette.accent,
        foregroundColor: const Color(0xFFF4F6E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Palette.ink,
        displayColor: Palette.ink,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Palette.accent,
        selectionColor: Palette.track,
        selectionHandleColor: Palette.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.ink,
        contentTextStyle: const TextStyle(color: Palette.paper),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
