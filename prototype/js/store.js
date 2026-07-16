// LocalStorage-backed state — the prototype's stand-in for SwiftData.
// Shape mirrors the domain entities in Aura/Domain/Entities.

const Store = (() => {
  const KEY = 'aura-prototype-v1';

  const todayISO = (offset = 0) => {
    const d = new Date(Date.now() + offset * 86400000);
    return d.toISOString().slice(0, 10);
  };

  const blank = () => ({
    profile: null,           // {name, age, heightCm, sex, activityLevel, cycleTracking}
    goal: null,              // {kind, targetWeightKg, weeklyRateKg, startWeightKg, startDate}
    why: '',
    futureMe: '',
    letters: [],             // {id, text, deliverAt, deliveredAt}
    meals: [],               // {id, date, time(ms), mealType, name, kcal, p, c, f, fiber, favorite}
    water: [],               // {id, date, ml}
    activity: {},            // date → {steps, exerciseMinutes, workoutCompleted, sedentaryMinutes}
    sleep: {},               // date → hours
    panels: [],              // {id, date, weightKg, bodyFatPercent, leanBodyMassKg, muscle, waterPct, visceral, bone, proteinPct, bmi, bmr, metaAge, subcut}
    cycles: [],              // period start dates (ISO)
    collections: [],         // {id, name}
    wardrobe: [],            // {id, title, category, targetSize, notes, wishlist, fitStatus, pinned, image, collectionId}
    milestones: [],          // {kind, title, detail, date}
    foods: DEFAULT_FOODS,
  });

  // Small built-in catalog so search works out of the box (per 100 g).
  const DEFAULT_FOODS = [
    { name: 'Chicken breast, grilled', kcal: 165, p: 31, c: 0,  f: 3.6, fiber: 0 },
    { name: 'Greek yogurt 2%',         kcal: 73,  p: 10, c: 4,  f: 2,   fiber: 0 },
    { name: 'Eggs',                    kcal: 155, p: 13, c: 1,  f: 11,  fiber: 0 },
    { name: 'Salmon, baked',           kcal: 208, p: 20, c: 0,  f: 13,  fiber: 0 },
    { name: 'Lentils, cooked',         kcal: 116, p: 9,  c: 20, f: 0.4, fiber: 8 },
    { name: 'Brown rice, cooked',      kcal: 112, p: 2.6,c: 24, f: 0.9, fiber: 1.8 },
    { name: 'Oats, dry',               kcal: 389, p: 17, c: 66, f: 7,   fiber: 10 },
    { name: 'Banana',                  kcal: 89,  p: 1.1,c: 23, f: 0.3, fiber: 2.6 },
    { name: 'Avocado',                 kcal: 160, p: 2,  c: 9,  f: 15,  fiber: 7 },
    { name: 'Cottage cheese',          kcal: 98,  p: 11, c: 3.4,f: 4.3, fiber: 0 },
    { name: 'Almonds',                 kcal: 579, p: 21, c: 22, f: 50,  fiber: 12.5 },
    { name: 'Broccoli, steamed',       kcal: 35,  p: 2.4,c: 7,  f: 0.4, fiber: 3.3 },
    { name: 'Sweet potato, baked',     kcal: 90,  p: 2,  c: 21, f: 0.2, fiber: 3.3 },
    { name: 'Whey protein scoop (30g)',kcal: 380, p: 80, c: 8,  f: 3.5, fiber: 0 },
    { name: 'Feta cheese',             kcal: 264, p: 14, c: 4,  f: 21,  fiber: 0 },
  ];

  let state = null;

  function load() {
    if (state) return state;
    try {
      const raw = localStorage.getItem(KEY);
      state = raw ? Object.assign(blank(), JSON.parse(raw)) : blank();
    } catch {
      state = blank();
    }
    return state;
  }

  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch { /* quota — prototype-only */ }
  }

  function reset() {
    state = blank();
    save();
  }

  const uid = () => Math.random().toString(36).slice(2, 10);

  // Rich fixture so UX can be tested without 30 days of manual logging:
  // 30 days of meals/water/activity/sleep, 8 BIA panels trending well,
  // two cycle records, and a small wardrobe.
  function loadDemo() {
    reset();
    const s = state;
    s.profile = { name: 'Elif', age: 34, heightCm: 168, sex: 'female', activityLevel: 'moderate', cycleTracking: true };
    s.goal = { kind: 'fatLoss', targetWeightKg: 62, weeklyRateKg: 0.5, startWeightKg: 70, startDate: todayISO(-32) };
    s.why = 'To feel strong at 35 — and to wear the linen dress in September.';
    s.cycles = [todayISO(-50), todayISO(-22)];

    for (let i = 30; i >= 1; i--) {
      const date = todayISO(-i);
      const jitter = (seed) => (Math.sin(i * seed) + 1) / 2; // deterministic 0..1
      s.meals.push(
        { id: uid(), date, time: Date.parse(date + 'T08:30'), mealType: 'breakfast', name: 'Yogurt bowl with oats', kcal: 380, p: 28, c: 45, f: 10, fiber: 6, favorite: true },
        { id: uid(), date, time: Date.parse(date + 'T13:00'), mealType: 'lunch', name: 'Chicken salad', kcal: 520, p: 42, c: 28, f: 24, fiber: 7, favorite: false },
        { id: uid(), date, time: Date.parse(date + 'T19:30'), mealType: 'dinner', name: 'Salmon, rice & broccoli', kcal: 610, p: 38, c: 52, f: 22, fiber: 6, favorite: false },
      );
      if (jitter(3) > 0.5) {
        s.meals.push({ id: uid(), date, time: Date.parse(date + 'T16:00'), mealType: 'snack', name: 'Almonds & banana', kcal: 210, p: 5, c: 27, f: 10, fiber: 4, favorite: false });
      }
      s.water.push({ id: uid(), date, ml: 1700 + Math.round(jitter(5) * 800) });
      s.activity[date] = {
        steps: 6500 + Math.round(jitter(7) * 4500),
        exerciseMinutes: jitter(2) > 0.45 ? 35 : 10,
        workoutCompleted: jitter(2) > 0.45,
        sedentaryMinutes: 420 + Math.round(jitter(4) * 180),
      };
      s.sleep[date] = +(6.8 + jitter(6) * 1.4).toFixed(1);
    }
    // Today: a realistic mid-day state (breakfast + lunch logged, some
    // water and steps) so Momentum reads as a partial-credit day.
    const today = todayISO();
    s.meals.push(
      { id: uid(), date: today, time: Date.parse(today + 'T08:30'), mealType: 'breakfast', name: 'Yogurt bowl with oats', kcal: 380, p: 28, c: 45, f: 10, fiber: 6, favorite: true },
      { id: uid(), date: today, time: Date.parse(today + 'T13:00'), mealType: 'lunch', name: 'Chicken salad', kcal: 520, p: 42, c: 28, f: 24, fiber: 7, favorite: false },
    );
    s.water.push({ id: uid(), date: today, ml: 1250 });
    s.activity[today] = { steps: 6200, exerciseMinutes: 30, workoutCompleted: true, sedentaryMinutes: 300 };
    s.sleep[today] = 7.4;

    for (let k = 7; k >= 0; k--) {
      const daysAgo = k * 4;
      s.panels.push({
        id: uid(), date: todayISO(-daysAgo),
        weightKg: +(70 - (28 - daysAgo) * 0.068).toFixed(1),
        bodyFatPercent: +(29.5 - (28 - daysAgo) * 0.055).toFixed(1),
        leanBodyMassKg: null,
        muscle: +(26.0 + (28 - daysAgo) * 0.004).toFixed(2),
        waterPct: 52.4, visceral: 6, bone: 2.5, proteinPct: 16.8,
        bmi: null, bmr: null, metaAge: 31, subcut: 24.1,
      });
    }
    s.collections = [{ id: 'c1', name: 'September' }, { id: 'c2', name: 'Work' }];
    s.wardrobe = [
      { id: uid(), title: 'The linen dress', category: 'dress', targetSize: '38', notes: 'The reason for all of this.', wishlist: false, fitStatus: 'closer', pinned: true, image: null, collectionId: 'c1' },
      { id: uid(), title: 'Vintage jeans', category: 'jeans', targetSize: '28', notes: '', wishlist: false, fitStatus: 'almostFits', pinned: false, image: null, collectionId: 'c1' },
      { id: uid(), title: 'Cream blazer', category: 'jacket', targetSize: 'S', notes: 'For the promotion talk.', wishlist: true, fitStatus: 'dream', pinned: false, image: null, collectionId: 'c2' },
      { id: uid(), title: 'Slingback heels', category: 'shoes', targetSize: '38', notes: '', wishlist: true, fitStatus: 'fits', pinned: false, image: null, collectionId: null },
    ];
    s.milestones = [
      { kind: 'firstWeekComplete', title: 'First week complete', detail: 'Seven days of showing up. The habit is forming.', date: todayISO(-25) },
      { kind: 'momentum80Week', title: 'A week of high momentum', detail: 'Averaging 84 momentum for seven straight days.', date: todayISO(-12) },
    ];
    save();
  }

  return { load, save, reset, loadDemo, uid, todayISO };
})();
