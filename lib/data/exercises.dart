/// Exercise database: bilingual names, muscle group, equipment, form cues.
/// Static data — no storage needed.
library;

class Exercise {
  final String id;
  final String nameEn;
  final String nameBn;
  final String muscle; // chest|back|legs|shoulders|arms|core
  final String equipment; // barbell|dumbbell|machine|cable|bodyweight
  final String cueEn;
  final String cueBn;

  const Exercise({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.muscle,
    required this.equipment,
    required this.cueEn,
    required this.cueBn,
  });
}

const exercises = <Exercise>[
  // Chest
  Exercise(id: 'bench_press', nameEn: 'Bench Press', nameBn: 'বেঞ্চ প্রেস', muscle: 'chest', equipment: 'barbell', cueEn: 'Shoulder blades pinched, bar touches mid-chest.', cueBn: 'কাঁধের পাখনা চেপে ধরুন, বার বুকের মাঝে নামান।'),
  Exercise(id: 'incline_db_press', nameEn: 'Incline DB Press', nameBn: 'ইনক্লাইন ডাম্বেল প্রেস', muscle: 'chest', equipment: 'dumbbell', cueEn: 'Bench at 30°, press up in a slight arc.', cueBn: 'বেঞ্চ ৩০° কাত করুন, হালকা বাঁকে উপরে তুলুন।'),
  Exercise(id: 'pushup', nameEn: 'Push-Up', nameBn: 'পুশ-আপ', muscle: 'chest', equipment: 'bodyweight', cueEn: 'Body in one line, chest to fist-height.', cueBn: 'শরীর এক লাইনে, বুক মুঠো-উচ্চতায় নামান।'),
  Exercise(id: 'cable_fly', nameEn: 'Cable Fly', nameBn: 'কেবল ফ্লাই', muscle: 'chest', equipment: 'cable', cueEn: 'Slight elbow bend, hug a big tree.', cueBn: 'কনুই হালকা বাঁকা, বড় গাছ জড়িয়ে ধরার মতো।'),
  // Back
  Exercise(id: 'deadlift', nameEn: 'Deadlift', nameBn: 'ডেডলিফট', muscle: 'back', equipment: 'barbell', cueEn: 'Push the floor away, lats tight, neutral spine.', cueBn: 'মেঝে ঠেলে দিন, পিঠ টানটান, মেরুদণ্ড সোজা।'),
  Exercise(id: 'pullup', nameEn: 'Pull-Up', nameBn: 'পুল-আপ', muscle: 'back', equipment: 'bodyweight', cueEn: 'Chest to bar, no swinging.', cueBn: 'বুক বারে ঠেকান, দোলা দেবেন না।'),
  Exercise(id: 'barbell_row', nameEn: 'Barbell Row', nameBn: 'বারবেল রো', muscle: 'back', equipment: 'barbell', cueEn: 'Hinge ~45°, pull bar to lower ribs.', cueBn: '৪৫° ঝুঁকে বার পাঁজরের নিচে টানুন।'),
  Exercise(id: 'lat_pulldown', nameEn: 'Lat Pulldown', nameBn: 'ল্যাট পুলডাউন', muscle: 'back', equipment: 'machine', cueEn: 'Drive elbows down to your ribs.', cueBn: 'কনুই পাঁজরের দিকে নামিয়ে আনুন।'),
  Exercise(id: 'seated_row', nameEn: 'Seated Cable Row', nameBn: 'সিটেড কেবল রো', muscle: 'back', equipment: 'cable', cueEn: 'Squeeze shoulder blades at the back.', cueBn: 'পেছনে কাঁধের পাখনা চেপে ধরুন।'),
  Exercise(id: 'db_row', nameEn: 'One-Arm DB Row', nameBn: 'একহাতে ডাম্বেল রো', muscle: 'back', equipment: 'dumbbell', cueEn: 'Flat back, pull dumbbell to hip.', cueBn: 'পিঠ সমান রেখে ডাম্বেল কোমরের দিকে টানুন।'),
  // Legs
  Exercise(id: 'squat', nameEn: 'Barbell Squat', nameBn: 'স্কোয়াট', muscle: 'legs', equipment: 'barbell', cueEn: 'Knees track toes, hit parallel or below.', cueBn: 'হাঁটু পায়ের আঙুল বরাবর, প্যারালাল পর্যন্ত বসুন।'),
  Exercise(id: 'leg_press', nameEn: 'Leg Press', nameBn: 'লেগ প্রেস', muscle: 'legs', equipment: 'machine', cueEn: "Don't lock knees hard at the top.", cueBn: 'উপরে হাঁটু শক্ত করে লক করবেন না।'),
  Exercise(id: 'romanian_deadlift', nameEn: 'Romanian Deadlift', nameBn: 'রোমানিয়ান ডেডলিফট', muscle: 'legs', equipment: 'barbell', cueEn: 'Hinge at hips, feel hamstrings stretch.', cueBn: 'কোমর থেকে ঝুঁকুন, হ্যামস্ট্রিং টান অনুভব করুন।'),
  Exercise(id: 'leg_curl', nameEn: 'Leg Curl', nameBn: 'লেগ কার্ল', muscle: 'legs', equipment: 'machine', cueEn: 'Control the negative, no hip lift.', cueBn: 'ধীরে নামান, কোমর তুলবেন না।'),
  Exercise(id: 'leg_extension', nameEn: 'Leg Extension', nameBn: 'লেগ এক্সটেনশন', muscle: 'legs', equipment: 'machine', cueEn: 'Squeeze quads at the top.', cueBn: 'উপরে কোয়াড চেপে ধরুন।'),
  Exercise(id: 'calf_raise', nameEn: 'Calf Raise', nameBn: 'কাফ রেইজ', muscle: 'legs', equipment: 'machine', cueEn: 'Full stretch at bottom, pause at top.', cueBn: 'নিচে পুরো প্রসারিত, উপরে থামুন।'),
  Exercise(id: 'lunge', nameEn: 'Walking Lunge', nameBn: 'লাঞ্জ', muscle: 'legs', equipment: 'dumbbell', cueEn: 'Long step, front knee over ankle.', cueBn: 'লম্বা পা ফেলুন, হাঁটু গোড়ালির উপরে।'),
  Exercise(id: 'goblet_squat', nameEn: 'Goblet Squat', nameBn: 'গবলেট স্কোয়াট', muscle: 'legs', equipment: 'dumbbell', cueEn: 'Dumbbell at chest, elbows inside knees.', cueBn: 'ডাম্বেল বুকে, কনুই হাঁটুর ভেতরে।'),
  // Shoulders
  Exercise(id: 'overhead_press', nameEn: 'Overhead Press', nameBn: 'ওভারহেড প্রেস', muscle: 'shoulders', equipment: 'barbell', cueEn: 'Glutes tight, press bar behind ears line.', cueBn: 'নিতম্ব শক্ত, বার কানের রেখায় তুলুন।'),
  Exercise(id: 'lateral_raise', nameEn: 'Lateral Raise', nameBn: 'ল্যাটারাল রেইজ', muscle: 'shoulders', equipment: 'dumbbell', cueEn: 'Lead with elbows, stop at shoulder height.', cueBn: 'কনুই আগে তুলুন, কাঁধ-উচ্চতায় থামুন।'),
  Exercise(id: 'face_pull', nameEn: 'Face Pull', nameBn: 'ফেস পুল', muscle: 'shoulders', equipment: 'cable', cueEn: 'Pull rope to forehead, rotate knuckles back.', cueBn: 'দড়ি কপালে টানুন, হাতের গাঁট পেছনে ঘোরান।'),
  Exercise(id: 'shrug', nameEn: 'Barbell Shrug', nameBn: 'শ্রাগ', muscle: 'shoulders', equipment: 'barbell', cueEn: 'Lift shoulders to ears, 1s hold.', cueBn: 'কাঁধ কান পর্যন্ত তুলে ১ সেকেন্ড ধরুন।'),
  // Arms
  Exercise(id: 'barbell_curl', nameEn: 'Barbell Curl', nameBn: 'বারবেল কার্ল', muscle: 'arms', equipment: 'barbell', cueEn: 'Elbows pinned, no swinging.', cueBn: 'কনুই স্থির, দোলা নয়।'),
  Exercise(id: 'db_curl', nameEn: 'Dumbbell Curl', nameBn: 'ডাম্বেল কার্ল', muscle: 'arms', equipment: 'dumbbell', cueEn: 'Supinate at the top.', cueBn: 'উপরে হাতের তালু ঘোরান।'),
  Exercise(id: 'hammer_curl', nameEn: 'Hammer Curl', nameBn: 'হ্যামার কার্ল', muscle: 'arms', equipment: 'dumbbell', cueEn: 'Neutral grip, like holding hammers.', cueBn: 'নিরপেক্ষ গ্রিপ, হাতুড়ি ধরার মতো।'),
  Exercise(id: 'pushdown', nameEn: 'Tricep Pushdown', nameBn: 'ট্রাইসেপ পুশডাউন', muscle: 'arms', equipment: 'cable', cueEn: 'Elbows glued to sides, full lockout.', cueBn: 'কনুই শরীরের সাথে, পুরো সোজা করুন।'),
  Exercise(id: 'overhead_tri_ext', nameEn: 'Overhead Tricep Ext', nameBn: 'ওভারহেড ট্রাইসেপ', muscle: 'arms', equipment: 'dumbbell', cueEn: 'Upper arms still, stretch at bottom.', cueBn: 'উপরের হাত স্থির, নিচে প্রসারিত করুন।'),
  // Core
  Exercise(id: 'plank', nameEn: 'Plank', nameBn: 'প্ল্যাংক', muscle: 'core', equipment: 'bodyweight', cueEn: 'Squeeze glutes, breathe behind the brace.', cueBn: 'নিতম্ব চাপুন, পেট শক্ত রেখে শ্বাস নিন।'),
  Exercise(id: 'leg_raise', nameEn: 'Hanging Leg Raise', nameBn: 'হ্যাংগিং লেগ রেইজ', muscle: 'core', equipment: 'bodyweight', cueEn: 'Curl pelvis up, no swinging.', cueBn: 'শ্রোণী উপরে বাঁকান, দোলা নয়।'),
  Exercise(id: 'cable_crunch', nameEn: 'Cable Crunch', nameBn: 'কেবল ক্রাঞ্চ', muscle: 'core', equipment: 'cable', cueEn: 'Crunch ribs to hips, hips still.', cueBn: 'পাঁজর কোমরের দিকে বাঁকান।'),
];

final exerciseById = {for (final e in exercises) e.id: e};
