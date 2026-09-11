import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import '../screens/main_gallery_screen.dart';
import '../widgets/vx_brand_mark.dart';
import '../widgets/vx_pill.dart';

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

  ThemeMode _mode(int index) =>
      index == 1 ? ThemeMode.light : index == 2 ? ThemeMode.dark : ThemeMode.system;

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: vxAccent,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        textTheme: lightText,
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        primaryColor: vxAccent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: vxAccent,
          brightness: Brightness.dark,
          surface: darkSurface,
        ),
        textTheme: darkText,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
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

class _VXLaunchScreenState extends State<VXLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _line;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _line = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.28, 1, curve: Curves.easeOut),
    );
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1050), _continue);
  }

  Future<void> _continue() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(firstLaunchGuideKey) ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            seen ? const _VXGalleryEntry() : const VXFirstLaunchGuide(),
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF17171A);
    return Scaffold(
      backgroundColor: dark ? darkBg : lightBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: AnimatedBuilder(
                animation: _line,
                builder: (_, __) => CustomPaint(
                  painter: _VXRevealPainter(
                    progress: _line.value,
                    color: foreground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  Text(
                    'VX Walls',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Walls worth keeping.',
                    style: TextStyle(
                      color: foreground.withOpacity(.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VXRevealPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _VXRevealPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()
      ..moveTo(size.width * .12, size.height * .20)
      ..lineTo(size.width * .38, size.height * .80)
      ..lineTo(size.width * .52, size.height * .45)
      ..moveTo(size.width * .49, size.height * .25)
      ..lineTo(size.width * .86, size.height * .80)
      ..moveTo(size.width * .84, size.height * .25)
      ..lineTo(size.width * .52, size.height * .70);

    final metrics = fullPath.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, metric) => sum + metric.length);
    var target = total * progress;
    final revealed = Path();
    for (final metric in metrics) {
      if (target <= 0) break;
      final take = target.clamp(0, metric.length).toDouble();
      revealed.addPath(metric.extractPath(0, take), Offset.zero);
      target -= metric.length;
    }

    canvas.drawPath(
      revealed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .105
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VXRevealPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _VXGalleryEntry extends StatelessWidget {
  const _VXGalleryEntry();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_VXWallsAppState>();
    return MainGalleryScreen(
      themeMode: state?.mode ?? ThemeMode.system,
      onThemeChanged: state?.setTheme ?? (_) async {},
    );
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

  static const _steps = <({String title, String body})>[
    (
      title: 'Your screen deserves better.',
      body: 'A small, curated library chosen for the way phone screens actually look.',
    ),
    (
      title: 'Find one. Make it yours.',
      body: 'Open a wall, swipe through the collection, then like, save or set it in a few taps.',
    ),
    (
      title: 'Everything, within reach.',
      body: 'The VX Pill keeps the important controls close without covering the wallpaper.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(firstLaunchGuideKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const _VXGalleryEntry(),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? darkBg : lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const VXBrandMark(size: 27),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => index = value),
                  itemBuilder: (_, i) {
                    final item = _steps[i];
                    return Column(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Center(child: _GuideVisual(index: i)),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 340),
                                child: Text(
                                  item.body,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.5,
                                    color: dark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == index ? vxAccent : Colors.grey.withOpacity(.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: vxAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    if (index == _steps.length - 1) {
                      _finish();
                    } else {
                      _pages.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                  child: Text(
                    index == _steps.length - 1 ? 'Start Exploring' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideVisual extends StatelessWidget {
  final int index;
  const _GuideVisual({required this.index});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? const Color(0xFF1B1C21) : Colors.white;

    if (index == 2) {
      return SizedBox(
        width: 330,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 245,
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.grey.withOpacity(.18)),
              ),
            ),
            const Positioned(
              bottom: 28,
              child: VXPill(
                floating: false,
                widthOverride: 284,
                items: [
                  VXPillItem(icon: Icons.home_outlined, label: 'Home', onTap: _noop),
                  VXPillItem(icon: Icons.search_rounded, label: 'Search', onTap: _noop),
                  VXPillItem(icon: Icons.favorite_border_rounded, label: 'Saved', onTap: _noop),
                  VXPillItem(icon: Icons.tune_rounded, label: 'Settings', onTap: _noop),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 210,
      height: 285,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.withOpacity(.18)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: index == 0
            ? const _CuratedWallPreview()
            : const _ViewerActionPreview(),
      ),
    );
  }

  static void _noop() {}
}

class _CuratedWallPreview extends StatelessWidget {
  const _CuratedWallPreview();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      crossAxisSpacing: 7,
      mainAxisSpacing: 7,
      childAspectRatio: .58,
      children: const [
        _PreviewTile(a: Color(0xFF5D6F82), b: Color(0xFFD6C8A5)),
        _PreviewTile(a: Color(0xFF26364B), b: Color(0xFF8CA6A4)),
        _PreviewTile(a: Color(0xFF8B5E4F), b: Color(0xFFE6C99E)),
        _PreviewTile(a: Color(0xFF3C5450), b: Color(0xFFA9B69D)),
      ],
    );
  }
}

class _ViewerActionPreview extends StatelessWidget {
  const _ViewerActionPreview();
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _PreviewTile(a: Color(0xFF314B5E), b: Color(0xFFDDA66D)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: 142,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: VXPillTheme.border, width: .65),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF17171A)),
                  Icon(Icons.favorite_border_rounded, size: 17, color: Color(0xFF17171A)),
                  Icon(Icons.download_rounded, size: 17, color: Color(0xFF17171A)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final Color a;
  final Color b;
  const _PreviewTile({required this.a, required this.b});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
    );
  }
}
