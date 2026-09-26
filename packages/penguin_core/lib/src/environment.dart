/// Deployment tier for a penguinm app build, matching the five-tier CI/CD
/// pipeline (pre-alpha through prod). Drives tier-specific defaults such as
/// DEBUG-level logging below prod and license-bypass domain checks.
enum PenguinEnvironment {
  /// Local/dev builds, run outside CI.
  prealpha,

  /// `release/*` branch builds, deployed to the alpha cluster.
  alpha,

  /// Builds from a merge to `main`, deployed to beta.
  beta,

  /// Pre-release builds, upgrade-in-place tested on gamma.
  gamma,

  /// Tagged production releases.
  prod;

  /// Parses a [PenguinEnvironment] from its lowercase enum [name] (e.g.
  /// `PENGUIN_ENV=beta`); an unrecognised value falls back to [prealpha] so
  /// a misconfigured build degrades safely instead of crashing at startup.
  static PenguinEnvironment parse(String value) {
    for (final env in PenguinEnvironment.values) {
      if (env.name == value) return env;
    }
    return PenguinEnvironment.prealpha;
  }
}
