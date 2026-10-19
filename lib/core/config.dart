/// App-wide constants: Gemini models, price feed, defaults.
library;

class GeminiModels {
  static const urls = <String, String>{
    'gemini-2.5-flash':
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
    'gemini-2.5-pro':
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent',
    'gemini-2.5-flash-lite':
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent',
    'gemini-3-flash-preview':
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
    'gemini-3-pro-preview':
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview:generateContent',
  };

  /// Try in this order; mirrors the web app's FALLBACK_ORDER.
  static const fallbackOrder = <String>[
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3-pro-preview',
  ];

  static const timeout = Duration(seconds: 30);
}

class AppConfig {
  static const defaultCalorieGoal = 2000;
  static const defaultProteinPerKg = 1.8;
  static const dataRetentionDays = 30;
  static const maxImageBytes = 1024 * 1024; // 1MB, like the web app
  static const imageQuality = 80;

  /// Raw JSON published daily by .github/workflows/dam-prices.yml.
  static const priceFeedUrl =
      'https://raw.githubusercontent.com/Armstain/caloriemeter_app/main/data/prices.json';

  static const aiStudioUrl = 'https://aistudio.google.com';
}
