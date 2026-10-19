# Caloriemeter — Flutter app

Bangladesh-first calorie & protein tracker. Bilingual (English/Bangla),
deep local food database, live market prices for the budget protein guide.

## Structure

- `lib/main.dart` — entry point
- `lib/core/` — config, nutrition math (Mifflin-St Jeor), JSON i18n
- `lib/data/` — models, sqflite storage, food DB loader, price service
- `lib/services/` — Gemini client (BYOK, model fallback), settings
- `lib/state/` — Riverpod providers
- `lib/ui/` — onboarding, capture, results, tracker, history, guide, settings
- `assets/food_db.json` — 375 foods: 328 from the Bangladesh Food
  Composition Table 2013 (FCTB-2013, INFS Dhaka), 47 cooked dishes /
  street foods / drinks as estimates
- `assets/prices_fallback.json` — last-known DAM prices, bundled as fallback

## Building

CI builds a debug APK on every push (`.github/workflows/flutter-apk.yml`).
The APK is attached to the workflow run as `caloriemeter-debug-apk`.

Locally: `cd flutter_app && flutter pub get && flutter run`

## Prices

`.github/workflows/dam-prices.yml` runs daily, scrapes dam.gov.bd
(`.github/scripts/scrape_dam_prices.py`), and commits `data/prices.json`.
The app fetches it from raw.githubusercontent.com with the bundled
fallback. Dhaka retail only, working days.

## Notes

- The Gemini API key is the user's own (BYOK), stored in secure storage.
- User corrections (food edits, price corrections) are stored on-device —
  they are the future training data for shared-plate intelligence.
- `FoodEntry` already carries `sharedMealId` / `cookedBy` / `correction`
  fields so v2 features need no migration.
