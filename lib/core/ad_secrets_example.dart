/// TEMPLATE — copy this file to `ad_secrets.dart` and fill in your real AdMob
/// Ad Unit IDs. Keep `ad_secrets.dart` out of version control once it contains
/// production identifiers.
///
/// `ad_secrets.dart` in this repo is a copy of this template with the safe
/// Google **test** units left in place (see `AdSecrets.adsEnabled`, which is
/// `false` in this dependency-free build, so nothing is ever shown).
abstract final class AdSecrets {
  /// Set to `true` once a real ad SDK is linked and your IDs are filled in.
  static const bool adsEnabled = false;

  static const String androidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // TODO: replace with real ID
  static const String iosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716'; // TODO: replace with real ID

  static const String androidAppId =
      'ca-app-pub-3940256099942544~3347511713'; // TODO: replace with real ID
  static const String iosAppId =
      'ca-app-pub-3940256099942544~1458002511'; // TODO: replace with real ID
}
