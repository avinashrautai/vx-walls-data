import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../models/wallpaper.dart';
import '../repositories/vx_image_cache.dart';
import '../repositories/wallpaper_repository.dart';
import '../widgets/vx_brand_mark.dart';
import '../widgets/vx_header.dart';
import '../widgets/vx_pill.dart';

const _savedKey = 'vx.saved.ids.v1';
const _displayKey = 'vx.display.mode.v1';

enum _Section { home, search, saved, settings }
enum _DisplayMode { grid, list }

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
  final _repository = const WallpaperRepository();
  final _search = TextEditingController();
  _Section _section = _Section.home;
  _DisplayMode _displayMode = _DisplayMode.grid;
  final Set<String> _savedIds = <String>{};
  List<Wallpaper> _walls = <Wallpaper>[];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedKey) ?? const <String>[];
    final display = prefs.getInt(_displayKey) ?? 0;
    if (mounted) {
      setState(() {
        _savedIds.addAll(saved);
        _displayMode = display == 1 ? _DisplayMode.list : _DisplayMode.grid;
      });
    }
    await _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await _repository.fetchPage(1);
      if (!mounted) return;
      setState(() {
        _page = 1;
        _walls = result;
        _hasMore = result.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load the VX library.'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _repository.fetchPage(_page + 1);
      if (!mounted) return;
      setState(() {
        if (next.isNotEmpty) {
          _page += 1;
          final byId = <String, Wallpaper>{
            for (final wall in [..._walls, ...next]) wall.id: wall,
          };
          _walls = byId.values.toList();
        } else {
          _hasMore = false;
        }
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleSaved(Wallpaper wall) async {
    setState(() {
      if (!_savedIds.add(wall.id)) _savedIds.remove(wall.id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedKey, _savedIds.toList());
  }

  Future<void> _setDisplayMode(_DisplayMode mode) async {
    setState(() => _displayMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayKey, mode == _DisplayMode.grid ? 0 : 1);
  }

  List<Wallpaper> get _searchResults {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _walls;
    return _walls.where((wall) {
      return wall.name.toLowerCase().contains(query) ||
          wall.category.toLowerCase().contains(query) ||
          wall.series.toLowerCase().contains(query) ||
          wall.author.toLowerCase().contains(query);
    }).toList();
  }

  List<Wallpaper> get _savedWalls =>
      _walls.where((wall) => _savedIds.contains(wall.id)).toList();

  void _select(_Section section) {
    FocusScope.of(context).unfocus();
    setState(() => _section = section);
  }

  void _openViewer(List<Wallpaper> source, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WallpaperViewer(
          wallpapers: source,
          initialIndex: index,
          savedIds: _savedIds,
          onToggleSaved: _toggleSaved,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Column(
                children: [
                  const VXHeader(title: 'VX Walls'),
                  Expanded(child: _sectionBody()),
                ],
              ),
            ),
          ),
          VXPill(
            items: [
              VXPillItem(
                label: 'Home',
                selected: _section == _Section.home,
                iconWidget: VXBrandMark(
                  size: 21,
                  compact: true,
                  color: _section == _Section.home
                      ? VXPillTheme.selectedColor
                      : VXPillTheme.iconColor,
                ),
                onTap: () => _select(_Section.home),
              ),
              VXPillItem(
                icon: Icons.search_rounded,
                label: 'Search',
                selected: _section == _Section.search,
                onTap: () => _select(_Section.search),
              ),
              VXPillItem(
                icon: Icons.favorite_border_rounded,
                label: 'Saved',
                selected: _section == _Section.saved,
                onTap: () => _select(_Section.saved),
              ),
              VXPillItem(
                icon: Icons.tune_rounded,
                label: 'Settings',
                selected: _section == _Section.settings,
                onTap: () => _select(_Section.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionBody() {
    switch (_section) {
      case _Section.home:
        return _libraryView(_walls);
      case _Section.search:
        return _searchView();
      case _Section.saved:
        return _savedView();
      case _Section.settings:
        return _SettingsView(
          themeMode: widget.themeMode,
          displayMode: _displayMode,
          onThemeChanged: widget.onThemeChanged,
          onDisplayChanged: _setDisplayMode,
        );
    }
  }

  Widget _searchView() {
    return Column(
      children: [
        const SizedBox(height: 4),
        TextField(
          controller: _search,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search wallpapers',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () { _search.clear(); setState(() {}); },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: _libraryView(_searchResults, nested: true)),
      ],
    );
  }

  Widget _savedView() {
    if (_savedWalls.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Nothing saved yet',
        body: 'Keep the walls you want to come back to.',
      );
    }
    return _libraryView(_savedWalls);
  }

  Widget _libraryView(List<Wallpaper> source, {bool nested = false}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null && source.isEmpty) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        title: _error!,
        body: 'Check your connection and try again.',
        action: TextButton(onPressed: _loadFirstPage, child: const Text('Retry')),
      );
    }
    if (source.isEmpty) {
      return const _EmptyState(
        icon: Icons.wallpaper_rounded,
        title: 'No walls found',
        body: 'Try another search.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : width >= 600 ? 3 : 2;
        final bottomPadding = 118.0 + MediaQuery.paddingOf(context).bottom;

        if (_displayMode == _DisplayMode.list) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 500 && source == _walls) {
                _loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: EdgeInsets.only(top: 4, bottom: bottomPadding),
              itemCount: source.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _WallListTile(
                wallpaper: source[index],
                saved: _savedIds.contains(source[index].id),
                onTap: () => _openViewer(source, index),
                onSave: () => _toggleSaved(source[index]),
              ),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 600 && source == _walls) {
              _loadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: EdgeInsets.only(top: 4, bottom: bottomPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .60,
            ),
            itemCount: source.length,
            itemBuilder: (_, index) => _WallCard(
              wallpaper: source[index],
              saved: _savedIds.contains(source[index].id),
              onTap: () => _openViewer(source, index),
              onSave: () => _toggleSaved(source[index]),
            ),
          ),
        );
      },
    );
  }
}

class _WallCard extends StatelessWidget {
  final Wallpaper wallpaper;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _WallCard({
    required this.wallpaper,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: wallpaper.thumbnailUrl,
                cacheManager: VXImageCacheManager.instance,
                memCacheWidth: 540,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surface),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: _RoundButton(
                  icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  onTap: onSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WallListTile extends StatelessWidget {
  final Wallpaper wallpaper;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _WallListTile({
    required this.wallpaper,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: wallpaper.thumbnailUrl,
                  cacheManager: VXImageCacheManager.instance,
                  memCacheWidth: 720,
                  width: 84,
                  height: 112,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wallpaper.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 5),
                    Text('${wallpaper.series} • ${wallpaper.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.65))),
                    const SizedBox(height: 4),
                    Text(wallpaper.resolution, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.55))),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSave,
                icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _WallpaperViewer extends StatefulWidget {
  final List<Wallpaper> wallpapers;
  final int initialIndex;
  final Set<String> savedIds;
  final Future<void> Function(Wallpaper) onToggleSaved;

  const _WallpaperViewer({
    required this.wallpapers,
    required this.initialIndex,
    required this.savedIds,
    required this.onToggleSaved,
  });

  @override
  State<_WallpaperViewer> createState() => _WallpaperViewerState();
}

class _WallpaperViewerState extends State<_WallpaperViewer> {
  late final PageController _pages;
  late int _index;
  bool _showInfo = false;
  bool _showSetAs = false;
  bool _busy = false;

  Wallpaper get wall => widget.wallpapers[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  double _pillItemX(BuildContext context, int index) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pillWidth = VXPillTheme.contextualWidth.clamp(220.0, screenWidth - 24).toDouble();
    final left = (screenWidth - pillWidth) / 2;
    const horizontalPadding = 7.0;
    const firstWidth = 58.0;
    final remaining = pillWidth - horizontalPadding * 2 - firstWidth;
    final slot = remaining / 4;
    if (index == 0) return left + horizontalPadding + firstWidth / 2;
    return left + horizontalPadding + firstWidth + slot * (index - .5);
  }

  Future<File> _getFile() async {
    final FileInfo? cached = await VXImageCacheManager.instance.getFileFromCache(wall.imageUrl);
    if (cached != null) return cached.file;
    return VXImageCacheManager.instance.getSingleFile(wall.imageUrl);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _getFile();
      await ImageGallerySaver.saveFile(file.path);
      if (mounted) _notice('Saved to gallery');
    } catch (_) {
      if (mounted) _notice('Could not save wallpaper');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setWallpaper(int location) async {
    if (_busy) return;
    setState(() { _busy = true; _showSetAs = false; });
    try {
      final file = await _getFile();
      final ok = await WallpaperManager.setWallpaperFromFile(file.path, location);
      if (mounted) _notice(ok ? 'Wallpaper applied' : 'Could not apply wallpaper');
    } catch (_) {
      if (mounted) _notice('Could not apply wallpaper');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 220,
        margin: EdgeInsets.only(bottom: 102 + MediaQuery.paddingOf(context).bottom),
        duration: const Duration(milliseconds: 1300),
        content: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.savedIds.contains(wall.id);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: widget.wallpapers.length,
            onPageChanged: (value) => setState(() {
              _index = value;
              _showInfo = false;
              _showSetAs = false;
            }),
            itemBuilder: (_, index) {
              final current = widget.wallpapers[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 3.5,
                child: SizedBox.expand(
                  child: CachedNetworkImage(
                    imageUrl: current.imageUrl,
                    cacheManager: VXImageCacheManager.instance,
                    memCacheWidth: 1080,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator.adaptive()),
                    errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white)),
                  ),
                ),
              );
            },
          ),
          const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: _TopScrim(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: VXHeader(
                title: 'VX Walls',
                compact: true,
                foregroundColor: Colors.white,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(.28), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_index + 1}/${widget.wallpapers.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
            ),
          ),
          VXPill(
            mode: VXPillMode.contextual,
            items: [
              VXPillItem(
                label: 'Home',
                iconWidget: VXBrandMark(size: 21, compact: true, color: VXPillTheme.iconColor),
                onTap: () => Navigator.of(context).pop(),
              ),
              VXPillItem(
                icon: Icons.wallpaper_rounded,
                label: 'Set',
                selected: _showSetAs,
                onTap: () => setState(() { _showSetAs = !_showSetAs; _showInfo = false; }),
              ),
              VXPillItem(
                icon: Icons.info_outline_rounded,
                label: 'Info',
                selected: _showInfo,
                onTap: () => setState(() { _showInfo = !_showInfo; _showSetAs = false; }),
              ),
              VXPillItem(
                icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: 'Like',
                selected: saved,
                onTap: () async { await widget.onToggleSaved(wall); if (mounted) setState(() {}); },
              ),
              VXPillItem(
                icon: Icons.download_rounded,
                label: _busy ? 'Wait' : 'Save',
                onTap: _save,
              ),
            ],
          ),
          if (_showInfo)
            VXPillCallout(
              targetX: _pillItemX(context, 2),
              width: 292,
              child: _WallpaperInfo(wallpaper: wall),
            ),
          if (_showSetAs)
            VXPillCallout(
              targetX: _pillItemX(context, 1),
              width: 240,
              child: _SetAsMenu(onSelect: _setWallpaper),
            ),
        ],
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x00000000)],
        ),
      ),
    );
  }
}

