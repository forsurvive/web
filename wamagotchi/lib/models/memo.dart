/// 사용자가 작성한 메모 한 편.
class Memo {
  final String id;
  String title;
  String body;

  /// 마지막 저장 시점의 글자 수(공백 제외). 다음 저장 때 "늘어난 글자" 계산 기준.
  int charCount;

  final DateTime createdAt;
  DateTime updatedAt;

  Memo({
    required this.id,
    this.title = '',
    this.body = '',
    this.charCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayTitle => title.trim().isEmpty ? '(제목 없음)' : title.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'charCount': charCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      charCount: (json['charCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
