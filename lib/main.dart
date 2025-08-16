import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'views/home_page.dart';
import 'services/player_provider.dart';
import 'database/database.dart';
import './services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 确保 MediaKit 完全初始化
    MediaKit.ensureInitialized();

    final themeProvider = AppThemeProvider();
    await themeProvider.init();

    // 初始化数据库
    final musicDatabase = MusicDatabase();

    // 确保窗口管理器初始化
    await windowManager.ensureInitialized();

    // 设置窗口选项，隐藏系统标题栏，方便自定义
    const WindowOptions windowOptions = WindowOptions(
      size: Size(1080, 720),
      minimumSize: Size(1080, 720),
      center: true,
      backgroundColor: Colors.transparent, // 透明背景
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider(create: (_) => PlayerProvider()),
          Provider<MusicDatabase>.value(value: musicDatabase),
        ],
        child: const MainApp(),
      ),
    );

    final bool isWindows = Platform.isWindows;
    if (isWindows) {
      doWhenWindowReady(() {
        final win = appWindow;
        win.minSize = const Size(1080, 720);
        win.size = const Size(1080, 720);
        win.alignment = Alignment.center;
        win.show();
      });
    }
  } catch (e) {
    debugPrint('应用初始化失败: $e');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWindows = Platform.isWindows;

    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'LZF Music',
          theme: ThemeData(
            fontFamily: isWindows ? 'Microsoft YaHei' : null,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF016B5B),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            fontFamily: isWindows ? 'Microsoft YaHei' : null,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF016B5B),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeProvider.themeMode,
          home: const HomePage(),
          builder: (context, child) {
            if (!isWindows) {
              // 非 Windows，直接返回页面，无自定义标题栏
              return child ?? const SizedBox.shrink();
            }
            // Windows 平台，自定义标题栏覆盖内容，不推内容，透明
            return Stack(
              children: [
                if (child != null) Positioned.fill(child: child),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 30,
                  child: CustomTitleBar(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;

    final buttonColors = WindowButtonColors(
      iconNormal: isDark ? Colors.white70 : Colors.black54,
      mouseOver: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      mouseDown: isDark ? Colors.grey.shade800 : Colors.grey.shade400,
      iconMouseOver: isDark ? Colors.white : Colors.black,
      iconMouseDown: isDark ? Colors.white : Colors.black,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: isDark ? Colors.white70 : Colors.black54,
      mouseOver: Colors.red.shade700,
      mouseDown: Colors.red.shade900,
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Container(
      color: Colors.transparent,
      child: WindowTitleBarBox(
        child: Row(
          children: [
            Expanded(child: MoveWindow()),
            Row(
              children: [
                MinimizeWindowButton(
                  colors: buttonColors,
                  onPressed: () => windowManager.minimize(),
                ),
                MaximizeWindowButton(
                  colors: buttonColors,
                  onPressed: () async {
                    bool maximized = await windowManager.isMaximized();
                    if (maximized) {
                      windowManager.restore();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                CloseWindowButton(
                  colors: closeButtonColors,
                  onPressed: () => windowManager.close(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
