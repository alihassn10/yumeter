/// Route paths, kept in one place so screens never hard-code a string.
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const onboarding = '/onboarding';
  static const creatingPlan = '/creating-plan';
  static const planReveal = '/plan';
  static const paywall = '/paywall';

  // Home shell tabs.
  static const today = '/today';
  static const analytics = '/analytics';
  static const meals = '/meals';
  static const settings = '/settings';

  // Logging flow.
  static const scan = '/scan';
  static const mealResult = '/meal-result';
  static const foodSearch = '/food-search';
  static const barcodeScan = '/barcode';

  /// A packaged food to log; the product travels as `extra`.
  static const foodProduct = '/food';
  static const quickAdd = '/quick-add';

  /// One logged meal, full screen above the tabs.
  static const mealDetailPattern = '/meal/:id';
  static String mealDetail(String id) => '/meal/$id';

  static const deleteAccount = '/settings/delete-account';

  // Legal documents, open to everyone including before sign-in.
  static const privacy = '/legal/privacy';
  static const terms = '/legal/terms';
}
