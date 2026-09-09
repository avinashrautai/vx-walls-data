import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../models/wallpaper.dart';
import '../repositories/wallpaper_repository.dart';
import '../widgets/vx_brand_mark.dart';
import '../widgets/vx_pill.dart';

class MainGalleryScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Future<void> Function(int index) onThemeChanged;

  const MainGalleryScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<MainGalleryScreen> createState() => _MainGalleryScreenState();
}

class _MainGalleryScreenState extends State<MainGalleryScreen> {
  final WallpaperRepository _repository = const WallpaperRepository();
  final List<Wallpaper> _wallpapers = [];
  final Set<String> _savedIds = {};

  int _activeNavIndex = 0; // 0: Home, 1: Search, 2: Saved, 3: Settings
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  int _motionMode = 1; // 0: Off, 1: Subtle, 2: Smooth

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _fetchWallpapers();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedIds.addAll(prefs.getStringList('saved_wallpapers') ?? []);
      _motionMode = prefs.getInt('pill_motion_mode') ?? 1;
    });
  }

  Future<void> _toggleSave(Wallpaper wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_savedIds.contains(wallpaper.id)) {
        _savedIds.remove(wallpaper.id);
      } else {
        _savedIds.add(wallpaper.id);
      }
    });
    await prefs.setStringList('saved_wallpapers', _savedIds.toList());
  }

  Future<void> _fetchWallpapers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _repository.fetchPage(1, limit: 50);
      setState(() {
        _wallpapers.clear();
        _wallpapers.addAll(list);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Wallpaper> get _filteredWallpapers {
    if (_activeNavIndex == 2) {
      return _wallpapers.where((w) => _savedIds.contains(w.id)).toList();
    }
    if (_searchQuery.trim().isEmpty) return _wallpapers;
    final q = _searchQuery.toLowerCase();
    return _wallpapers.where((w) =>
      w.author.toLowerCase().contains(q) ||
      w.id.toLowerCase().contains(q) ||
      w.source.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? darkBg : lightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(dark),
                Expanded(child: _buildBody(dark)),
              ],
            ),
          ),
          VXPill(
            animationMode: _motionMode,
            items: [
              VXPillItem(
                iconWidget: const VXBrandMark(size: 21, color: VXPillTheme.iconColor),
                label: 'Home',
                selected: _activeNavIndex == 0,
                onTap: () => setState(() {
                  _activeNavIndex = 0;
                  _searchQuery = '';
                }),
              ),
              VXPillItem(
                icon: LucideIcons.search,
                label: 'Search',
                selected: _activeNavIndex == 1,
                onTap: () => setState(() => _activeNavIndex = 1),
              ),
              VXPillItem(
                icon: LucideIcons.bookmark,
                label: 'Saved',
                selected: _activeNavIndex == 2,
                onTap: () => setState(() => _activeNavIndex = 2),
              ),
              VXPillItem(
                icon: LucideIcons.settings,
                label: 'Settings',
                selected: _activeNavIndex == 3,
                onTap: () => setState(() => _activeNavIndex = 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool dark) {
    final title = switch (_activeNavIndex) {
      1 => 'Search',
      2 => 'Saved',
      3 => 'Settings',
      _ => 'VX Walls',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: dark ? Colors.white : const Color(0xFF18181B),
            ),
          ),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: vxAccent),
            )
          else if (_activeNavIndex == 0)
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: _fetchWallpapers,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool dark) {
    if (_activeNavIndex == 3) {
      return _buildSettingsView(dark);
    }

    if (_activeNavIndex == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              autofocus: true,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search wallpapers or authors...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: dark ? darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildGrid(dark)),
        ],
      );
    }

    return _buildGrid(dark);
  }

  Widget _buildGrid(bool dark) {
    if (_isLoading && _wallpapers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: vxAccent));
    }

    if (_errorMessage != null && _wallpapers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.triangleAlert, size: 40, color: Colors.amber),
              const SizedBox(height: 12),
              Text(
                'Unable to load wallpapers',
                style: TextStyle(fontWeight: FontWeight.w700, color: dark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchWallpapers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredWallpapers;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _activeNavIndex == 2 ? 'No saved wallpapers yet' : 'No wallpapers found',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final wallpaper = items[index];
        final isSaved = _savedIds.contains(wallpaper.id);

        return GestureDetector(
          onTap: () => _openFullscreen(wallpaper),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: wallpaper.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: dark ? darkSurface : Colors.grey.shade200,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: dark ? darkSurface : Colors.grey.shade200,
                    child: const Icon(LucideIcons.imageOff, color: Colors.grey),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          wallpaper.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleSave(wallpaper),
                        child: Icon(
                          isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                          size: 18,
                          color: isSaved ? vxAccent : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsView(bool dark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          'APPEARANCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: dark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: dark ? darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              RadioListTile<int>(
                title: const Text('System Default'),
                value: 0,
                groupValue: widget.themeMode == ThemeMode.system ? 0 : (widget.themeMode == ThemeMode.light ? 1 : 2),
                onChanged: (val) => widget.onThemeChanged(val ?? 0),
              ),
              RadioListTile<int>(
                title: const Text('Light Theme'),
                value: 1,
                groupValue: widget.themeMode == ThemeMode.system ? 0 : (widget.themeMode == ThemeMode.light ? 1 : 2),
                onChanged: (val) => widget.onThemeChanged(val ?? 1),
              ),
              RadioListTile<int>(
                title: const Text('Dark Theme'),
                value: 2,
                groupValue: widget.themeMode == ThemeMode.system ? 0 : (widget.themeMode == ThemeMode.light ? 1 : 2),
                onChanged: (val) => widget.onThemeChanged(val ?? 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'PILL MOTION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: dark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: dark ? darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              RadioListTile<int>(
                title: const Text('Off'),
                value: 0,
                groupValue: _motionMode,
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _motionMode = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('pill_motion_mode', val);
                },
              ),
              RadioListTile<int>(
                title: const Text('Subtle'),
                value: 1,
                groupValue: _motionMode,
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _motionMode = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('pill_motion_mode', val);
                },
              ),
              RadioListTile<int>(
                title: const Text('Smooth'),
                value: 2,
                groupValue: _motionMode,
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _motionMode = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('pill_motion_mode', val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openFullscreen(Wallpaper wallpaper) {
    final initialIndex = _filteredWallpapers.indexOf(wallpaper);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenWallpaperViewer(
          wallpapers: _filteredWallpapers,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
          savedIds: _savedIds,
          onToggleSave: _toggleSave,
        ),
      ),
    );
  }
}

class FullscreenWallpaperViewer extends StatefulWidget {
  final List<Wallpaper> wallpapers;
  final int initialIndex;
  final Set<String> savedIds;
  final Function(Wallpaper wallpaper) onToggleSave;

  const FullscreenWallpaperViewer({
    super.key,
    required this.wallpapers,
    required this.initialIndex,
    required this.savedIds,
    required this.onToggleSave,
  });

  @override
  State<FullscreenWallpaperViewer> createState() => _FullscreenWallpaperViewerState();
}

class _FullscreenWallpaperViewerState extends State<FullscreenWallpaperViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = widget.wallpapers[_currentIndex];
    final isSaved = widget.savedIds.contains(wallpaper.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.wallpapers.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final wp = widget.wallpapers[index];
              return CachedNetworkImage(
                imageUrl: wp.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: vxAccent),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wallpaper.author,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          wallpaper.source,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                      color: isSaved ? vxAccent : Colors.white,
                    ),
                    onPressed: () {
                      widget.onToggleSave(wallpaper);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
