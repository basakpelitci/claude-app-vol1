/**
 * Aura Web Prototype — Main application logic
 * Renders the Today tab with mock data and interactive UI
 */

class AuraApp {
  constructor() {
    this.store = new LocalStore();
    this.momentumEngine = new MomentumEngine();
    this.healthScoreEngine = new HealthScoreEngine();
    this.goalEngine = new GoalEngine();
    this.currentTab = 'today';
    this.snapshot = null;
    this.profileName = '';
    this.init();
  }

  async init() {
    const profile = await this.store.currentProfile();
    this.profileName = profile.name;
    await this.load();
    this.setupEventListeners();
    this.render();
  }

  async load() {
    const profile = await this.store.currentProfile();
    const goal = await this.store.activeGoal();
    const latestBIA = await this.store.latestPanel();

    // Compute targets
    const targets = this.goalEngine.targets({
      profile,
      goal,
      latestBIA,
    });

    // Get today's metrics
    const meals = await this.store.entries(new Date());
    const waterMl = await this.store.totalMl(new Date());
    const activity = await this.store.summary(new Date());
    const sleep = await this.store.entry(new Date());

    const metrics = {
      date: new Date(),
      caloriesConsumed: meals.reduce((sum, m) => sum + m.calories, 0),
      proteinG: meals.reduce((sum, m) => sum + m.proteinG, 0),
      carbsG: meals.reduce((sum, m) => sum + m.carbsG, 0),
      fatG: meals.reduce((sum, m) => sum + m.fatG, 0),
      fiberG: meals.reduce((sum, m) => sum + m.fiberG, 0),
      waterMl,
      mealTimes: meals.map(m => m.date),
      activity,
      sleep,
      cycleState: null,
    };

    const momentum = this.momentumEngine.score(metrics, targets);
    const healthScore = this.healthScoreEngine.score({});
    const panels = await this.store.panels(new Date());
    const wardrobe = await this.store.allItems();

    this.snapshot = {
      date: new Date(),
      targets,
      momentum,
      healthScore,
      metrics,
    };
  }

