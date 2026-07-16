// JavaScript port of Aura/Domain — kept in lockstep with the Swift engines
// so the prototype's scores behave exactly like the native app's.
// Source of truth: Aura/Domain/Engines/*.swift + Support/HealthMath.swift.

const Engines = (() => {

  // ---------- HealthMath ----------
  const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

  const katchMcArdleBMR = (lbm) => 370 + 21.6 * lbm;

  function mifflinStJeorBMR(weightKg, heightCm, age, sex) {
    const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    if (sex === 'male') return base + 5;
    if (sex === 'female') return base - 161;
    return base - 78;
  }

  function estimatedLBM(weightKg, heightCm, sex) {
    return sex === 'male'
      ? 0.407 * weightKg + 0.267 * heightCm - 19.2
      : 0.252 * weightKg + 0.473 * heightCm - 48.3;
  }

  function weightedSlopePerDay(x, y, decay = 0.05) {
    if (x.length !== y.length || x.length < 3) return null;
    const latest = x[x.length - 1];
    const w = x.map(v => Math.exp(-decay * (latest - v)));
    const sw = w.reduce((a, b) => a + b, 0);
    if (sw <= 0) return null;
    const mx = x.reduce((a, v, i) => a + w[i] * v, 0) / sw;
    const my = y.reduce((a, v, i) => a + w[i] * v, 0) / sw;
    let num = 0, den = 0;
    for (let i = 0; i < x.length; i++) {
      num += w[i] * (x[i] - mx) * (y[i] - my);
      den += w[i] * (x[i] - mx) * (x[i] - mx);
    }
    return den > 1e-9 ? num / den : null;
  }

  const attainment = (actual, target) => target > 0 ? clamp(actual / target, 0, 1) : 1;

  // Full credit from 70% of target up to target, gentle falloff above.
  function adherenceWithOvershoot(actual, target) {
    if (target <= 0) return 1;
    const ratio = actual / target;
    if (ratio <= 1) return ratio >= 0.7 ? 1 : clamp(ratio / 0.7, 0, 1);
    return clamp(1 - (ratio - 1) * 1.5, 0, 1);
  }

  // ---------- ActivityLevel ----------
  const ACTIVITY = {
    sedentary:  { tdee: 1.2,   protein: 1.6, steps: 7000,  exercise: 20, label: 'Mostly seated',    detail: 'Desk days, little planned exercise' },
    light:      { tdee: 1.375, protein: 1.8, steps: 8000,  exercise: 25, label: 'Lightly active',   detail: 'Walks and 1–2 workouts a week' },
    moderate:   { tdee: 1.55,  protein: 2.0, steps: 9000,  exercise: 30, label: 'Moderately active',detail: '3–4 workouts a week' },
    active:     { tdee: 1.725, protein: 2.2, steps: 10000, exercise: 40, label: 'Active',           detail: 'Training most days' },
    veryActive: { tdee: 1.9,   protein: 2.4, steps: 12000, exercise: 50, label: 'Very active',      detail: 'Physical job or twice-daily training' },
  };

  // ---------- CycleEngine ----------
  const PHASE_NAMES = { menstrual: 'Menstrual', follicular: 'Follicular', ovulation: 'Ovulation', luteal: 'Luteal' };

  function phaseForDay(day, cycleLength) {
    const ovulationDay = cycleLength - 14;
    if (day < 6) return 'menstrual';
    if (day < ovulationDay - 1) return 'follicular';
    if (day <= ovulationDay + 1) return 'ovulation';
    return 'luteal';
  }

  function cycleState(records, dateISO) {
    const date = new Date(dateISO + 'T12:00:00');
    const starts = records.map(d => new Date(d + 'T12:00:00')).sort((a, b) => a - b)
      .filter(d => d <= date);
    if (!starts.length) return null;
    let length = 28;
    if (starts.length >= 2) {
      const gaps = [];
      for (let i = 1; i < starts.length; i++) {
        gaps.push(Math.round((starts[i] - starts[i - 1]) / 86400000));
      }
      const plausible = gaps.filter(g => g >= 20 && g <= 45);
      if (plausible.length) length = Math.round(plausible.reduce((a, b) => a + b, 0) / plausible.length);
    }
    const last = starts[starts.length - 1];
    const rawDay = Math.round((date - last) / 86400000) + 1;
    const day = Math.min(rawDay, length);
    return { phase: phaseForDay(day, length), dayInCycle: day, averageCycleLength: length };
  }

  function phaseRecommendation(phase) {
    const recs = {
      menstrual: {
        workout: 'Gentle movement — walking, mobility, light yoga',
        recovery: 'Prioritize rest; extra recovery days are productive this week',
        cardio: 'Easy zone-1/2 only, and only if it feels good',
        strength: 'Light technique work, no maxing',
        sleep: 'Aim for 8+ hours; iron-rich meals support energy',
        proteinAdj: 0, waterAdj: 250, calorieMult: 1.0,
      },
      follicular: {
        workout: 'Your power window — push strength and new personal bests',
        recovery: 'Normal recovery; energy and pain tolerance are highest',
        cardio: 'HIIT and intervals land best in this phase',
        strength: 'Progressive overload — add weight or reps',
        sleep: 'Standard 7.5–8 hours',
        proteinAdj: 0, waterAdj: 0, calorieMult: 1.0,
      },
      ovulation: {
        workout: 'Peak strength — great day for a big session',
        recovery: 'Warm up thoroughly; ligament laxity is slightly higher',
        cardio: 'Intensity is fine; keep form sharp',
        strength: 'Strong lifts, extra attention to joints',
        sleep: 'Standard 7.5–8 hours',
        proteinAdj: 0, waterAdj: 0, calorieMult: 1.0,
      },
      luteal: {
        workout: 'Moderate strength and steady cardio over intensity',
        recovery: 'Schedule extra rest; RPE runs higher this week',
        cardio: 'Zone-2 over HIIT — same fat-loss benefit, less strain',
        strength: 'Maintain loads; don’t chase records',
        sleep: 'Aim 8+ hours; sleep quality dips are normal now',
        proteinAdj: 10, waterAdj: 250, calorieMult: 1.06,
      },
    };
    return { phase, ...recs[phase] };
  }

  // ---------- GoalEngine ----------
  function targets(profile, goal, latestPanel, phase) {
    const weightKg = latestPanel ? latestPanel.weightKg : goal.startWeightKg;
    let lbm = null, lowConfidence = true;
    if (latestPanel) {
      if (latestPanel.leanBodyMassKg) { lbm = latestPanel.leanBodyMassKg; lowConfidence = false; }
      else if (latestPanel.bodyFatPercent != null) { lbm = weightKg * (1 - latestPanel.bodyFatPercent / 100); lowConfidence = false; }
    }
    if (lbm == null) lbm = estimatedLBM(weightKg, profile.heightCm, profile.sex);

    const bmr = lowConfidence
      ? mifflinStJeorBMR(weightKg, profile.heightCm, profile.age, profile.sex)
      : katchMcArdleBMR(lbm);
    const act = ACTIVITY[profile.activityLevel] || ACTIVITY.moderate;
    const tdee = bmr * act.tdee;

    let calories;
    if (goal.kind === 'maintenance') {
      calories = tdee;
    } else {
      const dailyDeficit = goal.weeklyRateKg * 7700 / 7;
      calories = Math.max(tdee - dailyDeficit, Math.max(bmr * 0.8, tdee * 0.75));
    }

    let proteinAdj = 0, waterAdj = 0, sleepHours = 7.5;
    if (phase && profile.cycleTracking) {
      const rec = phaseRecommendation(phase);
      calories *= rec.calorieMult;
      proteinAdj = rec.proteinAdj;
      waterAdj = rec.waterAdj;
      if (phase === 'luteal' || phase === 'menstrual') sleepHours = 8;
    }

    const protein = lbm * act.protein + proteinAdj;
    const fat = Math.max(0.8 * weightKg, calories * 0.25 / 9);
    const carbs = Math.max((calories - protein * 4 - fat * 9) / 4, 50);
    const fiber = calories / 1000 * 14;
    const water = weightKg * 33 + waterAdj;

    return {
      calories: Math.round(calories),
      proteinG: Math.round(protein),
      carbsG: Math.round(carbs),
      fatG: Math.round(fat),
      fiberG: Math.round(fiber),
      waterMl: Math.round(water / 50) * 50,
      steps: act.steps,
      exerciseMinutes: act.exercise,
      sleepHours,
      isLowConfidence: lowConfidence,
    };
  }

  // ---------- MomentumEngine ----------
  const MOMENTUM_WEIGHTS = {
    calories: 0.20, protein: 0.18, water: 0.12, workout: 0.15, neat: 0.12,
    sleep: 0.10, mealTiming: 0.05, cycleCompliance: 0.04, habits: 0.04,
  };
  const MOMENTUM_NAMES = {
    calories: 'Calories', protein: 'Protein', water: 'Water', workout: 'Workout',
    neat: 'Movement', sleep: 'Sleep', mealTiming: 'Meal timing',
    cycleCompliance: 'Cycle sync', habits: 'Habits',
  };

  function momentum(metrics, t) {
    const components = [];
    const add = (metric, score, detail) => components.push({
      metric, name: MOMENTUM_NAMES[metric],
      score: clamp(score, 0, 1), weight: MOMENTUM_WEIGHTS[metric], detail,
    });

    add('calories', adherenceWithOvershoot(metrics.calories, t.calories),
        `${Math.round(metrics.calories)} of ${t.calories} kcal`);
    add('protein', attainment(metrics.proteinG, t.proteinG),
        `${Math.round(metrics.proteinG)} of ${t.proteinG} g`);
    add('water', attainment(metrics.waterMl, t.waterMl),
        `${Math.round(metrics.waterMl)} of ${t.waterMl} ml`);

    if (metrics.activity) {
      const a = metrics.activity;
      const workoutScore = a.workoutCompleted ? 1 : attainment(a.exerciseMinutes || 0, t.exerciseMinutes);
      add('workout', workoutScore, a.workoutCompleted ? 'Workout complete' : `${a.exerciseMinutes || 0} active minutes`);
      let neat = attainment(a.steps || 0, t.steps);
      if ((a.sedentaryMinutes || 0) > 600) neat *= 0.85;
      add('neat', neat, `${a.steps || 0} steps`);
    }
    if (metrics.sleepHours != null) {
      add('sleep', attainment(metrics.sleepHours, t.sleepHours),
          `${metrics.sleepHours.toFixed(1)} of ${t.sleepHours} h`);
    }
    if (metrics.mealTimes && metrics.mealTimes.length >= 2) {
      const times = [...metrics.mealTimes].sort();
      const spreadHours = (times[times.length - 1] - times[0]) / 3600000;
      const occasions = clamp(metrics.mealTimes.length / 3, 0, 1);
      const spread = clamp(spreadHours / 6, 0, 1);
      add('mealTiming', occasions * 0.5 + spread * 0.5, `${metrics.mealTimes.length} meals across the day`);
    } else if (metrics.mealTimes && metrics.mealTimes.length === 1) {
      add('mealTiming', 0.4, 'One meal logged so far');
    }
    if (metrics.followedCycle != null) {
      add('cycleCompliance', metrics.followedCycle ? 1 : 0.5,
          metrics.followedCycle ? 'Synced with your phase' : 'Off phase plan — still counts');
    }

    const totalWeight = components.reduce((a, c) => a + c.weight, 0);
    if (totalWeight <= 0) {
      return { overall: 0, components: [], headline: 'Log anything to start your day' };
    }
    components.forEach(c => c.weight = c.weight / totalWeight);
    const overall = Math.round(components.reduce((a, c) => a + c.score * c.weight, 0) * 100);
    components.sort((a, b) => b.score - a.score);

    let headline;
    if (overall >= 90) headline = 'A strong day — you’re building something.';
    else if (overall >= 75) headline = 'Solid consistency today.';
    else if (overall >= 50) headline = `${components[0].name} was your win today.`;
    else headline = 'Showing up is the whole game. You’re here.';
    return { overall, components, headline };
  }

  // ---------- NutritionEngine ----------
  function macroQuality(calories, proteinG, fatG, fiberG, t) {
    if (calories <= 0) return 0;
    const proteinShare = proteinG * 4 / calories;
    const targetShare = t.proteinG * 4 / Math.max(t.calories, 1);
    const proteinComponent = clamp(proteinShare / Math.max(targetShare, 0.01), 0, 1);
    const fatShare = fatG * 9 / calories;
    let fatComponent;
    if (fatShare >= 0.20 && fatShare <= 0.40) fatComponent = 1;
    else if (fatShare < 0.20) fatComponent = clamp(fatShare / 0.20, 0, 1);
    else fatComponent = clamp(1 - (fatShare - 0.40) * 2.5, 0, 1);
    const fiberComponent = attainment(fiberG, t.fiberG);
    return proteinComponent * 0.5 + fatComponent * 0.25 + fiberComponent * 0.25;
  }

  function nutritionScore(entries, t) {
    const sum = k => entries.reduce((a, e) => a + (e[k] || 0), 0);
    const calories = sum('kcal'), protein = sum('p'), fat = sum('f'), fiber = sum('fiber');
    const proteinScore = attainment(protein, t.proteinG);
    const calorieScore = adherenceWithOvershoot(calories, t.calories);
    const fiberScore = attainment(fiber, t.fiberG);
    const quality = macroQuality(calories, protein, fat, fiber, t);
    const overall = proteinScore * 0.35 + calorieScore * 0.35 + fiberScore * 0.10 + quality * 0.20;
    let grade = 'C';
    if (overall >= 0.93) grade = 'A+';
    else if (overall >= 0.85) grade = 'A';
    else if (overall >= 0.75) grade = 'B+';
    else if (overall >= 0.65) grade = 'B';
    else if (overall >= 0.50) grade = 'C+';
    return { overall, grade };
  }

  // ---------- HealthScoreEngine (per HealthScoreEngine.swift) ----------
  const HEALTH_WEIGHTS = {
    bodyFatTrend: 0.16, musclePreservation: 0.16, hydration: 0.10, sleep: 0.13,
    recovery: 0.09, nutritionQuality: 0.13, proteinAdequacy: 0.13,
    cycleHealth: 0.05, restingDays: 0.05,
  };
  const HEALTH_NAMES = {
    bodyFatTrend: 'Body fat trend', musclePreservation: 'Muscle preservation',
    hydration: 'Hydration', sleep: 'Sleep', recovery: 'Recovery',
    nutritionQuality: 'Nutrition quality', proteinAdequacy: 'Protein adequacy',
    cycleHealth: 'Cycle health', restingDays: 'Rest days',
  };

  function healthScore(panels, days) {
    // panels: [{daysAgo, bodyFatPercent, muscle}], days: [{metrics, targets}]
    const factors = [];
    const dayNum = p => p.daysAgo != null ? -p.daysAgo : 0;

    const bfSeries = panels.filter(p => p.bodyFatPercent != null);
    if (bfSeries.length >= 3) {
      const slope = weightedSlopePerDay(bfSeries.map(dayNum), bfSeries.map(p => p.bodyFatPercent));
      if (slope != null) {
        const score = clamp(0.6 + (-slope / 0.05) * 0.4, 0, 1);
        const trend = slope < -0.005 ? 'improving' : (slope > 0.01 ? 'declining' : 'stable');
        factors.push({
          kind: 'bodyFatTrend', score, trend,
          explanation: trend === 'improving' ? 'Body fat is trending down'
            : trend === 'stable' ? 'Body fat is holding steady'
            : 'Body fat ticked up — trends matter more than days',
        });
      }
    }
    const mSeries = panels.filter(p => p.muscle != null);
    if (mSeries.length >= 3) {
      const slope = weightedSlopePerDay(mSeries.map(dayNum), mSeries.map(p => p.muscle));
      if (slope != null) {
        const score = clamp(0.9 + slope * 20, 0, 1);
        const trend = slope > 0.002 ? 'improving' : (slope < -0.01 ? 'declining' : 'stable');
        factors.push({
          kind: 'musclePreservation', score, trend,
          explanation: trend === 'improving' ? 'Muscle is increasing while you lose fat — the best possible sign'
            : trend === 'stable' ? 'Muscle preserved during fat loss'
            : 'Muscle dipping — protein and strength work protect it',
        });
      }
    }

    const avgFactor = (kind, list, valueFn, good, weak) => {
      if (!list.length) return;
      const scores = list.map(valueFn);
      const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
      const mid = Math.floor(scores.length / 2);
      const h1 = scores.slice(0, mid), h2 = scores.slice(mid);
      const m1 = h1.length ? h1.reduce((a, b) => a + b, 0) / h1.length : 0;
      const m2 = h2.length ? h2.reduce((a, b) => a + b, 0) / h2.length : 0;
      const delta = m2 - m1;
      factors.push({
        kind, score: avg,
        trend: delta > 0.05 ? 'improving' : (delta < -0.05 ? 'declining' : 'stable'),
        explanation: avg >= 0.75 ? good : weak,
      });
    };

    if (days.length) {
      avgFactor('hydration', days, d => attainment(d.metrics.waterMl, d.targets.waterMl),
        'Hydration on target', 'Water has been running below target');
      const sleepDays = days.filter(d => d.metrics.sleepHours != null);
      avgFactor('sleep', sleepDays, d => attainment(d.metrics.sleepHours, d.targets.sleepHours),
        'Sleep is supporting recovery', 'Sleep slightly under what your body needs');
      avgFactor('proteinAdequacy', days, d => attainment(d.metrics.proteinG, d.targets.proteinG),
        'Protein excellent — muscle is protected', 'Protein below target on several days');
      avgFactor('nutritionQuality', days,
        d => macroQuality(d.metrics.calories, d.metrics.proteinG, d.metrics.fatG || 0, d.metrics.fiberG || 0, d.targets),
        'Calories are well spent — quality macros', 'Macro quality has room to improve');

      const activityDays = days.map(d => d.metrics.activity).filter(Boolean);
      if (activityDays.length >= 5) {
        const workouts = activityDays.filter(a => a.workoutCompleted).length;
        const rest = activityDays.length - workouts;
        const restScore = (rest >= 1 && workouts >= 2) ? 1 : ((rest >= 1 || workouts >= 2) ? 0.7 : 0.4);
        factors.push({
          kind: 'restingDays', score: restScore, trend: 'stable',
          explanation: restScore === 1 ? 'A healthy balance of training and rest'
            : 'Balance training with at least one full rest day',
        });
        const sedAvg = activityDays.reduce((a, x) => a + (x.sedentaryMinutes || 0), 0) / activityDays.length;
        const recovery = clamp(1.2 - sedAvg / 900, 0, 1);
        factors.push({
          kind: 'recovery', score: recovery, trend: recovery > 0.7 ? 'stable' : 'declining',
          explanation: recovery > 0.7 ? 'Active recovery looks good'
            : 'Long sedentary stretches — short walks will help',
        });
      }
      if (days.some(d => d.metrics.cycleState)) {
        factors.push({
          kind: 'cycleHealth', score: 1, trend: 'stable',
          explanation: 'Cycle tracked — targets are adapting to your phase',
        });
      }
    }

    if (!factors.length) {
      return { overall: 0, factors: [], reasons: ['Not enough data yet — log a few days to see your Health Score.'] };
    }
    factors.forEach(f => { f.name = HEALTH_NAMES[f.kind]; f.weight = HEALTH_WEIGHTS[f.kind] || 0.05; });
    const total = factors.reduce((a, f) => a + f.weight, 0);
    factors.forEach(f => f.weight = f.weight / total);
    const overall = Math.round(factors.reduce((a, f) => a + f.score * f.weight, 0) * 100);
    factors.sort((a, b) => b.score - a.score);

    let reasons = factors.slice(0, 3).filter(f => f.score >= 0.75).map(f => f.explanation);
    const weakest = factors[factors.length - 1];
    if (weakest && weakest.score < 0.75) reasons.push(weakest.explanation);
    if (!reasons.length) reasons = factors.slice(0, 2).map(f => f.explanation);
    return { overall, factors, reasons };
  }

  // ---------- PredictionEngine ----------
  function predict(panels, goal) {
    // panels: [{daysAgo, weightKg, bodyFatPercent, muscle}], newest = daysAgo 0-ish
    if (!panels.length) return null;
    const latest = panels[panels.length - 1];
    const xs = panels.map(p => -p.daysAgo);
    const wSlope = weightedSlopePerDay(xs, panels.map(p => p.weightKg));
    const bf = panels.filter(p => p.bodyFatPercent != null);
    const bfSlope = bf.length >= 3 ? weightedSlopePerDay(bf.map(p => -p.daysAgo), bf.map(p => p.bodyFatPercent)) : null;
    const slope = wSlope != null ? wSlope : -goal.weeklyRateKg / 7;

    let goalDays = null;
    if (goal.targetWeightKg && latest.weightKg > goal.targetWeightKg && slope < -0.005) {
      const d = (goal.targetWeightKg - latest.weightKg) / slope;
      if (d > 0 && d < 730) goalDays = Math.round(d);
    }

    const horizon = goalDays != null ? Math.min(Math.max(goalDays, 7), 365) : 16 * 7;
    const series = [];
    for (let week = 0; week * 7 <= horizon; week++) {
      const d = week * 7;
      let w = latest.weightKg + slope * d;
      if (goal.targetWeightKg) w = Math.max(w, goal.targetWeightKg);
      series.push({
        daysAhead: d, weightKg: w,
        bodyFatPercent: (latest.bodyFatPercent != null && bfSlope != null)
          ? Math.max(latest.bodyFatPercent + bfSlope * d, 5) : null,
      });
    }

    let confidence = 'low';
    if (panels.length >= 8 && wSlope != null && bfSlope != null) confidence = 'high';
    else if (panels.length >= 4 && wSlope != null) confidence = 'medium';

    const last = series[series.length - 1];
    return {
      goalDays, projectedWeightKg: last.weightKg,
      projectedBodyFatPercent: last.bodyFatPercent, series, confidence,
    };
  }

  // ---------- MotivationEngine ----------
  const QUOTES = [
    'Consistency beats intensity. Every single time.',
    'You don’t have to be perfect. You have to be present.',
    'Small daily wins compound into a different life.',
    'The scale measures mass. It cannot measure momentum.',
    'You are one good decision away from a good day.',
    'Six months from now, you’ll be glad you kept going today.',
    'Progress hides in weeks, not days. Zoom out.',
    'The person you’re becoming is built on days like this.',
    'Rest is part of the plan, not a break from it.',
    'Strong is a practice, not a destination.',
  ];

  function dailyMotivation(why, startDateISO, momentumYesterday) {
    const dayOrdinal = Math.floor(Date.now() / 86400000);
    if (why) {
      const journeyDays = Math.floor((Date.now() - new Date(startDateISO)) / 86400000);
      if (journeyDays % 7 === 0) return `Remember why you started: “${why}”`;
    }
    const pool = [...QUOTES];
    if (momentumYesterday != null && momentumYesterday >= 85) {
      pool.push(`Yesterday’s momentum was ${momentumYesterday}. Carry it forward.`);
    }
    return pool[dayOrdinal % pool.length];
  }

  return {
    clamp, attainment, adherenceWithOvershoot, ACTIVITY, PHASE_NAMES,
    cycleState, phaseRecommendation, targets, momentum, nutritionScore,
    healthScore, predict, dailyMotivation, QUOTES,
  };
})();
