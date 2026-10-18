class PersonalWhiteboardItem {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String bgTheme;
  final int strokeCount;
  final String? previewSnippet;

  const PersonalWhiteboardItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.bgTheme = 'gridMath',
    this.strokeCount = 0,
    this.previewSnippet,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'bgTheme': bgTheme,
    'strokeCount': strokeCount,
    'previewSnippet': previewSnippet,
  };

  factory PersonalWhiteboardItem.fromJson(Map<String, dynamic> json) =>
      PersonalWhiteboardItem(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        title: json['title'] as String? ?? 'سبورة بدون عنوان',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        bgTheme: json['bgTheme'] as String? ?? 'gridMath',
        strokeCount: (json['strokeCount'] as num?)?.toInt() ?? 0,
        previewSnippet: json['previewSnippet'] as String?,
      );

  PersonalWhiteboardItem copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bgTheme,
    int? strokeCount,
    String? previewSnippet,
  }) => PersonalWhiteboardItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    bgTheme: bgTheme ?? this.bgTheme,
    strokeCount: strokeCount ?? this.strokeCount,
    previewSnippet: previewSnippet ?? this.previewSnippet,
  );
}
