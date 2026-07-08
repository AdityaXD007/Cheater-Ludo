/// Centralizes all tunable parameters for the rigged dice engine.
/// Adjust these values to change rigging intensity, anti-detection
/// behavior, and hard mode thresholds without touching engine logic.
class RiggingConfig {
  // --- Bias probabilities ---
  /// Probability of applying bias on the winner's turn (normal mode).
  final double normalWinnerBias;

  /// Probability of applying bias on a loser's turn (normal mode).
  final double normalLoserBias;

  /// Probability of applying bias on the winner's turn (hard mode).
  final double hardWinnerBias;

  /// Probability of applying bias on a loser's turn (hard mode).
  final double hardLoserBias;

  /// Bias probability when winner is blowing out (dampened to avoid suspicion).
  final double blowoutBias;

  /// Bias probability applied when trailing winner has pieces at home (probabilistic priority 6s).
  final double prioritySixTrailingBias;

  /// Probability that the winner ignores a low roll (<4) that lands on a safe square, in favor of better pacing.
  final double ignoreLowSafeSquareProbability;

  /// Probability of winner being sabotaged when bias flip fails (probabilistic split).
  final double winnerSabotageProbabilityWhenNoBias;

  /// Naturalizer rate applied to winner when trailing (softened naturalizer bypass).
  final double trailingWinnerNaturalizerRate;

  // --- Anti-detection ---
  /// Fraction of turns where bias is skipped entirely (disabled in hard mode).
  final double globalNaturalizerRate;

  /// Minimum grace turns granted after a long unfavorable streak.
  final int graceTurnMin;

  /// Maximum grace turns granted after a long unfavorable streak.
  final int graceTurnMax;

  /// Number of consecutive unfavorable rolls before grace turns kick in.
  final int unfavorableStreakThreshold;

  /// Number of early-game turns that are always pure random.
  final int earlyGameTurnCount;

  // --- Hard mode hysteresis ---
  /// Score gap at which hard mode activates (loser ahead by this much).
  final double hardModeEnterGap;

  /// Score gap at which hard mode deactivates (must drop below this).
  final double hardModeExitGap;

  // --- Blowout detection ---
  /// If winner leads ALL losers by at least this much, bias is dampened.
  final double blowoutGapThreshold;

  // --- Emergency sabotage ---
  /// Probability of forcing unfavorable roll on an emergency-sabotage target.
  final double emergencySabotageProbability;
  // --- Target Bias Adjustments ---
  /// Maximum bias probability allowed when a loser's piece is in the home stretch (51-55).
  /// This flat cap ensures Hard Mode doesn't skew near-finish rolls too heavily.
  final double nearFinishLoserBiasCap;

  /// Base stuck turn limit for a non-winner's 4th piece.
  final int dynamicStuckCapBase;

  /// Absolute maximum stuck turn limit for a non-winner's 4th piece.
  final int dynamicStuckCapMax;

  const RiggingConfig({
    this.normalWinnerBias = 0.75,
    this.normalLoserBias = 0.35,
    this.hardWinnerBias = 0.85,
    this.hardLoserBias = 0.75,
    this.blowoutBias = 0.10,
    this.prioritySixTrailingBias = 0.95,
    this.ignoreLowSafeSquareProbability = 0.75,
    this.winnerSabotageProbabilityWhenNoBias = 0.05,
    this.trailingWinnerNaturalizerRate = 0.05,
    this.globalNaturalizerRate = 0.15,
    this.graceTurnMin = 1,
    this.graceTurnMax = 2,
    this.unfavorableStreakThreshold = 5,
    this.earlyGameTurnCount = 3,
    this.hardModeEnterGap = 2.0,
    this.hardModeExitGap = -3.0,
    this.blowoutGapThreshold = 15.0,
    this.emergencySabotageProbability = 0.90,
    this.nearFinishLoserBiasCap = 0.20,
    this.dynamicStuckCapBase = 3,
    this.dynamicStuckCapMax = 6,
  });

  static const RiggingConfig defaults = RiggingConfig();
}

/// Debug information emitted for each roll when a debug hook is attached.
/// Only constructed in debug/profile builds (gated by assert or kDebugMode).
class RollDebugInfo {
  final int playerId;
  final int roll;
  final String layerName;
  final String reason;
  final bool isWinner;

  const RollDebugInfo({
    required this.playerId,
    required this.roll,
    required this.layerName,
    required this.reason,
    required this.isWinner,
  });

  @override
  String toString() =>
      'Roll=$roll player=$playerId winner=$isWinner layer=$layerName reason=$reason';
}
