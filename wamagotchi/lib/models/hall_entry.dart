/// 명예의 전당 기록 — 은퇴한 역대 정령 (Phase 5, 시스템 기획서 9.2).
class HallEntry {
  final int generation;
  final String name;
  final String className;

  /// 이 생애 동안 함께 쓴 글자 수
  final int chars;

  /// 함께한 일수
  final int days;

  /// 은퇴 시점의 위치
  final String dungeonName;
  final int floor;

  final DateTime retiredAt;

  const HallEntry({
    required this.generation,
    required this.name,
    required this.className,
    required this.chars,
    required this.days,
    required this.dungeonName,
    required this.floor,
    required this.retiredAt,
  });

  Map<String, dynamic> toJson() => {
        'generation': generation,
        'name': name,
        'className': className,
        'chars': chars,
        'days': days,
        'dungeonName': dungeonName,
        'floor': floor,
        'retiredAt': retiredAt.toIso8601String(),
      };

  factory HallEntry.fromJson(Map<String, dynamic> json) => HallEntry(
        generation: (json['generation'] as num?)?.toInt() ?? 1,
        name: json['name'] as String? ?? '이름 없는 정령',
        className: json['className'] as String? ?? '모험가',
        chars: (json['chars'] as num?)?.toInt() ?? 0,
        days: (json['days'] as num?)?.toInt() ?? 1,
        dungeonName: json['dungeonName'] as String? ?? '휴지통 던전',
        floor: (json['floor'] as num?)?.toInt() ?? 1,
        retiredAt: json['retiredAt'] != null
            ? DateTime.parse(json['retiredAt'] as String)
            : DateTime.now(),
      );
}
