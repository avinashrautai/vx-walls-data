import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallpaper.dart';

const String vxWallsCatalogUrl = 'https://raw.githubusercontent.com/avinashrautai/vx-walls-data/main/wallpapers.json';

abstract class WallpaperProvider {
  Future<List<Wallpaper>> fetchPage(int page, {int limit = 30});
}

class GitHubWallpaperProvider implements WallpaperProvider {
  final String catalogUrl;
  const GitHubWallpaperProvider({this.catalogUrl = vxWallsCatalogUrl});

  @override
  Future<List<Wallpaper>> fetchPage(int page, {int limit = 30}) async {
    final response = await http.get(Uri.parse(catalogUrl)).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('VX Walls library unavailable (${response.statusCode})');
    final root = jsonDecode(response.body);
    if (root is! Map<String, dynamic>) throw const FormatException('Invalid VX Walls catalog');
    final rawWalls = root['wallpapers'];
    if (rawWalls is! List) return <Wallpaper>[];
    final all = rawWalls.whereType<Map<String, dynamic>>().map(Wallpaper.fromCatalogJson).toList();
    final start = (page - 1) * limit;
    if (start >= all.length) return <Wallpaper>[];
    final end = (start + limit).clamp(0, all.length);
    return all.sublist(start, end);
  }
}

class PicsumWallpaperProvider implements WallpaperProvider {
  const PicsumWallpaperProvider();
  @override
  Future<List<Wallpaper>> fetchPage(int page, {int limit = 30}) async {
    final response = await http.get(Uri.parse('https://picsum.photos/v2/list?page=$page&limit=$limit')).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Wallpaper source unavailable (${response.statusCode})');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(Wallpaper.fromPicsum).toList();
  }
}

class WallpaperRepository {
  final WallpaperProvider provider;
  final SharedPreferences? preferences;
  static const String _cacheKey = 'wallpaperMetadataCache.v3';
  const WallpaperRepository({this.provider = const GitHubWallpaperProvider(), this.preferences});

  Future<List<Wallpaper>> fetchPage(int page, {int limit = 30}) async {
    try {
      final result = await provider.fetchPage(page, limit: limit);
      if (page == 1 || result.isNotEmpty) await _writeCache(result, append: page > 1);
      return result;
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) {
        final start = (page - 1) * limit;
        return cached.skip(start).take(limit).toList();
      }
      rethrow;
    }
  }

  Future<List<Wallpaper>> _readCache() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return <Wallpaper>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().map(Wallpaper.fromJson).toList();
    } catch (_) { return <Wallpaper>[]; }
  }

  Future<void> _writeCache(List<Wallpaper> page, {required bool append}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final existing = append ? await _readCache() : <Wallpaper>[];
    final merged = <String, Wallpaper>{for (final wallpaper in [...existing, ...page]) wallpaper.id: wallpaper}.values.toList();
    await prefs.setString(_cacheKey, jsonEncode(merged.map((wallpaper) => wallpaper.toJson()).toList()));
  }
}
