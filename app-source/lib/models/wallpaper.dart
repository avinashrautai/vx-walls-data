class Wallpaper {
  final String id;
  final String imageUrl;
  final String thumbnailUrl;
  final String author;
  final String source;
  final int width;
  final int height;

  const Wallpaper({required this.id, required this.imageUrl, required this.thumbnailUrl, required this.author, required this.source, required this.width, required this.height});

  factory Wallpaper.fromPicsum(Map<String, dynamic> json) {
    final id = json['id'].toString();
    return Wallpaper(id: id, imageUrl: 'https://picsum.photos/id/$id/1080/1920', thumbnailUrl: 'https://picsum.photos/id/$id/540/960', author: json['author']?.toString() ?? 'Picsum Artist', source: 'Picsum', width: (json['width'] as num?)?.toInt() ?? 1080, height: (json['height'] as num?)?.toInt() ?? 1920);
  }

  factory Wallpaper.fromCatalogJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? json['imageUrl'] ?? '').toString();
    final imageUrl = _catalogAssetUrl(rawUrl);
    final rawThumb = (json['thumbnail_url'] ?? json['thumbnailUrl'] ?? rawUrl).toString();
    final thumbnailUrl = _catalogAssetUrl(rawThumb);
    final source = json['source'];
    final sourceName = source is Map<String, dynamic> ? (source['repository'] ?? source['html_url'] ?? 'VX Library').toString() : (source?.toString() ?? 'VX Library');
    return Wallpaper(id: (json['id'] ?? rawUrl).toString(), imageUrl: imageUrl, thumbnailUrl: thumbnailUrl, author: (json['author'] ?? 'VX Curated').toString(), source: sourceName, width: (json['width'] as num?)?.toInt() ?? 1080, height: (json['height'] as num?)?.toInt() ?? 1920);
  }

  static String _catalogAssetUrl(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final path = value.startsWith('/') ? value.substring(1) : value;
    return 'https://raw.githubusercontent.com/avinashrautai/vx-walls-data/main/$path';
  }

  factory Wallpaper.fromJson(Map<String, dynamic> json) => Wallpaper(id: json['id'] as String, imageUrl: json['imageUrl'] as String, thumbnailUrl: json['thumbnailUrl'] as String, author: json['author'] as String, source: json['source'] as String, width: (json['width'] as num).toInt(), height: (json['height'] as num).toInt());

  Map<String, dynamic> toJson() => {'id': id, 'imageUrl': imageUrl, 'thumbnailUrl': thumbnailUrl, 'author': author, 'source': source, 'width': width, 'height': height};

  factory Wallpaper.demo(int number) {
    final id = ((number - 1) % 100 + 1).toString();
    return Wallpaper(id: id, imageUrl: 'https://picsum.photos/id/$id/1080/1920', thumbnailUrl: 'https://picsum.photos/id/$id/540/960', author: 'Picsum Artist', source: 'Picsum', width: 1080, height: 1920);
  }
}
