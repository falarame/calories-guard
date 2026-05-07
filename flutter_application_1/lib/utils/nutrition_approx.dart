/// Helpers for showing approximate nutrition numbers with a tilde (~) prefix.
abstract final class NutritionApprox {
  NutritionApprox._();

  static num _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  /// Rounded integer display: "~596".
  static String tildeRound(num n) => '~${n.round()}';

  /// Fixed decimals: "~29.5".
  static String tildeFixed(num n, int fractionDigits) =>
      fractionDigits <= 0 ? tildeRound(n) : '~${n.toStringAsFixed(fractionDigits)}';

  /// "~596 kcal"
  static String kcal(num n) => '~${n.round()} kcal';

  /// Dynamic JSON values (recipe/API): grams or other amounts as "~180".
  static String tildeDynamic(dynamic v, {int fractionDigits = 0}) {
    final n = _asNum(v);
    return fractionDigits > 0 ? tildeFixed(n, fractionDigits) : tildeRound(n);
  }

  /// Expanded meal row on Home: "~596 kcal • P:~29g C:~69g F:~21g"
  static String mealMacroLine(num cal, num p, num c, num f) =>
      '${tildeRound(cal)} kcal • '
      'P:${tildeRound(p)}g C:${tildeRound(c)}g F:${tildeRound(f)}g';
}
