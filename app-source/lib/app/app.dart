import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import '../screens/main_gallery_screen.dart';
import '../widgets/vx_brand_mark.dart';

const String themeKey = 'themeMode';
const String firstLaunchGuideKey = 'hasSeenFirstLaunchGuide';

class VXWallsApp extends StatefulWidget {
  final int initialThemeIndex;
  const VXWallsApp({super.key, required this.initialThemeIndex});

  static Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    runApp(VXWallsApp(initialThemeIndex: prefs.getInt(themeKey) ?? 0));
  }

  @override
  State<VXWallsApp> createState() => _VXWallsAppState();
}

class _VXWallsAppState extends State<VXWallsApp> {
  late ThemeMode mode;

  @override
  void initState() {
    super.initState();
    mode = _mode(widget.initialThemeIndex);
  }

  ThemeMode _mode(int index) => index == 1 ? ThemeMode.light : index == 2 ? ThemeMode.dark : ThemeMode.system;

  Future<void> setTheme(int index) async {
    setState(() => mode = _mode(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(themeKey, index);
  }

  @override
  Widget build(BuildContext context) {
    final lightText = GoogleFonts.plusJakartaSansTextTheme();
    final darkText = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VX Walls',
      themeMode: mode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        primaryColor: vxAccent,
        colorScheme: ColorScheme.fromSeed(seedColor: vxAccent, brightness: Brightness.light, surface: Colors.white),
        textTheme: lightText,
        appBarTheme: const AppBarTheme(backgroundColor: lightBg, elevation: 0, surfaceTintColor: Colors.transparent),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        primaryColor: vxAccent,
        colorScheme: ColorScheme.fromSeed(seedColor: vxAccent, brightness: Brightness.dark, surface: darkSurface),
        textTheme: darkText,
        appBarTheme: const AppBarTheme(backgroundColor: darkBg, elevation: 0, surfaceTintColor: Colors.transparent),
      ),
      home: const VXLaunchScreen(),
    );
  }
}

class VXLaunchScreen extends StatefulWidget {
  const VXLaunchScreen({super.key});
  @override
  State<VXLaunchScreen> createState() => _VXLaunchScreenState();
}

class _VXLaunchScreenState extends State<VXLaunchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: .94, end: 1).animate(curve);
    _slide = Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(curve);
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 820), _continue);
  }

  Future<void> _continue() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(firstLaunchGuideKey) ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => seen ? const _VXGalleryEntry() : const VXFirstLaunchGuide(),
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? darkBg : lightBg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                VXBrandMark(size: 54, light: dark),
                const SizedBox(height: 16),
                Text('VX Walls', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -1, color: dark ? Colors.white : const Color(0xFF18181B))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _VXGalleryEntry extends StatelessWidget {
  const _VXGalleryEntry();
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_VXWallsAppState>();
    return MainGalleryScreen(themeMode: state?.mode ?? ThemeMode.system, onThemeChanged: state?.setTheme ?? (_) async {});
  }
}

class VXFirstLaunchGuide extends StatefulWidget {
  const VXFirstLaunchGuide({super.key});
  @override
  State<VXFirstLaunchGuide> createState() => _VXFirstLaunchGuideState();
}

class _VXFirstLaunchGuideState extends State<VXFirstLaunchGuide> {
  final PageController _pages = PageController();
  int index = 0;
  static const _steps = <({String title, String body, IconData icon})>[
    (title: 'Discover', body: 'Explore a focused collection of beautiful wallpapers.', icon: Icons.auto_awesome_outlined),
    (title: 'Make it yours', body: 'Like, save and set any wallpaper in a few taps.', icon: Icons.favorite_border),
    (title: 'Swipe & explore', body: 'Open a wallpaper and swipe vertically to keep discovering.', icon: Icons.swipe_vertical_outlined),
    (title: 'The VX Pill', body: 'Home, Search, Saved and Settings stay within easy reach.', icon: Icons.more_horiz),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(firstLaunchGuideKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const _VXGalleryEntry(),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
    ));
  }

  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? darkBg : lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          child: Column(children: [
            Row(children: [const VXBrandMark(size: 27), const Spacer(), TextButton(onPressed: _finish, child: const Text('Skip'))]),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => index = value),
                itemBuilder: (_, i) {
                  final item = _steps[i];
                  return Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(key: ValueKey(i), mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 86, height: 86, decoration: BoxDecoration(color: vxAccent.withOpacity(.10), shape: BoxShape.circle), child: Icon(item.icon, size: 34, color: vxAccent)),
                        const SizedBox(height: 30),
                        Text(item.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
                        const SizedBox(height: 12),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Text(item.body, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5, color: dark ? Colors.white60 : Colors.black54))),
                      ]),
                    ),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_steps.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == index ? 22 : 7, height: 7, decoration: BoxDecoration(color: i == index ? vxAccent : Colors.grey.withOpacity(.35), borderRadius: BorderRadius.circular(10))))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: vxAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: () {
                if (index == _steps.length - 1) { _finish(); } else { _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeInOutCubic); }
              },
              child: Text(index == _steps.length - 1 ? 'Start Exploring' : 'Next', style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
      ),
    );
  }
}
