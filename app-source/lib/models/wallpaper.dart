class Wallpaper {
  final String id;
  final String name;
  final String imageUrl;
  final String thumbnailUrl;
  final String author;
  final String series;
  final String category;
  final String source;
  final String sourceUrl;
  final String license;
  final int width;
  final int height;

  const Wallpaper({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.author,
    required this.series,
    required this.category,
    required this.source,
    required this.sourceUrl,
    required this.license,
    required this.width,
    required this.height,
  });

  factory Wallpaper.fromPicsum(Map<String, dynamic> json) {
    final id = json['id'].toString();
    return Wallpaper(
      id: id,
      name: 'Wallpaper $id',
      imageUrl: 'https://picsum.photos/id/$id/1080/1920',
      thumbnailUrl: 'https://picsum.photos/id/$id/540/960',
      author: json['author']?.toString() ?? 'Picsum Artist',
      series: 'Discovery',
      category: 'Photography',
      source: 'Picsum',
      sourceUrl: 'https://picsum.photos',
      license: '',
      width: (json['width'] as num?)?.toInt() ?? 1080,
      height: (json['height'] as num?)?.toInt() ?? 1920,
    );
  }

  factory Wallpaper.fromCatalogJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? json['imageUrl'] ?? '').toString();
    final imageUrl = _catalogAssetUrl(rawUrl);
    final rawThumb = (json['thumbnail_url'] ?? json['thumbnailUrl'] ?? rawUrl).toString();
    final thumbnailUrl = _catalogAssetUrl(rawThumb);

    final rawSource = json['source'];
    String sourceName = 'VX Walls Library';
    String sourceUrl = '';
    if (rawSource is Map<String, dynamic>) {
      sourceName = (rawSource['name'] ?? rawSource['repository'] ?? rawSource['provider'] ?? 'VX Walls Library').toString();
      sourceUrl = (rawSource['html_url'] ?? rawSource['url'] ?? rawSource['source_url'] ?? '').toString();
    } else if (rawSource != null) {
      final value = rawSource.toString();
      sourceUrl = value.startsWith('http') ? value : '';
      sourceName = _friendlySource(value);
    }

    return Wallpaper(
      id: (json['id'] ?? rawUrl).toString(),
      name: (json['name'] ?? json['title'] ?? 'Untitled').toString(),
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      author: (json['artist'] ?? json['author'] ?? '').toString(),
      series: (json['series'] ?? 'VX Curated').toString(),
      category: (json['category'] ?? 'Wallpaper').toString(),
      source: sourceName.isEmpty ? 'VX Walls Library' : _friendlySource(sourceName),
      sourceUrl: sourceUrl,
      license: (json['license'] ?? '').toString(),
      width: (json['width'] as num?)?.toInt() ?? 1080,
      height: (json['height'] as num?)?.toInt() ?? 1920,
    );
  }

  static String _catalogAssetUrl(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final path = value.startsWith('/') ? value.substring(1) : value;
    return 'https://raw.githubusercontent.com/avinashrautai/vx-walls-data/main/$path';
  }

  static String _friendlySource(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('raw.githubusercontent.com') || lower.contains('github.com/avinashrautai/vx-walls-data')) {
      return 'VX Walls Library';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host.replaceFirst('www.', '');
    }
    return value.isEmpty ? 'VX Walls Library' : value;
  }

  factory Wallpaper.fromJson(Map<String, dynamic> json) => Wallpaper(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Untitled',
        imageUrl: json['imageUrl']?.toString() ?? '',
        thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
        author: json['author']?.toString() ?? '',
        series: json['series']?.toString() ?? 'VX Curated',
        category: json['category']?.toString() ?? 'Wallpaper',
        source: json['source']?.toString() ?? 'VX Walls Library',
        sourceUrl: json['sourceUrl']?.toString() ?? '',
        license: json['license']?.toString() ?? '',
        width: (json['width'] as num?)?.toInt() ?? 1080,
        height: (json['height'] as num?)?.toInt() ?? 1920,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
        'author': author,
        'series': series,
        'category': category,
        'source': source,
        'sourceUrl': sourceUrl,
        'license': license,
        'width': width,
        'height': height,
      };

  factory Wallpaper.demo(int number) {
    final id = ((number - 1) % 100 + 1).toString();
    return Wallpaper(
      id: id,
      name: 'Wallpaper $id',
      imageUrl: 'https://picsum.photos/id/$id/1080/1920',
      thumbnailUrl: 'https://picsum.photos/id/$id/540/960',
      author: 'Picsum Artist',
      series: 'Discovery',
      category: 'Photography',
      source: 'Picsum',
      sourceUrl: 'https://picsum.photos',
      license: '',
      width: 1080,
      height: 1920,
    );
  }

  String get resolution => '${width}×$height';
  bool get isPortrait => height >= width;
}
