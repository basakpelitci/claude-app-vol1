/**
 * LocalStore — In-memory data store with mock data for web prototype
 * Mirrors the Swift LocalStore actor pattern for familiar architecture
 */
class LocalStore {
  constructor() {
    this.profile = this.mockProfile();
    this.goal = this.mockGoal();
    this.meals = this.mockMeals();
    this.waterMl = 2000;
    this.activity = this.mockActivity();
    this.sleep = this.mockSleep();
    this.panels = this.mockBIAPanels();
    this.snapshots = [this.mockDailySnapshot()];
    this.milestones = [];
    this.insights = [];
    this.wardrobeItems = [this.mockWardrobeItem()];
  }

  async currentProfile() {
    return this.profile;
  }

  async activeGoal() {
    return this.goal;
  }

  async entries(date) {
    return this.meals;
  }

  async totalMl(date) {
    return this.waterMl;
  }

  async summary(date) {
    return this.activity;
  }

  async entry(date) {
    return this.sleep;
  }

  async records() {
    return []; // Cycle records
  }

  async latestPanel() {
    return this.panels[0] || null;
  }

  async panels(dateRange) {
    return this.panels;
  }

  async snapshots(dateRange) {
    return this.snapshots;
  }

  async allItems() {
    return this.wardrobeItems;
  }

  async milestones() {
    return this.milestones;
  }

  async insights(limit) {
    return this.insights.slice(0, limit);
  }

  async save(snapshot) {
    console.log('Saved snapshot:', snapshot);
  }

  mockProfile() {
    return {
      id: 'user-1',
      name: 'Basakpelitci',
      age: 28,
      gender: 'female',
      heightCm: 168,
      cycleTrackingEnabled: true,
      createdAt: new Date('2024-01-01'),
    };
  }

  mockGoal() {
    return {
      id: 'goal-1',
      kind: 'recomposition', // fatLoss, maintenance, recomposition
      targetWeightKg: 65,
      targetBodyFatPercent: 22,
      weeklyRateKg: 0.5,
      startDate: new Date('2024-06-01'),
      startWeightKg: 72,
      createdAt: new Date('2024-06-01'),
      updatedAt: new Date('2024-07-15'),
    };
  }

  mockMeals() {
    return [
      {
        id: 'meal-1',
        date: new Date(),
        name: 'Oatmeal with berries',
        calories: 350,
        proteinG: 12,
        carbsG: 58,
        fatG: 8,
        fiberG: 8,
      },
      {
        id: 'meal-2',
        date: new Date(),
        name: 'Grilled chicken & salad',
        calories: 420,
        proteinG: 45,
        carbsG: 35,
        fatG: 10,
        fiberG: 7,
      },
      {
        id: 'meal-3',
        date: new Date(),
        name: 'Greek yogurt & granola',
        calories: 280,
        proteinG: 20,
        carbsG: 35,
        fatG: 7,
        fiberG: 4,
      },
    ];
  }

  mockActivity() {
    return {
      date: new Date(),
      steps: 8420,
      exerciseMinutes: 45,
      workoutCompleted: true,
      caloriesBurned: 520,
    };
  }

  mockSleep() {
    return {
      date: new Date(),
      durationHours: 7.5,
      quality: 'good', // poor, fair, good, excellent
    };
  }

  mockBIAPanels() {
    return [
      {
        date: new Date('2024-07-15'),
        weightKg: 69.2,
        bodyFatPercent: 24.5,
        muscleMassKg: 45.8,
      },
      {
        date: new Date('2024-07-08'),
        weightKg: 69.8,
        bodyFatPercent: 25.1,
        muscleMassKg: 45.2,
      },
      {
        date: new Date('2024-07-01'),
        weightKg: 70.5,
        bodyFatPercent: 25.8,
        muscleMassKg: 44.8,
      },
    ];
  }

  mockDailySnapshot() {
    const targets = {
      calories: 1800,
      proteinG: 135,
      carbsG: 200,
      fatG: 60,
      fiberG: 30,
      waterMl: 2500,
      steps: 10000,
      exerciseMinutes: 60,
      sleepHours: 8,
      isLowConfidence: false,
    };

    const meals = this.mockMeals();
    const activity = this.mockActivity();

    const metrics = {
      date: new Date(),
      caloriesConsumed: meals.reduce((sum, m) => sum + m.calories, 0),
      proteinG: meals.reduce((sum, m) => sum + m.proteinG, 0),
      carbsG: meals.reduce((sum, m) => sum + m.carbsG, 0),
      fatG: meals.reduce((sum, m) => sum + m.fatG, 0),
      fiberG: meals.reduce((sum, m) => sum + m.fiberG, 0),
      waterMl: this.waterMl,
      mealTimes: meals.map(m => m.date),
      activity: activity,
      sleep: this.mockSleep(),
      cycleState: null,
      followedCycleRecommendation: null,
    };

    const momentum = {
      overall: 78,
      components: [
        { metric: 'calories', score: 0.85, weight: 0.2, detail: 'Consumed 1050 of 1800 kcal' },
        { metric: 'protein', score: 0.82, weight: 0.15, detail: '77g of 135g target' },
        { metric: 'water', score: 0.8, weight: 0.1, detail: '2000ml logged' },
        { metric: 'workout', score: 0.9, weight: 0.2, detail: '45 min strength session' },
        { metric: 'neat', score: 0.75, weight: 0.15, detail: '8420 steps' },
        { metric: 'sleep', score: 0.94, weight: 0.2, detail: '7.5 hours last night' },
      ],
      headline: 'You\'re in flow — keep it up! 🔥',
    };

    const healthScore = {
      overall: 72,
      factors: [
        {
          kind: 'bodyFatTrend',
          score: 0.8,
          weight: 0.25,
          trend: 'improving',
          explanation: 'Body fat down 1.3% in 2 weeks — excellent progress.',
        },
        {
          kind: 'musclePreservation',
          score: 0.85,
          weight: 0.25,
          trend: 'improving',
          explanation: 'Muscle mass stable; protein intake strong.',
        },
        {
          kind: 'hydration',
          score: 0.8,
          weight: 0.15,
          trend: 'stable',
          explanation: 'Meeting daily water targets consistently.',
        },
        {
          kind: 'sleep',
          score: 0.75,
          weight: 0.15,
          trend: 'stable',
          explanation: 'Average 7.5 hours — good recovery window.',
        },
        {
          kind: 'recovery',
          score: 0.7,
          weight: 0.2,
          trend: 'declining',
          explanation: 'More rest days recommended this week.',
        },
      ],
      reasons: [
        'Consistent protein intake',
        'Strong hydration',
        'Stable sleep patterns',
        'Measurable body fat loss',
      ],
    };

    return {
      id: 'snapshot-1',
      date: new Date(),
      targets,
      momentum,
      healthScore,
      metrics,
    };
  }

  mockWardrobeItem() {
    return {
      id: 'item-1',
      title: 'Black Power Blazer',
      targetSize: 'S',
      fitStatus: 'aspirational', // aspirational, current, too-loose
      category: 'top',
      isPinned: true,
      notes: 'For special occasions',
      imageData: null, // In real app, would be base64
    };
  }
}
