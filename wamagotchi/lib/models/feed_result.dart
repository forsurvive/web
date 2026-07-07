/// 저장(밥 주기) 한 번의 정산 결과. UI가 스낵바·다이얼로그 표시에 사용한다.
class FeedResult {
  /// 새로 늘어난 글자 수 (공백 제외)
  final int gainedChars;

  final int manaGained;
  final int expGained;
  final int levelsGained;

  /// 이번 정산으로 부화 레벨에 도달해 이름 입력이 필요해졌는가
  final bool justHatched;

  const FeedResult({
    required this.gainedChars,
    required this.manaGained,
    required this.expGained,
    required this.levelsGained,
    required this.justHatched,
  });

  static const FeedResult empty = FeedResult(
    gainedChars: 0,
    manaGained: 0,
    expGained: 0,
    levelsGained: 0,
    justHatched: false,
  );
}
