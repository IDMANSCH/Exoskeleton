enum Flavor { dev, staging, production }

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return '[Dev] Exoskeleton Leg';
      case Flavor.staging:
        return '[Stg] Exoskeleton Leg';
      case Flavor.production:
        return 'Exoskeleton Leg';
      default:
        return 'title';
    }
  }
}
