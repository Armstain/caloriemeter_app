/// Home tab: daily progress hero + capture + quick add.
library;

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../core/config.dart';
import '../core/lang.dart';
import '../core/nutrition.dart';
import '../data/app_db.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'fooddb_screen.dart';
import 'results.dart';

class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Lang.of(context);
    final settings = ref.watch(settingsProvider);
    final totals = ref.watch(todayTotalsProvider);
    final entries = ref.watch(todayEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(lang.t('appName'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayEntriesProvider);
          ref.invalidate(todayTotalsProvider);
          ref.invalidate(waterProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            totals.when(
              data: (t) => _HeroCard(
                kcal: t.kcal,
                macros: t.macros,
                calorieGoal: settings?.calorieGoal ?? AppConfig.defaultCalorieGoal,
                proteinGoal: settings?.proteinGoal ?? 90,
                gymMode: (settings?.goalPath ?? GoalPath.general) == GoalPath.gym,
              ),
              loading: () => const SizedBox(
                  height: 140, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            _CaptureCard(onImage: (file) => _analyze(context, ref, file)),
            const SizedBox(height: 16),
            Text(lang.t('home.quickAdd'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _QuickAddRow(),
            const SizedBox(height: 16),
            entries.when(
              data: (list) => list.isEmpty
                  ? _EmptyState()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('diary.entries'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...list.reversed.map((e) => _EntryTile(entry: e)),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze(BuildContext context, WidgetRef ref, File imageFile) async {
    final settings = ref.read(settingsProvider);
    final apiKey = await settings?.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Lang.of(context).t('onboarding.apiKeyTitle'))),
        );
        ref.read(tabProvider.notifier).state = 4; // settings tab
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnalysisScreen(imageFile: imageFile, apiKey: apiKey),
    ));
  }
}

class _HeroCard extends ConsumerWidget {
  final double kcal;
  final Macros macros;
  final int calorieGoal;
  final int proteinGoal;
  final bool gymMode;
  const _HeroCard(
      {required this.kcal,
      required this.macros,
      required this.calorieGoal,
      required this.proteinGoal,
      required this.gymMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Lang.of(context);
    final water = ref.watch(waterProvider).valueOrNull ?? 0;
    final heroLabel = gymMode ? lang.t('home.todayProtein') : lang.t('home.todayCalories');
    final heroValue = gymMode ? macros.protein : kcal;
    final heroGoal = gymMode ? proteinGoal : calorieGoal;
    final heroUnit = gymMode ? 'g' : lang.t('common.kcal');
    final progress = heroGoal > 0 ? (heroValue / heroGoal).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heroLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(lang.num(heroValue.round()),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(' $heroUnit ${lang.t('home.ofGoal')} ${lang.num(heroGoal)}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 10),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat(lang.t('common.protein'), '${lang.num(macros.protein.round())}g',
                    '${lang.num(proteinGoal)}g'),
                _miniStat(lang.t('common.carbs'), '${lang.num(macros.carbs.round())}g', ''),
                _miniStat(lang.t('common.fat'), '${lang.num(macros.fat.round())}g', ''),
                _miniStat(lang.t('diary.water'), '${lang.num((water / 1000))}L', ''),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.water_drop_outlined),
                label: Text(lang.t('diary.addWater')),
                onPressed: () async {
                  await AppDb.addWater(AppDb.todayKey(), 250);
                  ref.invalidate(waterProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, String goal) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (goal.isNotEmpty)
            Text('/ $goal', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

class _CaptureCard extends StatelessWidget {
  final Future<void> Function(File) onImage;
  const _CaptureCard({required this.onImage});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCamera(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(
            children: [
              const Icon(Icons.camera_alt, size: 48),
              const SizedBox(height: 8),
              Text(lang.t('home.tapToCapture'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(lang.t('home.tapToCaptureDesc'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCamera(BuildContext context) async {
    List<CameraDescription> cameras = [];
    try {
      cameras = await availableCameras();
    } catch (_) {}
    if (!context.mounted) return;
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Lang.of(context).t('common.error'))),
      );
      return;
    }
    final file = await Navigator.of(context).push<File?>(
      MaterialPageRoute(builder: (_) => _CameraView(cameras: cameras)),
    );
    if (file != null) await onImage(file);
  }
}

class _CameraView extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraView({required this.cameras});

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  CameraController? _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final back = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
    _controller!.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    if (_controller == null || !_controller!.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await _controller!.takePicture();
      final compressed = await _compress(File(shot.path));
      if (mounted) Navigator.of(context).pop<File>(compressed);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Lang.of(context).t('common.error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Downscale + JPEG compress to stay under the 1MB API limit.
  Future<File> _compress(File src) async {
    final bytes = await src.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return src;
    var w = decoded.width;
    if (w > 1600) {
      final resized = img.copyResize(decoded, width: 1600);
      w = resized.width;
      final out = img.encodeJpg(resized, quality: AppConfig.imageQuality);
      return _writeTemp(out);
    }
    var quality = AppConfig.imageQuality;
    var out = img.encodeJpg(decoded, quality: quality);
    while (out.length > AppConfig.maxImageBytes && quality > 40) {
      quality -= 10;
      out = img.encodeJpg(decoded, quality: quality);
    }
    return _writeTemp(out);
  }

  Future<File> _writeTemp(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/meal_${DateTime.now().millisecondsSinceEpoch}.jpg');
    return f.writeAsBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(c),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : FloatingActionButton.large(
                            onPressed: _take,
                            child: const Icon(Icons.camera),
                          ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuickAddRow extends ConsumerWidget {
  const _QuickAddRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Staple food IDs from the bundled DB; falls back silently if missing.
    const staples = ['ruti', 'egg_boiled', 'dudh_cha', 'banana'];
    return FutureBuilder(
      future: ref.watch(foodDbProvider.future),
      builder: (context, snap) {
        final db = snap.data;
        if (db == null) return const SizedBox.shrink();
        final items =
            staples.map(db.byId).whereType<DbFood>().toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = items[i];
              final lang = Lang.of(context);
              final name = lang.locale == 'bn' && f.nameBn.isNotEmpty
                  ? f.nameBn
                  : f.nameEn;
              return ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(name),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FoodDbScreen(preselect: f),
                )),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(lang.t('home.noEntries'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(lang.t('home.noEntriesDesc'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  final FoodEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Lang.of(context);
    final names = entry.foods.map((f) => f.name).join(', ');
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(lang.t('diary.delete')),
            content: Text(lang.t('diary.confirmDelete')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(lang.t('common.cancel'))),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(lang.t('common.delete'))),
            ],
          ),
        );
        return ok ?? false;
      },
      onDismissed: (_) async {
        await AppDb.deleteEntry(entry.id);
        ref.invalidate(todayEntriesProvider);
        ref.invalidate(todayTotalsProvider);
      },
      child: Card(
        child: ListTile(
          leading: entry.imagePath != null && File(entry.imagePath!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(entry.imagePath!),
                      width: 56, height: 56, fit: BoxFit.cover),
                )
              : const Icon(Icons.restaurant_outlined, size: 40),
          title: Text(names,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${_mealLabel(lang, entry.mealType)} · ${lang.num(entry.totalCalories.round())} ${lang.t('common.kcal')} · ${lang.num(entry.totalMacros.protein.round())}g ${lang.t('common.protein')}'),
        ),
      ),
    );
  }

  String _mealLabel(Lang lang, String type) {
    const keys = {
      'breakfast': 'results.breakfast',
      'lunch': 'results.lunch',
      'dinner': 'results.dinner',
      'snack': 'results.snack',
      'sehri': 'results.sehri',
      'iftar': 'results.iftar',
    };
    return lang.t(keys[type] ?? 'results.snack');
  }
}