class _WallpaperInfo extends StatelessWidget {
  final Wallpaper wallpaper;
  const _WallpaperInfo({required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoRow(label: 'Name', value: wallpaper.name),
      _InfoRow(label: 'Series', value: wallpaper.series),
      _InfoRow(label: 'Category', value: wallpaper.category),
      if (wallpaper.author.trim().isNotEmpty) _InfoRow(label: 'Artist', value: wallpaper.author),
      _InfoRow(label: 'Source', value: wallpaper.source),
      _InfoRow(label: 'Size', value: wallpaper.resolution),
      _InfoRow(label: 'Fit', value: wallpaper.isPortrait ? 'Portrait • screen ready' : 'Adaptive crop'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF77777E), fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF17171A), fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _SetAsMenu extends StatelessWidget {
  final Future<void> Function(int location) onSelect;
  const _SetAsMenu({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SetRow(icon: Icons.home_outlined, label: 'Home screen', onTap: () => onSelect(WallpaperManager.HOME_SCREEN)),
          _SetRow(icon: Icons.lock_outline_rounded, label: 'Lock screen', onTap: () => onSelect(WallpaperManager.LOCK_SCREEN)),
          _SetRow(icon: Icons.smartphone_rounded, label: 'Both screens', onTap: () => onSelect(WallpaperManager.BOTH_SCREEN)),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SetRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [Icon(icon, size: 19, color: const Color(0xFF17171A)), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Color(0xFF17171A), fontWeight: FontWeight.w700))]),
      ),
    );
  }
}

