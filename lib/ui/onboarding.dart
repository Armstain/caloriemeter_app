/// Onboarding: language -> goal path -> profile -> targets -> API key.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/lang.dart';
import '../core/nutrition.dart';
import '../services/gemini.dart';
import '../services/settings.dart';

class OnboardingFlow extends StatefulWidget {
  final Settings settings;
  final VoidCallback onDone;
  final Future<void> Function(String) onLocaleChanged;
  const OnboardingFlow(
      {super.key, required this.settings, required this.onDone, required this.onLocaleChanged});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _page = PageController();
  int _step = 0;

  GoalPath _path = GoalPath.general;
  GymPhase _phase = GymPhase.maintain;
  Sex _sex = Sex.male;
  int _age = 25;
  double _height = 170;
  double _weight = 65;
  ActivityLevel _activity = ActivityLevel.moderate;
  final _keyCtrl = TextEditingController();
  bool _checkingKey = false;
  String? _keyError;

  static const _steps = 5;

  void _next() {
    if (_step < _steps - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_step > 0) {
      _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _finishProfile() async {
    final s = widget.settings;
    await s.setGoalPath(_path);
    await s.setPhase(_phase);
    await s.setSex(_sex);
    await s.setAge(_age);
    await s.setHeightCm(_height);
    await s.setWeightKg(_weight);
    await s.setActivity(_activity);
    final bmrVal = bmr(sex: _sex, weightKg: _weight, heightCm: _height, age: _age);
    final tdeeVal = tdee(bmrValue: bmrVal, activity: _activity);
    await s.setCalorieGoal(calorieTarget(path: _path, tdeeValue: tdeeVal, phase: _phase));
    await s.setProteinGoal(proteinTarget(path: _path, weightKg: _weight, phase: _phase));
    _next();
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.startsWith('AIza') && text.length > 20 && _keyCtrl.text.isEmpty) {
      setState(() => _keyCtrl.text = text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Lang.of(context).t('onboarding.apiKeyDetected'))),
        );
      }
    }
  }

  Future<void> _saveKeyAndFinish() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      widget.onDone();
      return;
    }
    if (!key.startsWith('AIza') || key.length < 20) {
      setState(() => _keyError = Lang.of(context).t('onboarding.apiKeyInvalid'));
      return;
    }
    setState(() {
      _checkingKey = true;
      _keyError = null;
    });
    final ok = await GeminiClient(key).validateKey(key);
    setState(() => _checkingKey = false);
    if (!ok) {
      setState(() => _keyError = Lang.of(context).t('onboarding.apiKeyInvalid'));
      return;
    }
    await widget.settings.setApiKey(key);
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              )
            : null,
        title: Text('${lang.num(_step + 1)} / ${lang.num(_steps)}'),
        centerTitle: true,
      ),
      body: PageView(
        controller: _page,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _step = i),
        children: [
          _languageStep(lang),
          _goalStep(lang),
          _profileStep(lang),
          _targetsStep(lang),
          _keyStep(lang),
        ],
      ),
    );
  }

  Widget _languageStep(Lang lang) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lang.t('onboarding.languageTitle'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(lang.t('onboarding.languageSubtitle')),
            const SizedBox(height: 32),
            _bigButton('English', lang.locale == 'en', () => widget.onLocaleChanged('en')),
            const SizedBox(height: 12),
            _bigButton('বাংলা', lang.locale == 'bn', () => widget.onLocaleChanged('bn')),
            const Spacer(),
            ElevatedButton(
              onPressed: _next,
              child: Text(lang.t('onboarding.continue')),
            ),
          ],
        ),
      );

  Widget _goalStep(Lang lang) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lang.t('onboarding.goalTitle'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _choiceCard(
              selected: _path == GoalPath.gym,
              title: lang.t('onboarding.goalGym'),
              subtitle: lang.t('onboarding.goalGymDesc'),
              icon: Icons.fitness_center,
              onTap: () => setState(() => _path = GoalPath.gym),
            ),
            const SizedBox(height: 12),
            _choiceCard(
              selected: _path == GoalPath.general,
              title: lang.t('onboarding.goalGeneral'),
              subtitle: lang.t('onboarding.goalGeneralDesc'),
              icon: Icons.favorite_outline,
              onTap: () => setState(() => _path = GoalPath.general),
            ),
            if (_path == GoalPath.gym) ...[
              const SizedBox(height: 16),
              Text(lang.t('onboarding.phase'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: GymPhase.values
                    .map((p) => ChoiceChip(
                          label: Text(lang.t('onboarding.phase${_phaseName(p)}')),
                          selected: _phase == p,
                          onSelected: (_) => setState(() => _phase = p),
                        ))
                    .toList(),
              ),
            ],
            const Spacer(),
            ElevatedButton(onPressed: _next, child: Text(lang.t('onboarding.continue'))),
          ],
        ),
      );

  String _phaseName(GymPhase p) =>
      p == GymPhase.bulk ? 'Bulk' : p == GymPhase.cut ? 'Cut' : 'Maintain';

  Widget _profileStep(Lang lang) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(lang.t('onboarding.profileTitle'), style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(lang.t('onboarding.sex'), style: theme.textTheme.titleMedium),
          Row(
            children: [
              ChoiceChip(
                  label: Text(lang.t('onboarding.male')),
                  selected: _sex == Sex.male,
                  onSelected: (_) => setState(() => _sex = Sex.male)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text(lang.t('onboarding.female')),
                  selected: _sex == Sex.female,
                  onSelected: (_) => setState(() => _sex = Sex.female)),
            ],
          ),
          const SizedBox(height: 16),
          _sliderRow(lang.t('onboarding.age'), lang.num(_age), _age.toDouble(), 14, 80,
              (v) => setState(() => _age = v.round())),
          _sliderRow(lang.t('onboarding.heightCm'), lang.num(_height.round()), _height, 140, 210,
              (v) => setState(() => _height = v)),
          _sliderRow(lang.t('onboarding.weightKg'), lang.num(_weight.round()), _weight, 35, 150,
              (v) => setState(() => _weight = v)),
          const SizedBox(height: 8),
          Text(lang.t('onboarding.activity'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...ActivityLevel.values.map((a) => RadioListTile<ActivityLevel>(
                title: Text(lang.t('onboarding.activity${_activityName(a)}')),
                value: a,
                groupValue: _activity,
                onChanged: (v) => setState(() => _activity = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _finishProfile, child: Text(lang.t('onboarding.continue'))),
        ],
      ),
    );
  }

  String _activityName(ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.light => 'Light',
        ActivityLevel.moderate => 'Moderate',
        ActivityLevel.active => 'Active',
        ActivityLevel.veryActive => 'VeryActive',
      };

  Widget _sliderRow(String label, String value, double current, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
        ),
        Slider(value: current, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _targetsStep(Lang lang) {
    final bmrVal = bmr(sex: _sex, weightKg: _weight, heightCm: _height, age: _age);
    final tdeeVal = tdee(bmrValue: bmrVal, activity: _activity);
    final cal = calorieTarget(path: _path, tdeeValue: tdeeVal, phase: _phase);
    final pro = proteinTarget(path: _path, weightKg: _weight, phase: _phase);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lang.t('onboarding.yourTargets'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(lang.t('onboarding.calorieTarget'),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(lang.num(cal),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(lang.t('common.kcal')),
                  const Divider(height: 32),
                  Text(lang.t('onboarding.proteinTarget'),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(lang.num(pro),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('g'),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(onPressed: _next, child: Text(lang.t('onboarding.continue'))),
        ],
      ),
    );
  }

  Widget _keyStep(Lang lang) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lang.t('onboarding.apiKeyTitle'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(lang.t('onboarding.apiKeyDesc')),
            const SizedBox(height: 12),
            Text(lang.t('onboarding.apiKeyHow'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            TextField(
              controller: _keyCtrl,
              decoration: InputDecoration(
                hintText: lang.t('onboarding.apiKeyHint'),
                border: const OutlineInputBorder(),
                errorText: _keyError,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) setState(() => _keyCtrl.text = data!.text!.trim());
                  },
                ),
              ),
              obscureText: true,
            ),
            const Spacer(),
            if (_checkingKey) const Center(child: CircularProgressIndicator()),
            if (!_checkingKey)
              ElevatedButton(
                onPressed: _saveKeyAndFinish,
                child: Text(lang.t('onboarding.done')),
              ),
            TextButton(
              onPressed: widget.onDone,
              child: Text(lang.t('onboarding.skip')),
            ),
          ],
        ),
      );

  Widget _bigButton(String label, bool selected, VoidCallback onTap) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          side: BorderSide(
              width: selected ? 2.5 : 1,
              color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 20)),
      );

  Widget _choiceCard(
      {required bool selected,
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap}) {
    return Card(
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            width: selected ? 2 : 1,
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
