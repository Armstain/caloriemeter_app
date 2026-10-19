/// Pre-built training routines. Static data.
library;

class RoutineExercise {
  final String exerciseId;
  final int sets;
  final String reps; // "8-10", "max", "45s"
  const RoutineExercise(this.exerciseId, this.sets, this.reps);
}

class Routine {
  final String id;
  final String nameEn;
  final String nameBn;
  final String descEn;
  final String descBn;
  final String level; // beginner|intermediate
  final String daysEn;
  final String daysBn;
  final List<RoutineExercise> blocks;

  const Routine({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.descEn,
    required this.descBn,
    required this.level,
    required this.daysEn,
    required this.daysBn,
    required this.blocks,
  });
}

const routines = <Routine>[
  Routine(
    id: 'fullbody_ab',
    nameEn: 'Full Body A/B',
    nameBn: 'ফুল বডি A/B',
    descEn: 'Best for beginners. Alternate A and B, 3 days a week.',
    descBn: 'নতুনদের জন্য সেরা। A ও B পাল্টাপাল্টি, সপ্তাহে ৩ দিন।',
    level: 'beginner',
    daysEn: '3 days/week',
    daysBn: 'সপ্তাহে ৩ দিন',
    blocks: [
      // A
      RoutineExercise('squat', 3, '8-10'),
      RoutineExercise('bench_press', 3, '8-10'),
      RoutineExercise('barbell_row', 3, '8-10'),
      RoutineExercise('overhead_press', 2, '10-12'),
      RoutineExercise('plank', 3, '45s'),
      // B
      RoutineExercise('deadlift', 3, '5'),
      RoutineExercise('lat_pulldown', 3, '8-10'),
      RoutineExercise('incline_db_press', 3, '8-10'),
      RoutineExercise('leg_curl', 2, '10-12'),
      RoutineExercise('leg_raise', 3, '12'),
    ],
  ),
  Routine(
    id: 'ppl',
    nameEn: 'Push / Pull / Legs',
    nameBn: 'পুশ / পুল / লেগস',
    descEn: 'Classic split. Run 3 or 6 days a week.',
    descBn: 'জনপ্রিয় স্প্লিট। সপ্তাহে ৩ বা ৬ দিন চালান।',
    level: 'intermediate',
    daysEn: '3-6 days/week',
    daysBn: 'সপ্তাহে ৩-৬ দিন',
    blocks: [
      // Push
      RoutineExercise('bench_press', 4, '6-8'),
      RoutineExercise('overhead_press', 3, '8-10'),
      RoutineExercise('incline_db_press', 3, '8-10'),
      RoutineExercise('lateral_raise', 3, '12-15'),
      RoutineExercise('pushdown', 3, '10-12'),
      RoutineExercise('pushup', 2, 'max'),
      // Pull
      RoutineExercise('deadlift', 3, '5'),
      RoutineExercise('pullup', 3, 'max'),
      RoutineExercise('barbell_row', 4, '8-10'),
      RoutineExercise('face_pull', 3, '12-15'),
      RoutineExercise('barbell_curl', 3, '10-12'),
      RoutineExercise('hammer_curl', 2, '10-12'),
      // Legs
      RoutineExercise('squat', 4, '6-8'),
      RoutineExercise('romanian_deadlift', 3, '8-10'),
      RoutineExercise('leg_press', 3, '10-12'),
      RoutineExercise('leg_curl', 3, '10-12'),
      RoutineExercise('leg_extension', 2, '12-15'),
      RoutineExercise('calf_raise', 4, '12-15'),
    ],
  ),
  Routine(
    id: 'upper_lower',
    nameEn: 'Upper / Lower',
    nameBn: 'আপার / লোয়ার',
    descEn: 'Balanced 4-day split. Alternate upper and lower days.',
    descBn: 'সুষম ৪ দিনের স্প্লিট। আপার-লোয়ার পাল্টাপাল্টি।',
    level: 'intermediate',
    daysEn: '4 days/week',
    daysBn: 'সপ্তাহে ৪ দিন',
    blocks: [
      // Upper
      RoutineExercise('bench_press', 4, '6-8'),
      RoutineExercise('barbell_row', 4, '8-10'),
      RoutineExercise('overhead_press', 3, '8-10'),
      RoutineExercise('lat_pulldown', 3, '8-10'),
      RoutineExercise('db_curl', 2, '10-12'),
      RoutineExercise('overhead_tri_ext', 2, '10-12'),
      // Lower
      RoutineExercise('squat', 4, '6-8'),
      RoutineExercise('romanian_deadlift', 3, '8-10'),
      RoutineExercise('leg_press', 3, '10-12'),
      RoutineExercise('leg_curl', 3, '10-12'),
      RoutineExercise('calf_raise', 4, '12-15'),
    ],
  ),
  Routine(
    id: 'db_home',
    nameEn: 'Dumbbell Only (Home)',
    nameBn: 'শুধু ডাম্বেল (বাসা)',
    descEn: 'No gym needed. One pair of dumbbells, 3 days a week.',
    descBn: 'জিম লাগবে না। এক জোড়া ডাম্বেল, সপ্তাহে ৩ দিন।',
    level: 'beginner',
    daysEn: '3 days/week',
    daysBn: 'সপ্তাহে ৩ দিন',
    blocks: [
      RoutineExercise('goblet_squat', 3, '10-12'),
      RoutineExercise('pushup', 3, 'max'),
      RoutineExercise('db_row', 3, '10-12'),
      RoutineExercise('overhead_press', 3, '10-12'),
      RoutineExercise('romanian_deadlift', 3, '10-12'),
      RoutineExercise('lunge', 2, '12'),
      RoutineExercise('db_curl', 2, '12'),
      RoutineExercise('overhead_tri_ext', 2, '12'),
      RoutineExercise('plank', 3, '45s'),
    ],
  ),
];

final routineById = {for (final r in routines) r.id: r};