class _SettingsView extends StatefulWidget {
  final ThemeMode themeMode;
  final _DisplayMode displayMode;
  final Future<void> Function(int index) onThemeChanged;
  final Future<void> Function(_DisplayMode mode) onDisplayChanged;

  const _SettingsView({
    required this.themeMode,
    required this.displayMode,
    required this.onThemeChanged,
    required this.onDisplayChanged,
  });

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((value) {
      if (mounted) setState(() => _packageInfo = value);
    });
  }

  int get _themeIndex => widget.themeMode == ThemeMode.light ? 1 : widget.themeMode == ThemeMode.dark ? 2 : 0;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 126.0 + MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 4, 0, bottomPadding),
              children: [
                const _SectionTitle('Settings'),
                const SizedBox(height: 14),
                const _SettingsLabel('Appearance'),
                const SizedBox(height: 8),
                _Segmented(
                  labels: const ['System', 'Light', 'Dark'],
                  selected: _themeIndex,
                  onChanged: (index) async { await widget.onThemeChanged(index); if (mounted) setState(() {}); },
                ),
                const SizedBox(height: 24),
                const _SettingsLabel('Display'),
                const SizedBox(height: 8),
                _Segmented(
                  labels: const ['Grid', 'List'],
                  selected: widget.displayMode == _DisplayMode.grid ? 0 : 1,
                  onChanged: (index) async { await widget.onDisplayChanged(index == 0 ? _DisplayMode.grid : _DisplayMode.list); if (mounted) setState(() {}); },
                ),
                const SizedBox(height: 26),
                const _SettingsLabel('About'),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.16)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Walls worth keeping.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -.3)),
                      SizedBox(height: 7),
                      Text('A small, curated collection made for screens — not a wallpaper dump.', style: TextStyle(height: 1.45)),
                      SizedBox(height: 12),
                      Text('Made by Avinash • Created with ❤️ & ⌨️', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsRow(label: 'Version', value: _packageInfo == null ? '1.0.x' : '${_packageInfo!.version} (${_packageInfo!.buildNumber})'),
                const _SettingsRow(label: 'Public build', value: '1.0'),
                const _SettingsRow(label: 'Check for updates', value: 'Current'),
                const _SettingsRow(label: 'Change log', value: 'View'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.8));
}

class _SettingsLabel extends StatelessWidget {
  final String text;
  const _SettingsLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.65)));
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const _Segmented({required this.labels, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: active ? vxAccent.withOpacity(.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(labels[index], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: active ? vxAccent : null)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  const _SettingsRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text(value, style: TextStyle(fontSize: 12.5, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.6), fontWeight: FontWeight.w700))]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _EmptyState({required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.45)),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 7),
            Text(body, textAlign: TextAlign.center, style: TextStyle(height: 1.45, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.65))),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
