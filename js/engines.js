/**
 * Score Engines — Business logic for computing daily metrics
 * Simplified versions of Swift engines adapted for JavaScript/web
 */

class MomentumEngine {
  score(metrics, targets) {
    // Compute weighted partial credit across 6-9 metrics
    const scores = this.computeComponentScores(metrics, targets);
    const overall = Math.round(scores.reduce((sum, c) => sum + (c.score * c.weight), 0) * 100);
    const headline = this.generateHeadline(overall);
    return { overall, components: scores, headline };
  }

  computeComponentScores(metrics, targets) {
    const components = [];

    // Calories
    components.push({
      metric: 'calories',
      score: Math.min(metrics.caloriesConsumed / targets.calories, 1.0),
      weight: 0.2,
      detail: `${Math.round(metrics.caloriesConsumed)} of ${targets.calories} kcal`,
    });

    // Protein
    components.push({
      metric: 'protein',
      score: Math.min(metrics.proteinG / targets.proteinG, 1.0),
      weight: 0.15,
      detail: `${Math.round(metrics.proteinG)}g of ${targets.proteinG}g target`,
    });

    // Water
    components.push({
      metric: 'water',
      score: Math.min(metrics.waterMl / targets.waterMl, 1.0),
      weight: 0.1,
      detail: `${Math.round(metrics.waterMl / 100) / 10}L logged`,
    });

    // Workout
    const workoutScore = metrics.activity?.workoutCompleted ? 1.0 : metrics.activity?.exerciseMinutes / targets.exerciseMinutes || 0;
    components.push({
      metric: 'workout',
      score: Math.min(workoutScore, 1.0),
      weight: 0.2,
      detail: `${metrics.activity?.exerciseMinutes || 0} min exercise`,
    });

    // NEAT (steps)
    components.push({
      metric: 'neat',
      score: Math.min((metrics.activity?.steps || 0) / targets.steps, 1.0),
      weight: 0.15,
      detail: `${metrics.activity?.steps || 0} steps`,
    });

    // Sleep
    const sleepScore = (metrics.sleep?.durationHours || 0) / targets.sleepHours;
    components.push({
      metric: 'sleep',
      score: Math.min(Math.max(sleepScore, 0), 1.0), // Clamp to 0-1
      weight: 0.2,
      detail: `${metrics.sleep?.durationHours || 0}h sleep`,
    });

    return components;
  }

  generateHeadline(overallScore) {
    if (overallScore >= 90) return 'Perfect day! You\'re crushing it! 🔥';
    if (overallScore >= 80) return 'You\'re in flow — keep it up! 🔥';
    if (overallScore >= 70) return 'Good momentum building 💪';
    if (overallScore >= 60) return 'You\'re on track 👍';
    return 'Let\'s start strong tomorrow 💫';
  }
}

class HealthScoreEngine {
  score(input) {
    // Simplified: just return a mock health score for now
    // In real implementation, would analyze BIA trends, sleep patterns, etc.
    return {
      overall: 72,
      factors: [
        {
          kind: 'bodyFatTrend',
          score: 0.8,
          weight: 0.25,
          trend: 'improving',
          explanation: 'Body fat trending down — keep consistency.',
        },
        {
          kind: 'musclePreservation',
          score: 0.85,
          weight: 0.25,
          trend: 'improving',
          explanation: 'Muscle mass preserved with strong protein intake.',
        },
        {
          kind: 'hydration',
          score: 0.8,
          weight: 0.15,
          trend: 'stable',
          explanation: 'Daily water intake consistent.',
        },
        {
          kind: 'sleep',
          score: 0.75,
          weight: 0.15,
          trend: 'stable',
          explanation: '7-8 hours average — good recovery.',
        },
        {
          kind: 'recovery',
          score: 0.7,
          weight: 0.2,
          trend: 'stable',
          explanation: 'Adequate rest days for adaptation.',
        },
      ],
      reasons: [
        'Consistent protein intake supporting muscle',
        'Strong hydration habits',
        'Body fat trending in right direction',
        'Sleep quality improving',
      ],
    };
  }
}

class GoalEngine {
  targets(input) {
    // Simplified TDEE calculation for demo
    const { profile, goal, latestBIA } = input;

    // Base multiplier: female, moderate activity
    const baseTDEE = 1800;
    const deficit = goal.kind === 'fatLoss' ? 300 : 0;

    return {
      calories: baseTDEE - deficit,
      proteinG: profile.weightKg * 1.8, // 1.8g per kg for recomposition
      carbsG: 180,
      fatG: 60,
      fiberG: 30,
      waterMl: 2500,
      steps: 10000,
      exerciseMinutes: 60,
      sleepHours: 8,
      isLowConfidence: !latestBIA,
    };
  }
}

class MotivationEngine {
  newMilestones(input) {
    // Check for achievements: first meal logged, first week complete, etc.
    return [];
  }
}

class CycleEngine {
  state(date, records) {
    // Simplified: no cycle tracking for MVP
    return null;
  }
}
