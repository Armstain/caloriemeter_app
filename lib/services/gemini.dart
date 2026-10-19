/// Gemini client: direct REST calls with the web app's model fallback order,
/// plus a Bangladesh-tuned analysis prompt.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../data/models.dart';

class GeminiException implements Exception {
  final String message;
  final int? statusCode;
  GeminiException(this.message, [this.statusCode]);
  @override
  String toString() => 'GeminiException($statusCode): $message';
}

class GeminiClient {
  final String apiKey;
  GeminiClient(this.apiKey);

  static const _bdPrompt = '''
Analyze this food photo. The user is in BANGLADESH. Return JSON only, exactly this shape:
{
  "foods": [
    {
      "name": "food name (English, specific)",
      "nameBn": "food name in Bangla script if known, else ''",
      "calories": number,
      "quantity": "portion, e.g. '1.5 plates bhaat', '2 pieces rui machh'",
      "confidence": 0.0-1.0,
      "ingredients": ["..."],
      "cookingMethod": "grilled|fried|baked|steamed|raw|boiled|roasted",
      "macros": {"protein": g, "carbs": g, "fat": g, "fiber": g},
      "category": "protein|vegetable|grain|fruit|dairy|snack|beverage",
      "healthScore": 1-10
    }
  ],
  "mealType": "breakfast|lunch|dinner|snack",
  "totalMacros": {"protein": g, "carbs": g, "fat": g, "fiber": g}
}

BANGLADESH FOOD KNOWLEDGE (use it):
- Staples: bhaat (steamed white rice, ~130 kcal/100g cooked; a "plate" is ~250-300g), ruti (~120 kcal each), paratha (~250 kcal, fried), khichuri, tehari, biriyani, pulao.
- Curries are usually shared family-style: estimate the portion ON THE PLATE, not the serving bowl. Common: rui/katla/pangas/tilapia/ilisha machh (fish curry, 1 piece ~80-120g fish), murgir mangsho (chicken curry), gorur mangsho (beef), dim bhuna/bhaji (egg), dal (lentils, thin), alu bhorta/bharta (mashed potato with mustard oil), shutki (dried fish).
- Home cooking uses generous oil: if the curry looks oily add ~1-2 tbsp oil (120-240 kcal) split across the portion.
- Street food: shingara (~150 kcal each), piaju, beguni, chotpoti, fuchka (~40 kcal each), jhalmuri, pitha (seasonal rice cakes).
- Sweets: roshogolla (~125 kcal each), chomchom, sandesh, mishti doi.
- Drinks: dudh cha (milk tea with sugar, ~80 kcal/cup), rong cha (black tea), laban, borhani.
- If a nutrition label is visible, use its exact values with confidence 0.95.
- Be specific with names ("rui machh bhuna, 2 pieces") not ("fish curry"). Estimate macros from typical composition. Keep temperature low: be consistent, not creative.
''';

  Future<List<AnalyzedFood>> analyzeFood(String base64Jpeg) async {
    String lastError = 'unknown';
    for (final model in GeminiModels.fallbackOrder) {
      try {
        return await _tryModel(model, base64Jpeg);
      } on GeminiException catch (e) {
        // Auth errors: no point trying other models.
        if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 400) rethrow;
        lastError = e.message;
      } catch (e) {
        lastError = e.toString();
      }
    }
    throw GeminiException('Analysis failed on all models. $lastError');
  }

  Future<List<AnalyzedFood>> _tryModel(String model, String base64Jpeg) async {
    final url = Uri.parse('${GeminiModels.urls[model]}?key=$apiKey');
    final body = json.encode({
      'contents': [
        {
          'parts': [
            {'text': _bdPrompt},
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': base64Jpeg}
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'topK': 32,
        'topP': 1,
        'maxOutputTokens': 4096,
      },
    });
    http.Response resp;
    try {
      resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(GeminiModels.timeout);
    } on TimeoutException {
      throw GeminiException('Request timed out. Please try again.', 408);
    }
    if (resp.statusCode != 200) {
      throw GeminiException(_friendlyError(resp.statusCode, resp.body), resp.statusCode);
    }
    return _parseFoods(resp.body);
  }

  List<AnalyzedFood> _parseFoods(String body) {
    final data = json.decode(body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    final text = candidates?.firstOrNull?['content']?['parts']?.firstOrNull?['text'] as String?;
    if (text == null) throw GeminiException('Empty response from model.', 422);
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) throw GeminiException('Could not parse model response.', 422);
    final parsed = json.decode(match.group(0)!) as Map<String, dynamic>;
    final foods = (parsed['foods'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AnalyzedFood.fromJson)
        .where((f) => f.calories >= 0 && f.name.isNotEmpty)
        .toList();
    if (foods.isEmpty) {
      throw GeminiException(
          'Could not recognize any food. Try a clearer photo with the full plate visible.', 422);
    }
    return foods;
  }

  String _friendlyError(int status, String body) {
    switch (status) {
      case 401:
      case 403:
        return 'Invalid API key. Check your Gemini API key in Settings.';
      case 429:
        return 'Rate limit exceeded. Wait a moment and try again.';
      case 400:
        return 'Invalid request. Try a different image.';
      default:
        try {
          final err = (json.decode(body) as Map)['error'] as Map?;
          return 'API error: ${err?['message'] ?? 'status $status'}';
        } catch (_) {
          return 'API error: status $status';
        }
    }
  }

  /// Lightweight key check: tiny "Hello" call against the first model.
  Future<bool> validateKey(String key) async {
    try {
      final url = Uri.parse('${GeminiModels.urls[GeminiModels.fallbackOrder.first]}?key=$key');
      final resp = await http
          .post(url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'Hello'}
                    ]
                  }
                ]
              }))
          .timeout(const Duration(seconds: 15));
      return resp.statusCode != 401 && resp.statusCode != 403;
    } catch (_) {
      return false;
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