  setupEventListeners() {
    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tab = e.currentTarget.dataset.tab;
        this.switchTab(tab);
      });
    });

    // Quick actions
    const addWaterBtn = document.getElementById('quick-add-water');
    if (addWaterBtn) {
      addWaterBtn.addEventListener('click', () => this.quickAddWater());
    }
  }

  quickAddWater() {
    this.snapshot.metrics.waterMl += 250;
    this.render();
  }

  switchTab(tab) {
    this.currentTab = tab;
    this.render();
  }

  render() {
    const app = document.getElementById('app');
    const tabbar = document.getElementById('tabbar');

    // Show tabbar
    tabbar.style.display = 'block';

    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
      if (btn.dataset.tab === this.currentTab) {
        btn.style.color = 'var(--accent)';
      } else {
        btn.style.color = 'var(--text-secondary)';
      }
    });

    // Render content based on current tab
    switch (this.currentTab) {
      case 'today':
        app.innerHTML = this.renderTodayTab();
        break;
      case 'nutrition':
        app.innerHTML = this.renderNutritionTab();
        break;
      case 'body':
        app.innerHTML = this.renderBodyTab();
        break;
      case 'wardrobe':
        app.innerHTML = this.renderWardrobeTab();
        break;
      case 'me':
        app.innerHTML = this.renderMeTab();
        break;
    }

    // Re-attach event listeners after render
    this.setupEventListeners();
  }

  renderTodayTab() {
    if (!this.snapshot) return '<div class="screen">Loading...</div>';

    const snap = this.snapshot;
    const greeting = this.getGreeting();
    const caloriesRemaining = Math.max(0, snap.targets.calories - snap.metrics.caloriesConsumed);

    return `
      <div class="screen">
        <div style="padding: 0 16px; padding-top: 16px; padding-bottom: 96px;">
          <!-- Header -->
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 24px;">
            <div>
              <div style="font-size: 12px; color: var(--text-secondary); margin-bottom: 4px;">${new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}</div>
              <div style="font-size: 20px; font-weight: 600; color: var(--text-primary);">${greeting}</div>
            </div>
          </div>

          <!-- Score Row -->
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 24px;">
            ${this.renderScoreCard('Momentum', snap.momentum.overall, 'var(--accent)', '🔥')}
            ${this.renderScoreCard('Health', snap.healthScore.overall, 'var(--health)', '❤️')}
          </div>

          <!-- Calories Card -->
          <div class="glass" style="padding: 16px; border-radius: 24px; margin-bottom: 16px;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
              <div style="font-size: 14px; font-weight: 500; color: var(--text-primary);">⚡ Calories remaining</div>
            </div>
            <div style="font-size: 32px; font-weight: 600; color: var(--energy); margin-bottom: 12px;">${caloriesRemaining} kcal</div>
            ${this.renderProgressBar('Eaten', snap.metrics.caloriesConsumed, snap.targets.calories, 'var(--energy)')}
          </div>

          <!-- Macros Row -->
          <div class="glass" style="padding: 16px; border-radius: 24px; margin-bottom: 16px;">
            <div style="display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 8px;">
              ${this.renderMacroRing('Protein', snap.metrics.proteinG, snap.targets.proteinG, 'var(--protein)')}
              ${this.renderMacroRing('Carbs', snap.metrics.carbsG, snap.targets.carbsG, 'var(--energy)')}
              ${this.renderMacroRing('Fat', snap.metrics.fatG, snap.targets.fatG, 'var(--celebrate)')}
              ${this.renderMacroRing('Fiber', snap.metrics.fiberG, snap.targets.fiberG, 'var(--accent)')}
            </div>
          </div>

          <!-- Water & Movement Row -->
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px;">
            <div class="glass" style="padding: 16px; border-radius: 24px;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
                <div style="font-size: 14px; font-weight: 500; color: var(--text-primary);">💧 Water</div>
              </div>
              <div style="font-size: 20px; font-weight: 600; color: var(--water); margin-bottom: 12px;">${(snap.metrics.waterMl / 1000).toFixed(1)} / ${(snap.targets.waterMl / 1000).toFixed(1)} L</div>
              <button id="quick-add-water" style="width: 100%; padding: 8px; border: 1px solid var(--water); background: transparent; color: var(--water); border-radius: 12px; font-size: 12px; font-weight: 500; cursor: pointer;">+250 ml</button>
            </div>
            <div class="glass" style="padding: 16px; border-radius: 24px;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
                <div style="font-size: 14px; font-weight: 500; color: var(--text-primary);">🚶 Movement</div>
              </div>
              <div style="font-size: 20px; font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">${snap.metrics.activity?.steps || 0}</div>
              <div style="font-size: 12px; color: var(--text-secondary);">of ${snap.targets.steps} steps</div>
            </div>
          </div>

          <!-- Motivation Card -->
          <div class="glass" style="padding: 16px; border-radius: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
              <div style="font-size: 14px; font-weight: 500; color: var(--text-primary);">💬 Daily motivation</div>
            </div>
            <div style="font-size: 14px; color: var(--text-primary); font-style: italic; margin-bottom: 12px;">${snap.momentum.headline}</div>
            <div style="font-size: 12px; color: var(--text-secondary); border-top: 1px solid rgba(0,0,0,0.1); padding-top: 12px; dark:border-color: rgba(255,255,255,0.1);">Progress is the goal, not perfection.</div>
          </div>
        </div>
      </div>
    `;
  }

  renderNutritionTab() {
    return `
      <div class="screen" style="padding: 16px;">
        <div style="text-align: center; padding: 40px 20px;">
          <div style="font-size: 48px; margin-bottom: 16px;">🍽️</div>
          <div style="font-size: 18px; font-weight: 600; color: var(--text-primary); margin-bottom: 8px;">Nutrition</div>
          <div style="font-size: 14px; color: var(--text-secondary);">Track meals, macros, and hydration</div>
        </div>
      </div>
    `;
  }

  renderBodyTab() {
    return `
      <div class="screen" style="padding: 16px;">
        <div style="text-align: center; padding: 40px 20px;">
          <div style="font-size: 48px; margin-bottom: 16px;">📈</div>
          <div style="font-size: 18px; font-weight: 600; color: var(--text-primary); margin-bottom: 8px;">Body</div>
          <div style="font-size: 14px; color: var(--text-secondary);">Weight, body composition, and trends</div>
        </div>
      </div>
    `;
  }

  renderWardrobeTab() {
    return `
      <div class="screen" style="padding: 16px;">
        <div style="text-align: center; padding: 40px 20px;">
          <div style="font-size: 48px; margin-bottom: 16px;">👗</div>
          <div style="font-size: 18px; font-weight: 600; color: var(--text-primary); margin-bottom: 8px;">Wardrobe</div>
          <div style="font-size: 14px; color: var(--text-secondary);">Track dream outfits and fit goals</div>
        </div>
      </div>
    `;
  }

  renderMeTab() {
    return `
      <div class="screen" style="padding: 16px;">
        <div style="text-align: center; padding: 40px 20px;">
          <div style="font-size: 48px; margin-bottom: 16px;">🧘</div>
          <div style="font-size: 18px; font-weight: 600; color: var(--text-primary); margin-bottom: 8px;">Me</div>
          <div style="font-size: 14px; color: var(--text-secondary);">Profile, settings, and achievements</div>
        </div>
      </div>
    `;
  }

  renderScoreCard(title, score, tint, emoji) {
    return `
      <div class="glass" style="padding: 16px; border-radius: 24px; text-align: center;">
        <div style="font-size: 12px; color: var(--text-secondary); margin-bottom: 8px;">${emoji} ${title}</div>
        <div style="position: relative; width: 80px; height: 80px; margin: 0 auto;">
          <svg width="100%" height="100%" style="transform: rotate(-90deg);">
            <circle cx="40" cy="40" r="36" stroke="rgba(0,0,0,0.1)" stroke-width="4" fill="none" />
            <circle cx="40" cy="40" r="36" stroke="${tint}" stroke-width="4" fill="none" stroke-dasharray="${226 * (score / 100)} 226" style="transition: stroke-dasharray 0.9s cubic-bezier(0.34, 1.3, 0.5, 1);" />
          </svg>
          <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center;">
            <div style="font-size: 24px; font-weight: 600; color: ${tint};">${Math.round(score)}</div>
          </div>
        </div>
      </div>
    `;
  }

  renderProgressBar(label, value, target, tint) {
    const percent = Math.min((value / target) * 100, 100);
    return `
      <div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
          <span style="font-size: 12px; color: var(--text-secondary);">${label}</span>
          <span style="font-size: 12px; color: var(--text-secondary);">${Math.round(value)} / ${target}</span>
        </div>
        <div style="width: 100%; height: 6px; background: rgba(0,0,0,0.08); border-radius: 3px; overflow: hidden;">
          <div style="width: ${percent}%; height: 100%; background: ${tint}; border-radius: 3px; transition: width 0.5s cubic-bezier(0.3, 1.1, 0.5, 1);"></div>
        </div>
      </div>
    `;
  }

  renderMacroRing(title, value, target, tint) {
    const percent = Math.min((value / target) * 100, 100);
    return `
      <div style="text-align: center;">
        <div style="position: relative; width: 64px; height: 64px; margin: 0 auto 8px;">
          <svg width="100%" height="100%" style="transform: rotate(-90deg);">
            <circle cx="32" cy="32" r="28" stroke="rgba(0,0,0,0.1)" stroke-width="3" fill="none" />
            <circle cx="32" cy="32" r="28" stroke="${tint}" stroke-width="3" fill="none" stroke-dasharray="${175 * (percent / 100)} 175" />
          </svg>
          <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center;">
            <div style="font-size: 12px; font-weight: 600; color: ${tint};">${Math.round(value)}</div>
          </div>
        </div>
        <div style="font-size: 12px; color: var(--text-secondary);">${title}</div>
      </div>
    `;
  }

  getGreeting() {
    const hour = new Date().getHours();
    const name = this.profileName || 'there';
    const prefix = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return name ? `${prefix}, ${name}` : prefix;
  }
}

// Initialize app when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    new AuraApp();
  });
} else {
  new AuraApp();
}
