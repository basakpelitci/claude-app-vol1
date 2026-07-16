// Aura HTML prototype — screen rendering, navigation, and interactions.
// Every view mirrors a SwiftUI screen; see prototype/README.md for the map.

const App = (() => {
  const S = () => Store.load();
  let tab = 'today';
  let stack = [];            // pushed detail views: {title, render}
  let pendingCelebrations = [];
  let sheetImageData = null; // wardrobe photo being attached

  // ---------- Utilities ----------
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g,
    c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmtDate = (iso) => new Date(iso + 'T12:00:00')
    .toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const fmtLong = (iso) => new Date(iso + 'T12:00:00')
    .toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const daysAgoOf = (iso) => Math.round((Date.parse(Store.todayISO()) - Date.parse(iso)) / 86400000);

  // ---------- Derived data (RecalculationCoordinator equivalent) ----------
  function latestPanel() {
    const p = [...S().panels].sort((a, b) => a.date.localeCompare(b.date));
    return p[p.length - 1] || null;
  }

  function targetsFor(dateISO) {
    const s = S();
    if (!s.profile || !s.goal) return null;
    const phase = s.profile.cycleTracking
      ? (Engines.cycleState(s.cycles, dateISO)?.phase ?? null) : null;
    return Engines.targets(s.profile, s.goal, latestPanel(), phase);
  }

  function dayMetrics(dateISO) {
    const s = S();
    const meals = s.meals.filter(m => m.date === dateISO);
    const sum = k => meals.reduce((a, m) => a + (m[k] || 0), 0);
    const waterMl = s.water.filter(w => w.date === dateISO).reduce((a, w) => a + w.ml, 0);
    const activity = s.activity[dateISO] || null;
    const cycle = s.profile?.cycleTracking ? Engines.cycleState(s.cycles, dateISO) : null;
    const t = targetsFor(dateISO);
    let followedCycle = null;
    if (cycle && activity && t) {
      followedCycle = (cycle.phase === 'menstrual' || cycle.phase === 'luteal')
        ? (!activity.workoutCompleted || (activity.exerciseMinutes || 0) <= 75)
        : (activity.workoutCompleted || (activity.steps || 0) >= t.steps / 2);
    }
    return {
      date: dateISO,
      calories: sum('kcal'), proteinG: sum('p'), carbsG: sum('c'),
      fatG: sum('f'), fiberG: sum('fiber'),
      waterMl, mealTimes: meals.map(m => m.time), activity,
      sleepHours: s.sleep[dateISO] ?? null,
      cycleState: cycle, followedCycle,
    };
  }

  function snapshot(dateISO) {
    const t = targetsFor(dateISO);
    if (!t) return null;
    const metrics = dayMetrics(dateISO);
    return { date: dateISO, targets: t, metrics, momentum: Engines.momentum(metrics, t) };
  }

  function recentSnapshots(days) {
    const out = [];
    for (let i = days - 1; i >= 0; i--) {
      const date = Store.todayISO(-i);
      const s = S();
      const hasData = s.meals.some(m => m.date === date) || s.water.some(w => w.date === date)
        || s.activity[date] || s.sleep[date] != null;
      if (hasData) {
        const snap = snapshot(date);
        if (snap) out.push(snap);
      }
    }
    return out;
  }

  function healthToday() {
    const panels = S().panels
      .filter(p => daysAgoOf(p.date) <= 14)
      .sort((a, b) => a.date.localeCompare(b.date))
      .map(p => ({ ...p, daysAgo: daysAgoOf(p.date) }));
    const days = recentSnapshots(7).map(s => ({ metrics: s.metrics, targets: s.targets }));
    return Engines.healthScore(panels, days);
  }

  // ---------- Milestone detection (MotivationEngine.newMilestones, lite) ----------
  function checkMilestones() {
    const s = S();
    if (!s.goal) return;
    const earned = new Set(s.milestones.map(m => m.kind));
    const award = (kind, title, detail) => {
      if (earned.has(kind)) return;
      const m = { kind, title, detail, date: Store.todayISO() };
      s.milestones.push(m);
      pendingCelebrations.push(m);
    };
    const snaps = recentSnapshots(90);
    if (snaps.length >= 7) award('firstWeekComplete', 'First week complete', 'Seven days of showing up. The habit is forming.');
    const last7 = snaps.slice(-7);
    if (last7.length === 7 && last7.reduce((a, x) => a + x.momentum.overall, 0) / 7 >= 80) {
      award('momentum80Week', 'A week of high momentum', 'Averaging 80+ momentum for seven straight days.');
    }
    const panels = [...s.panels].sort((a, b) => a.date.localeCompare(b.date));
    if (panels.length >= 3) {
      const first = panels[0], last = panels[panels.length - 1];
      if (first.bodyFatPercent != null && last.bodyFatPercent != null && first.bodyFatPercent - last.bodyFatPercent >= 1) {
        award('bodyFatDown1Percent', 'Body fat down a full point',
          `From ${first.bodyFatPercent.toFixed(1)}% to ${last.bodyFatPercent.toFixed(1)}% — real composition change.`);
      }
      if (s.goal.targetWeightKg) {
        const halfway = s.goal.startWeightKg - (s.goal.startWeightKg - s.goal.targetWeightKg) / 2;
        if (last.weightKg <= halfway && s.goal.startWeightKg > s.goal.targetWeightKg) {
          award('halfwayToGoal', 'Halfway there', 'You’ve covered half the distance to your goal.');
        }
        if (last.weightKg <= s.goal.targetWeightKg) {
          award('goalReached', 'Goal reached', 'You did the thing. Take a moment — then we celebrate properly.');
        }
      }
    }
    if (s.wardrobe.some(w => w.fitStatus === 'fits')) {
      award('wardrobeItemFits', 'It fits!', 'A dream wardrobe item fits. This is what the journey was for.');
    }
    Store.save();
  }

  // ---------- SVG building blocks (DesignSystem equivalents) ----------
  function ring(score, tintVar, size) {
    // ScoreRing: hero 132/13, mini 56/6
    const d = size === 'hero' ? 132 : 56;
    const sw = size === 'hero' ? 13 : 6;
    const r = (d - sw) / 2, c = 2 * Math.PI * r;
    const frac = Engines.clamp(score / 100, 0, 1);
    const fs = size === 'hero' ? 'text-[44px]' : 'text-[17px]';
    return `
      <div class="relative inline-block" style="width:${d}px;height:${d}px"
           role="img" aria-label="${score} out of 100">
        <svg width="${d}" height="${d}" class="-rotate-90">
          <circle cx="${d / 2}" cy="${d / 2}" r="${r}" fill="none"
                  stroke="var(--${tintVar})" stroke-opacity="0.15" stroke-width="${sw}"/>
          <circle cx="${d / 2}" cy="${d / 2}" r="${r}" fill="none"
                  stroke="var(--${tintVar})" stroke-width="${sw}" stroke-linecap="round"
                  class="ring-progress" stroke-dasharray="${c}"
                  stroke-dashoffset="${c}" data-final="${c * (1 - frac)}"/>
        </svg>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="font-rounded font-bold tabular ${fs}">${score}</span>
        </div>
      </div>`;
  }

  function bar(value, target, tintVar) {
    const frac = Engines.clamp(target > 0 ? value / target : 0, 0, 1);
    return `
      <div class="h-2 rounded-full overflow-hidden" style="background:color-mix(in srgb, var(--${tintVar}) 15%, transparent)">
        <div class="h-full rounded-full bar-fill" style="background:var(--${tintVar});width:0%" data-final="${(frac * 100).toFixed(1)}"></div>
      </div>`;
  }

  function metricBar(label, value, target, unit, tintVar) {
    return `
      <div>
        <div class="flex justify-between items-baseline mb-1.5">
          <span class="text-[15px]">${esc(label)}</span>
          <span class="text-[13px] text-tsecondary tabular">${Math.round(value)} / ${Math.round(target)} ${unit}</span>
        </div>
        ${bar(value, target, tintVar)}
      </div>`;
  }

  function sparkline(values, tintVar, height = 32) {
    if (values.length < 2) return '';
    const min = Math.min(...values), max = Math.max(...values);
    const span = Math.max(max - min, 0.0001);
    const w = 300;
    const pts = values.map((v, i) =>
      `${(i * w / (values.length - 1)).toFixed(1)},${(height - 3 - (v - min) / span * (height - 6)).toFixed(1)}`).join(' ');
    return `<svg viewBox="0 0 ${w} ${height}" class="w-full" style="height:${height}px" aria-hidden="true">
      <polyline points="${pts}" fill="none" stroke="var(--${tintVar})" stroke-width="2"
        stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  }

  function lineChart(points, tintVar, { dashed = false, height = 140 } = {}) {
    // points: [{x(0..1 fraction or index), y}] — we normalize indices.
    if (points.length < 2) return '';
    const ys = points.map(p => p.y);
    const min = Math.min(...ys), max = Math.max(...ys);
    const span = Math.max(max - min, 0.0001);
    const w = 320, pad = 6;
    const px = (i) => pad + i * (w - 2 * pad) / (points.length - 1);
    const py = (y) => height - pad - (y - min) / span * (height - 2 * pad);
    const pts = points.map((p, i) => `${px(i).toFixed(1)},${py(p.y).toFixed(1)}`).join(' ');
    const area = `${pad},${height - pad} ${pts} ${(w - pad).toFixed(1)},${height - pad}`;
    return `<svg viewBox="0 0 ${w} ${height}" class="w-full" style="height:${height}px" aria-hidden="true">
      ${dashed ? '' : `<polygon points="${area}" fill="var(--${tintVar})" opacity="0.1"/>`}
      <polyline points="${pts}" fill="none" stroke="var(--${tintVar})" stroke-width="2"
        ${dashed ? 'stroke-dasharray="6 4"' : ''} stroke-linecap="round" stroke-linejoin="round"/>
      <text x="${w - pad}" y="${py(points[points.length - 1].y) - 6}" text-anchor="end"
        font-size="11" fill="var(--text-secondary)" class="tabular">${points[points.length - 1].y.toFixed(1)}</text>
    </svg>`;
  }

  const cardTitle = (text, icon, tintVar = 'text-secondary') =>
    `<div class="flex items-center gap-2 text-[12px] font-medium uppercase tracking-wider text-tsecondary">
       <span style="color:var(--${tintVar})">${icon}</span>${esc(text)}</div>`;
  const surfaceCard = (inner, extra = '') =>
    `<div class="bg-surface rounded-card p-6 ${extra}">${inner}</div>`;
  const glassCard = (inner, extra = '') =>
    `<div class="glass rounded-card p-6 ${extra}">${inner}</div>`;
  const primaryBtn = (label, onclick, extra = '') =>
    `<button onclick="${onclick}" class="w-full py-3.5 rounded-2xl font-semibold text-white ${extra}"
       style="background:var(--accent)">${esc(label)}</button>`;
  const chipBtn = (label, onclick, on) =>
    `<button onclick="${onclick}" class="px-3 py-2 rounded-full text-[12px] font-medium whitespace-nowrap"
       style="${on ? 'background:var(--accent);color:#fff'
                   : 'background:color-mix(in srgb, var(--accent) 16%, transparent);color:var(--accent)'}">${esc(label)}</button>`;

  const FIT_LABELS = { dream: 'The dream', closer: 'Getting closer', almostFits: 'Almost fits', fits: 'It fits!' };
  const CATEGORY_ICONS = { outfit: '👗', dress: '👗', jeans: '👖', jacket: '🧥', shoes: '👠', accessory: '👜', top: '👚', skirt: '👗', other: '🛍️' };

  // ---------- Rendering core ----------
  function render() {
    const app = document.getElementById('app');
    const tabbar = document.getElementById('tabbar');
    if (!S().profile) {
      tabbar.classList.add('hidden');
      app.innerHTML = Onboarding.render();
    } else if (stack.length) {
      // SwiftUI keeps the tab bar visible under NavigationStack pushes.
      tabbar.classList.remove('hidden');
      const top = stack[stack.length - 1];
      app.innerHTML = `
        <div class="screen">
          <header class="sticky top-0 z-10 glass px-4 py-3 relative flex items-center">
            <button onclick="App.pop()" class="relative z-10 text-[15px] font-medium" style="color:var(--accent)">‹ Back</button>
            <span class="absolute inset-x-0 text-center font-semibold text-[15px] pointer-events-none truncate px-16">${esc(top.title)}</span>
          </header>
          <div class="px-5 pt-4 pb-8">${top.render()}</div>
        </div>`;
    } else {
      tabbar.classList.remove('hidden');
      const renderers = { today: renderToday, nutrition: renderNutrition, body: renderBody, wardrobe: renderWardrobe, me: renderMe };
      app.innerHTML = `<div class="screen px-5 pt-6 pb-8">${renderers[tab]()}</div>`;
      document.querySelectorAll('.tab-btn').forEach(b => {
        b.style.color = b.dataset.tab === tab ? 'var(--accent)' : 'var(--text-secondary)';
      });
    }
    renderOverlays();
    requestAnimationFrame(animateIn);
  }

  function animateIn() {
    document.querySelectorAll('.ring-progress').forEach(el => {
      el.style.strokeDashoffset = el.dataset.final;
    });
    document.querySelectorAll('.bar-fill').forEach(el => {
      el.style.width = el.dataset.final + '%';
    });
  }

  function renderOverlays() {
    const root = document.getElementById('overlay-root');
    if (pendingCelebrations.length) {
      const m = pendingCelebrations[0];
      root.innerHTML = `
        <div class="absolute inset-0 z-50 glass flex items-center justify-center p-8">
          <div class="celebrate-pop bg-surface rounded-sheet p-8 text-center max-w-[300px] w-full">
            <div class="text-5xl mb-4">🏆</div>
            <h2 class="text-2xl font-bold mb-2">${esc(m.title)}</h2>
            <p class="text-tsecondary text-[15px] mb-6">${esc(m.detail)}</p>
            ${primaryBtn('Continue', 'App.dismissCelebration()')}
          </div>
        </div>`;
    } else if (!root.dataset.sheet) {
      root.innerHTML = '';
    }
  }

  function push(title, renderFn) { stack.push({ title, render: renderFn }); render(); }
  function pop() { stack.pop(); render(); }
  function switchTab(t) { tab = t; stack = []; render(); }
  function dismissCelebration() { pendingCelebrations.shift(); render(); }

  // ---------- Sheets ----------
  function openSheet(html) {
    const root = document.getElementById('overlay-root');
    root.dataset.sheet = '1';
    root.innerHTML = `
      <div class="absolute inset-0 z-40 bg-black/40" onclick="App.closeSheet()"></div>
      <div class="absolute inset-x-0 bottom-0 z-40 sheet-panel bg-surface rounded-t-sheet
                  max-h-[85%] overflow-y-auto noscroll p-6 text-tprimary">${html}</div>`;
  }
  function closeSheet() {
    const root = document.getElementById('overlay-root');
    delete root.dataset.sheet;
    sheetImageData = null;
    root.innerHTML = '';
    renderOverlays();
  }
  const sheetHeader = (title) => `
    <div class="flex items-center justify-between mb-4">
      <h3 class="font-semibold text-[17px]">${esc(title)}</h3>
      <button onclick="App.closeSheet()" class="text-[15px]" style="color:var(--accent)">Cancel</button>
    </div>`;
  const input = (id, placeholder, type = 'text', value = '') => `
    <input id="${id}" type="${type}" placeholder="${esc(placeholder)}" value="${esc(value)}"
      ${type === 'number' ? 'inputmode="decimal" step="any"' : ''}
      class="w-full bg-bg rounded-chip px-4 py-3 text-[15px] outline-none placeholder:text-tsecondary">`;

  // ============================================================
  // Screen: Today (TodayView.swift)
  // ============================================================
  function renderToday() {
    const s = S();
    const snap = snapshot(Store.todayISO());
    const health = healthToday();
    const hour = new Date().getHours();
    const greeting = (hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening')
      + (s.profile.name ? `, ${esc(s.profile.name)}` : '');
    const cycle = snap?.metrics.cycleState;
    const pinned = s.wardrobe.filter(w => w.pinned);
    const outfit = pinned.length ? pinned[Math.floor(Date.now() / 86400000) % pinned.length] : null;
    const rec = cycle ? Engines.phaseRecommendation(cycle.phase) : null;
    const panels30 = s.panels.filter(p => daysAgoOf(p.date) <= 30).sort((a, b) => a.date.localeCompare(b.date));
    const yesterday = snapshot(Store.todayISO(-1));
    const motivation = Engines.dailyMotivation(s.why, s.goal.startDate, yesterday?.momentum.overall ?? null);
    const t = snap.targets, m = snap.metrics;

    return `
      <div class="flex items-start justify-between pt-1">
        <div>
          <p class="text-[13px] text-tsecondary">${fmtLong(Store.todayISO())}</p>
          <h1 class="text-[22px] font-semibold">${greeting}</h1>
        </div>
        ${cycle ? `<button onclick="App.push('Cycle', App.views.cycle)"
            class="flex items-center gap-1 px-3 py-1.5 rounded-full text-[12px] font-medium"
            style="background:color-mix(in srgb, var(--cycle) 16%, transparent);color:var(--cycle)">
            🌙 ${Engines.PHASE_NAMES[cycle.phase]} · Day ${cycle.dayInCycle}</button>` : ''}
      </div>

      <div class="grid grid-cols-2 gap-4 mt-4">
        <button onclick="App.push('Momentum', App.views.momentumDetail)" class="text-left">
          ${glassCard(`<div class="flex flex-col items-center gap-3">
            ${cardTitle('Momentum', '🔥', 'accent')}${ring(snap.momentum.overall, 'accent', 'hero')}</div>`)}
        </button>
        <button onclick="App.push('Health Score', App.views.healthDetail)" class="text-left">
          ${glassCard(`<div class="flex flex-col items-center gap-3">
            ${cardTitle('Health', '💙', 'health')}${ring(health.overall, 'health', 'hero')}</div>`)}
        </button>
      </div>

      <div class="mt-4">${surfaceCard(`
        ${cardTitle('Calories remaining', '⚡', 'energy')}
        <p class="font-rounded text-[28px] font-semibold mt-2 tabular">${Math.max(Math.round(t.calories - m.calories), 0)} kcal</p>
        <div class="mt-3">${metricBar('Eaten', m.calories, t.calories, 'kcal', 'energy')}</div>`)}
      </div>

      <div class="mt-4">${surfaceCard(`
        <div class="grid grid-cols-4 gap-2 text-center">
          ${[['Protein', m.proteinG, t.proteinG, 'protein'], ['Carbs', m.carbsG, t.carbsG, 'energy'],
             ['Fat', m.fatG, t.fatG, 'celebrate'], ['Fiber', m.fiberG, t.fiberG, 'accent']]
            .map(([label, v, tg, tint]) => `
              <div class="flex flex-col items-center gap-1.5">
                ${ring(Math.round(Engines.clamp(v / (tg || 1), 0, 1) * 100), tint, 'mini')}
                <span class="text-[12px] text-tsecondary">${label}</span>
              </div>`).join('')}
        </div>`)}
      </div>

      <div class="grid grid-cols-2 gap-4 mt-4">
        ${surfaceCard(`
          ${cardTitle('Water', '💧', 'water')}
          <p class="font-rounded text-[24px] font-semibold mt-2 tabular">${(m.waterMl / 1000).toFixed(1)} / ${(t.waterMl / 1000).toFixed(1)} L</p>
          <button onclick="App.quickWater()" class="mt-2 px-3 py-1.5 rounded-full text-[12px] font-medium"
            style="background:color-mix(in srgb, var(--water) 16%, transparent);color:var(--water)">+ 250 ml</button>`)}
        ${surfaceCard(`
          ${cardTitle('Movement', '🚶', 'accent')}
          <p class="font-rounded text-[24px] font-semibold mt-2 tabular">${(m.activity?.steps ?? 0).toLocaleString()}</p>
          <p class="text-[13px] text-tsecondary mt-1">of ${t.steps.toLocaleString()} steps</p>`)}
      </div>

      ${rec ? `<div class="mt-4">${surfaceCard(`
        ${cardTitle("Today's workout", '💪', 'accent')}
        <p class="text-[15px] mt-2">${esc(rec.workout)}</p>
        <p class="text-[13px] text-tsecondary mt-1">Adapted to your ${Engines.PHASE_NAMES[rec.phase].toLowerCase()} phase</p>`)}</div>` : ''}

      ${panels30.length ? `<div class="mt-4"><button class="w-full text-left" onclick="App.switchTab('body')">${surfaceCard(`
        ${cardTitle('Body', '📉', 'health')}
        <div class="flex items-baseline gap-3 mt-2">
          <span class="font-rounded text-[24px] font-semibold tabular">${panels30[panels30.length - 1].weightKg.toFixed(1)} kg</span>
          ${panels30[panels30.length - 1].bodyFatPercent != null
            ? `<span class="text-[13px] text-tsecondary">${panels30[panels30.length - 1].bodyFatPercent.toFixed(1)}% fat</span>` : ''}
        </div>
        <div class="mt-2">${sparkline(panels30.map(p => p.weightKg), 'health')}</div>`)}</button></div>` : ''}

      ${outfit ? `<div class="mt-4"><button class="w-full text-left" onclick="App.switchTab('wardrobe')">${surfaceCard(`
        <div class="flex items-center gap-4">
          <div class="w-16 h-16 rounded-chip flex items-center justify-center text-2xl shrink-0 overflow-hidden"
               style="background:color-mix(in srgb, var(--celebrate) 12%, transparent)">
            ${outfit.image ? `<img src="${outfit.image}" class="w-full h-full object-cover" alt="">` : (CATEGORY_ICONS[outfit.category] || '✨')}
          </div>
          <div class="min-w-0">
            ${cardTitle('Dream outfit', '✨', 'celebrate')}
            <p class="font-semibold text-[16px] mt-1 truncate">${esc(outfit.title)}</p>
            <p class="text-[13px] text-tsecondary">Target size ${esc(outfit.targetSize)} · ${FIT_LABELS[outfit.fitStatus]}</p>
          </div>
        </div>`)}</button></div>` : ''}

      <div class="mt-4">${surfaceCard(`
        ${cardTitle('Daily motivation', '❝', 'accent')}
        <p class="italic text-[15px] mt-2">${esc(motivation)}</p>`)}
      </div>`;
  }

  function momentumDetailView() {
    const snap = snapshot(Store.todayISO());
    if (!snap) return '';
    return `
      <div class="flex flex-col items-center gap-3 py-4">
        ${ring(snap.momentum.overall, 'accent', 'hero')}
        <p class="text-tsecondary text-[15px] text-center">${esc(snap.momentum.headline)}</p>
      </div>
      <div class="space-y-4">
        ${snap.momentum.components.map(c => surfaceCard(`
          <div class="flex justify-between items-baseline mb-2">
            <span class="font-medium text-[15px]">${esc(c.name)}</span>
            <span class="font-semibold tabular" style="color:var(--accent)">${Math.round(c.score * 100)}%</span>
          </div>
          <p class="text-[13px] text-tsecondary mb-2">${esc(c.detail)}</p>
          ${bar(c.score * 100, 100, 'accent')}`)).join('')}
      </div>`;
  }

  function healthDetailView() {
    const h = healthToday();
    const trendIcon = t => t === 'improving' ? '↗' : t === 'declining' ? '↘' : '→';
    return `
      <div class="flex justify-center py-4">${ring(h.overall, 'health', 'hero')}</div>
      ${surfaceCard(`
        ${cardTitle('Why this score', '🔍', 'health')}
        <ul class="mt-3 space-y-2">
          ${h.reasons.map(r => `<li class="flex gap-2 text-[15px]"><span style="color:var(--accent)">✓</span>${esc(r)}</li>`).join('')}
        </ul>`)}
      <div class="space-y-4 mt-4">
        ${h.factors.map(f => surfaceCard(`
          <div class="flex items-center justify-between">
            <div class="min-w-0">
              <p class="font-medium text-[15px]">${esc(f.name)}</p>
              <p class="text-[13px] text-tsecondary">${esc(f.explanation)}</p>
            </div>
            <span class="text-xl shrink-0 ml-3" style="color:${f.trend === 'improving' ? 'var(--accent)' : 'var(--text-secondary)'}">${trendIcon(f.trend)}</span>
          </div>`)).join('')}
      </div>`;
  }

  function quickWater() {
    S().water.push({ id: Store.uid(), date: Store.todayISO(), ml: 250 });
    Store.save();
    checkMilestones();
    render();
  }

  // ============================================================
  // Screen: Nutrition (NutritionView.swift)
  // ============================================================
  let nutritionDay = Store.todayISO();

  function renderNutrition() {
    const s = S();
    const t = targetsFor(nutritionDay);
    const meals = s.meals.filter(m => m.date === nutritionDay);
    const sum = k => meals.reduce((a, m) => a + (m[k] || 0), 0);
    const waterMl = s.water.filter(w => w.date === nutritionDay).reduce((a, w) => a + w.ml, 0);
    const score = t ? Engines.nutritionScore(meals, t) : null;
    const isToday = nutritionDay === Store.todayISO();

    const mealSection = (type) => {
      const list = meals.filter(m => m.mealType === type).sort((a, b) => a.time - b.time);
      const kcal = list.reduce((a, m) => a + m.kcal, 0);
      return surfaceCard(`
        <div class="flex items-center justify-between">
          <span class="font-semibold text-[17px] capitalize">${type}</span>
          <div class="flex items-center gap-3">
            ${kcal ? `<span class="text-[13px] text-tsecondary tabular">${Math.round(kcal)} kcal</span>` : ''}
            <button onclick="App.openAddFood('${type}')" aria-label="Add food to ${type}"
              class="text-xl leading-none" style="color:var(--accent)">＋</button>
          </div>
        </div>
        ${list.map(m => `
          <div class="flex items-center justify-between mt-3">
            <div class="min-w-0">
              <p class="text-[15px] truncate">${m.favorite ? '♥ ' : ''}${esc(m.name)}</p>
              <p class="text-[12px] text-tsecondary tabular">P${Math.round(m.p)} · C${Math.round(m.c)} · F${Math.round(m.f)}</p>
            </div>
            <div class="flex items-center gap-2 shrink-0 ml-2">
              <span class="text-[15px] font-medium text-tsecondary tabular">${Math.round(m.kcal)}</span>
              <button onclick="App.toggleFavorite('${m.id}')" aria-label="Favorite" class="text-[13px]"
                style="color:var(--cycle)">${m.favorite ? '♥' : '♡'}</button>
              <button onclick="App.deleteMeal('${m.id}')" aria-label="Delete" class="text-[13px] text-tsecondary">✕</button>
            </div>
          </div>`).join('')}`, 'mt-4');
    };

    return `
      <div class="flex items-center justify-between pt-1">
        <button onclick="App.shiftNutritionDay(-1)" class="text-[17px] px-2" style="color:var(--accent)">‹</button>
        <h1 class="font-semibold text-[17px]">${isToday ? 'Today' : fmtLong(nutritionDay)}</h1>
        <button onclick="App.shiftNutritionDay(1)" class="text-[17px] px-2"
          style="color:${isToday ? 'var(--text-secondary)' : 'var(--accent)'}" ${isToday ? 'disabled' : ''}>›</button>
      </div>

      <div class="mt-4">${surfaceCard(t ? `
        <div class="flex items-baseline justify-between">
          <div class="flex items-baseline gap-2">
            <span class="font-rounded text-[28px] font-semibold tabular">${Math.max(Math.round(t.calories - sum('kcal')), 0)}</span>
            <span class="text-[13px] text-tsecondary">kcal remaining</span>
          </div>
          ${score ? `<span class="px-3 py-1.5 rounded-full text-[12px] font-medium"
            style="background:color-mix(in srgb, var(--accent) 16%, transparent);color:var(--accent)">Meal score ${score.grade}</span>` : ''}
        </div>
        <div class="mt-4 space-y-3">
          ${metricBar('Calories', sum('kcal'), t.calories, 'kcal', 'energy')}
          ${metricBar('Protein', sum('p'), t.proteinG, 'g', 'protein')}
        </div>` : '<p class="text-tsecondary text-[15px]">Set up your profile to see personalized targets.</p>')}
      </div>

      ${['breakfast', 'lunch', 'dinner', 'snack'].map(mealSection).join('')}

      <div class="mt-4">${surfaceCard(`
        ${cardTitle('Water', '💧', 'water')}
        <div class="mt-3">${metricBar('Hydration', waterMl, t ? t.waterMl : 2000, 'ml', 'water')}</div>
        <div class="flex gap-2 mt-3">
          ${[250, 500, 750].map(ml => `<button onclick="App.addWater(${ml})"
            class="px-3 py-1.5 rounded-full text-[12px] font-medium"
            style="background:color-mix(in srgb, var(--water) 16%, transparent);color:var(--water)">+${ml}</button>`).join('')}
        </div>`)}
      </div>`;
  }

  function shiftNutritionDay(delta) {
    const next = new Date(Date.parse(nutritionDay) + delta * 86400000).toISOString().slice(0, 10);
    if (next > Store.todayISO()) return;
    nutritionDay = next;
    render();
  }

  function openAddFood(mealType) {
    const favorites = S().meals.filter(m => m.favorite)
      .filter((m, i, arr) => arr.findIndex(x => x.name === m.name) === i).slice(0, 6);
    openSheet(`
      ${sheetHeader(`Add to ${mealType}`)}
      ${input('food-search', 'Search foods…')}
      <div id="food-results" class="mt-2 space-y-1"></div>
      ${favorites.length ? `
        <p class="text-[12px] font-medium uppercase tracking-wider text-tsecondary mt-5 mb-2">Favorites</p>
        ${favorites.map(f => `
          <button onclick='App.logFood(${JSON.stringify(JSON.stringify({ mealType, name: f.name, kcal: f.kcal, p: f.p, c: f.c, f: f.f, fiber: f.fiber }))})'
            class="w-full flex justify-between py-2.5 text-[15px] border-b border-black/5 dark:border-white/5">
            <span class="truncate">${esc(f.name)}</span>
            <span class="text-tsecondary tabular shrink-0 ml-2">${Math.round(f.kcal)} kcal</span>
          </button>`).join('')}` : ''}
      <p class="text-[12px] font-medium uppercase tracking-wider text-tsecondary mt-5 mb-2">Manual entry</p>
      <div class="space-y-2">
        ${input('mf-name', 'Name')}
        <div class="grid grid-cols-2 gap-2">
          ${input('mf-kcal', 'Calories', 'number')}${input('mf-p', 'Protein (g)', 'number')}
          ${input('mf-c', 'Carbs (g)', 'number')}${input('mf-f', 'Fat (g)', 'number')}
        </div>
        ${input('mf-fiber', 'Fiber (g)', 'number')}
        ${primaryBtn('Log ' + mealType, `App.logManual('${mealType}')`, 'mt-2')}
      </div>`);
    const search = document.getElementById('food-search');
    search.addEventListener('input', () => {
      const q = search.value.trim().toLowerCase();
      const results = q ? S().foods.filter(f => f.name.toLowerCase().includes(q)).slice(0, 6) : [];
      document.getElementById('food-results').innerHTML = results.map(f => `
        <button onclick='App.logFood(${JSON.stringify(JSON.stringify({ mealType, name: f.name, kcal: f.kcal, p: f.p, c: f.c, f: f.f, fiber: f.fiber }))})'
          class="w-full flex justify-between py-2.5 text-[15px] border-b border-black/5 dark:border-white/5">
          <span class="truncate">${esc(f.name)}</span>
          <span class="text-tsecondary tabular shrink-0 ml-2">${Math.round(f.kcal)} kcal / 100g</span>
        </button>`).join('');
    });
    search.focus();
  }

  function logFood(json) {
    const d = JSON.parse(json);
    S().meals.push({
      id: Store.uid(), date: nutritionDay, time: Date.now(),
      mealType: d.mealType, name: d.name, kcal: d.kcal, p: d.p, c: d.c, f: d.f,
      fiber: d.fiber || 0, favorite: false,
    });
    Store.save();
    closeSheet();
    checkMilestones();
    render();
  }

  function logManual(mealType) {
    const v = id => parseFloat(document.getElementById(id).value) || 0;
    const name = document.getElementById('mf-name').value.trim();
    if (!name || !v('mf-kcal')) return;
    logFood(JSON.stringify({ mealType, name, kcal: v('mf-kcal'), p: v('mf-p'), c: v('mf-c'), f: v('mf-f'), fiber: v('mf-fiber') }));
  }

  function deleteMeal(id) {
    const s = S();
    s.meals = s.meals.filter(m => m.id !== id);
    Store.save();
    render();
  }

  function toggleFavorite(id) {
    const m = S().meals.find(m => m.id === id);
    if (m) { m.favorite = !m.favorite; Store.save(); render(); }
  }

  function addWater(ml) {
    S().water.push({ id: Store.uid(), date: nutritionDay, ml });
    Store.save();
    render();
  }

  // ============================================================
  // Screen: Body (BodyView.swift)
  // ============================================================
  function renderBody() {
    const s = S();
    const panels = [...s.panels].sort((a, b) => a.date.localeCompare(b.date));
    const latest = panels[panels.length - 1];
    const stat = (label, v, unit) => v == null ? '' : `
      <div class="text-center">
        <p class="font-rounded text-[20px] font-semibold tabular">${typeof v === 'number' ? (Number.isInteger(v) ? v : v.toFixed(1)) : v}</p>
        <p class="text-[11px] text-tsecondary">${label}${unit ? ` (${unit})` : ''}</p>
      </div>`;

    const trendCard = (title, tintVar, valueFn, unit) => {
      const pts = panels.map(p => valueFn(p)).filter(v => v != null);
      if (pts.length < 2) return '';
      return `<div class="mt-4">${surfaceCard(`
        <div class="flex items-center justify-between">
          ${cardTitle(title, '📈', tintVar)}
          <span class="text-[12px] tabular" style="color:var(--${tintVar})">
            ${pts[pts.length - 1] - pts[0] <= 0 ? '↘' : '↗'} ${Math.abs(pts[pts.length - 1] - pts[0]).toFixed(1)} ${unit} overall
          </span>
        </div>
        <div class="mt-3">${lineChart(pts.map(y => ({ y })), tintVar)}</div>`)}</div>`;
    };

    const goal = s.goal;
    const recent = panels.filter(p => daysAgoOf(p.date) <= 28).map(p => ({ ...p, daysAgo: daysAgoOf(p.date) }));
    const prediction = goal ? Engines.predict(recent, goal) : null;
    const goalDateStr = prediction?.goalDays != null
      ? new Date(Date.now() + prediction.goalDays * 86400000).toLocaleDateString('en-US', { month: 'long', day: 'numeric' })
      : null;

    return `
      <h1 class="text-[28px] font-bold pt-1">Body</h1>
      ${!latest ? `
        <div class="mt-8 text-center px-6">
          <div class="text-4xl mb-3">⚖️</div>
          <p class="font-semibold text-[17px]">No measurements yet</p>
          <p class="text-tsecondary text-[15px] mt-1">Add your first measurement — even weight alone — and Aura starts learning your trends.</p>
        </div>` : `
        <div class="mt-4">${surfaceCard(`
          ${cardTitle('Latest panel · ' + fmtDate(latest.date), '🧍', 'health')}
          <div class="grid grid-cols-3 gap-y-4 mt-4">
            ${stat('Weight', latest.weightKg, 'kg')}
            ${stat('Body fat', latest.bodyFatPercent, '%')}
            ${stat('Lean mass', latest.leanBodyMassKg ?? (latest.bodyFatPercent != null ? +(latest.weightKg * (1 - latest.bodyFatPercent / 100)).toFixed(1) : null), 'kg')}
            ${stat('Muscle', latest.muscle, 'kg')}
            ${stat('Water', latest.waterPct, '%')}
            ${stat('Visceral', latest.visceral, '')}
            ${stat('Bone', latest.bone, 'kg')}
            ${stat('Protein', latest.proteinPct, '%')}
            ${stat('BMI', latest.bmi, '')}
            ${stat('BMR', latest.bmr, 'kcal')}
            ${stat('Meta. age', latest.metaAge, 'yr')}
            ${stat('Subcut.', latest.subcut, '%')}
          </div>`)}
        </div>
        ${trendCard('Weight', 'health', p => p.weightKg, 'kg')}
        ${trendCard('Body fat', 'energy', p => p.bodyFatPercent, '%')}
        ${trendCard('Muscle', 'protein', p => p.muscle, 'kg')}
        ${prediction ? `<div class="mt-4">${surfaceCard(`
          ${cardTitle('Prediction', '🎯', 'accent')}
          ${goalDateStr ? `<p class="font-semibold text-[17px] mt-2">Goal around ${goalDateStr}</p>` : ''}
          <div class="flex gap-6 mt-3">
            <div><p class="font-semibold text-[15px] tabular">${prediction.projectedWeightKg.toFixed(1)} kg</p>
                 <p class="text-[11px] text-tsecondary">projected weight</p></div>
            ${prediction.projectedBodyFatPercent != null ? `
            <div><p class="font-semibold text-[15px] tabular">${prediction.projectedBodyFatPercent.toFixed(1)} %</p>
                 <p class="text-[11px] text-tsecondary">projected body fat</p></div>` : ''}
          </div>
          <div class="mt-3">${lineChart(prediction.series.map(p => ({ y: p.weightKg })), 'accent', { dashed: true, height: 120 })}</div>
          <p class="text-[13px] text-tsecondary mt-2">Confidence: ${prediction.confidence} · based on your recent trend</p>`)}</div>` : ''}`}
      <div class="mt-5">${primaryBtn('Add measurement', 'App.openAddBIA()')}</div>`;
  }

  function openAddBIA() {
    const fields = [
      ['bia-bodyFat', 'Body fat %'], ['bia-lbm', 'Lean body mass (kg)'],
      ['bia-muscle', 'Muscle mass (kg)'], ['bia-waterPct', 'Body water %'],
      ['bia-visceral', 'Visceral fat'], ['bia-bone', 'Bone mass (kg)'],
      ['bia-proteinPct', 'Protein %'], ['bia-bmi', 'BMI'],
      ['bia-bmr', 'Basal metabolism (kcal)'], ['bia-metaAge', 'Metabolic age'],
      ['bia-subcut', 'Subcutaneous fat %'],
    ];
    openSheet(`
      ${sheetHeader('Add measurement')}
      <div class="space-y-2">
        <input id="bia-date" type="date" value="${Store.todayISO()}" max="${Store.todayISO()}"
          class="w-full bg-bg rounded-chip px-4 py-3 text-[15px] outline-none">
        ${input('bia-weight', 'Weight (kg) — required', 'number')}
        <p class="text-[12px] font-medium uppercase tracking-wider text-tsecondary pt-2">Body composition (optional)</p>
        <div class="grid grid-cols-2 gap-2">
          ${fields.map(([id, label]) => input(id, label, 'number')).join('')}
        </div>
        ${primaryBtn('Save', 'App.saveBIA()', 'mt-2')}
      </div>`);
  }

  function saveBIA() {
    const v = id => {
      const raw = document.getElementById(id).value;
      return raw === '' ? null : parseFloat(raw.replace(',', '.'));
    };
    const weight = v('bia-weight');
    if (weight == null || isNaN(weight)) return;
    S().panels.push({
      id: Store.uid(), date: document.getElementById('bia-date').value || Store.todayISO(),
      weightKg: weight, bodyFatPercent: v('bia-bodyFat'), leanBodyMassKg: v('bia-lbm'),
      muscle: v('bia-muscle'), waterPct: v('bia-waterPct'), visceral: v('bia-visceral'),
      bone: v('bia-bone'), proteinPct: v('bia-proteinPct'), bmi: v('bia-bmi'),
      bmr: v('bia-bmr'), metaAge: v('bia-metaAge'), subcut: v('bia-subcut'),
    });
    Store.save();
    closeSheet();
    checkMilestones();
    render();
  }

  // ============================================================
  // Screen: Wardrobe (WardrobeView.swift)
  // ============================================================
  let wardrobeFilter = { collectionId: null, wishlist: false };

  function renderWardrobe() {
    const s = S();
    const items = s.wardrobe.filter(w =>
      (!wardrobeFilter.collectionId || w.collectionId === wardrobeFilter.collectionId)
      && (!wardrobeFilter.wishlist || w.wishlist));
    // MasonryGrid: distribute to the shorter column by estimated height.
    const cols = [[], []], heights = [0, 0];
    items.forEach(item => {
      const h = item.image ? 240 : 150;
      const i = heights[0] <= heights[1] ? 0 : 1;
      cols[i].push(item);
      heights[i] += h;
    });

    const itemCard = (item) => `
      <button onclick="App.openWardrobeItem('${item.id}')" class="w-full text-left bg-surface rounded-2xl overflow-hidden">
        <div class="flex items-center justify-center overflow-hidden"
             style="height:${item.image ? 170 : 90}px;background:color-mix(in srgb, var(--celebrate) 10%, transparent)">
          ${item.image ? `<img src="${item.image}" class="w-full h-full object-cover" alt="">`
                       : `<span class="text-4xl">${CATEGORY_ICONS[item.category] || '🛍️'}</span>`}
        </div>
        <div class="p-3">
          <p class="font-medium text-[15px] truncate">${esc(item.title)}</p>
          <div class="flex items-center justify-between mt-1">
            <span class="text-[12px] text-tsecondary">Size ${esc(item.targetSize)}</span>
            <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full"
              style="background:color-mix(in srgb, var(--${item.fitStatus === 'fits' ? 'celebrate' : 'accent'}) 15%, transparent);
                     color:var(--${item.fitStatus === 'fits' ? 'celebrate' : 'accent'})">${FIT_LABELS[item.fitStatus]}</span>
          </div>
        </div>
      </button>`;

    return `
      <div class="flex items-center justify-between pt-1">
        <h1 class="text-[28px] font-bold">Wardrobe</h1>
        <button onclick="App.openAddWardrobe()" class="text-2xl leading-none" style="color:var(--accent)">＋</button>
      </div>
      <div class="flex gap-2 overflow-x-auto noscroll mt-3 -mx-5 px-5 pb-1">
        ${chipBtn('All', 'App.setWardrobeFilter(null,false)', !wardrobeFilter.collectionId && !wardrobeFilter.wishlist)}
        ${s.collections.map(c => chipBtn(c.name, `App.setWardrobeFilter('${c.id}',false)`, wardrobeFilter.collectionId === c.id)).join('')}
        ${chipBtn('✨ Wishlist', 'App.setWardrobeFilter(null,true)', wardrobeFilter.wishlist)}
        ${chipBtn('＋', 'App.newCollection()', false)}
      </div>
      ${items.length ? `
        <div class="flex gap-3 items-start mt-4">
          <div class="flex-1 space-y-3">${cols[0].map(itemCard).join('')}</div>
          <div class="flex-1 space-y-3">${cols[1].map(itemCard).join('')}</div>
        </div>` : `
        <div class="mt-10 text-center px-6">
          <div class="text-4xl mb-3">✨</div>
          <p class="font-semibold text-[17px]">Your dream wardrobe</p>
          <p class="text-tsecondary text-[15px] mt-1">Pin the outfits you're working toward. They'll cheer you on from your dashboard.</p>
        </div>`}`;
  }

  function setWardrobeFilter(collectionId, wishlist) {
    wardrobeFilter = { collectionId, wishlist };
    render();
  }

  function newCollection() {
    const name = prompt('New collection name');
    if (name && name.trim()) {
      S().collections.push({ id: Store.uid(), name: name.trim() });
      Store.save();
      render();
    }
  }

  function openWardrobeItem(id) {
    const item = S().wardrobe.find(w => w.id === id);
    if (!item) return;
    push(item.title, () => `
      ${item.image ? `<img src="${item.image}" class="w-full rounded-card mb-4" alt="">` : ''}
      ${surfaceCard(`
        <p class="text-[12px] font-medium uppercase tracking-wider text-tsecondary mb-2">Fit progress</p>
        <div class="grid grid-cols-4 gap-1 bg-bg rounded-chip p-1">
          ${Object.entries(FIT_LABELS).map(([k, label]) => `
            <button onclick="App.setFit('${item.id}','${k}')"
              class="py-2 rounded-[9px] text-[10px] font-medium ${item.fitStatus === k ? 'bg-surface shadow' : 'text-tsecondary'}">${label}</button>`).join('')}
        </div>
        <div class="flex items-center justify-between mt-4">
          <span class="text-[15px]">Pinned to dashboard</span>
          <button onclick="App.toggleItem('${item.id}','pinned')" role="switch" aria-checked="${item.pinned}"
            class="w-12 h-7 rounded-full relative transition-colors"
            style="background:${item.pinned ? 'var(--accent)' : 'color-mix(in srgb, var(--text-secondary) 30%, transparent)'}">
            <span class="absolute top-0.5 w-6 h-6 bg-white rounded-full transition-all" style="left:${item.pinned ? '22px' : '2px'}"></span>
          </button>
        </div>
        <div class="flex items-center justify-between mt-3">
          <span class="text-[15px]">Wishlist</span>
          <button onclick="App.toggleItem('${item.id}','wishlist')" role="switch" aria-checked="${item.wishlist}"
            class="w-12 h-7 rounded-full relative transition-colors"
            style="background:${item.wishlist ? 'var(--accent)' : 'color-mix(in srgb, var(--text-secondary) 30%, transparent)'}">
            <span class="absolute top-0.5 w-6 h-6 bg-white rounded-full transition-all" style="left:${item.wishlist ? '22px' : '2px'}"></span>
          </button>
        </div>
        <div class="mt-4 space-y-2">
          ${input('wi-size', 'Target size', 'text', item.targetSize)}
          ${input('wi-notes', 'Notes', 'text', item.notes)}
        </div>`)}
      <div class="mt-4 space-y-2">
        ${primaryBtn('Save', `App.saveWardrobeItem('${item.id}')`)}
        <button onclick="App.deleteWardrobeItem('${item.id}')" class="w-full py-3 text-[15px] font-medium"
          style="color:var(--accent)">Remove item</button>
      </div>`);
  }

  function setFit(id, status) {
    const item = S().wardrobe.find(w => w.id === id);
    if (!item) return;
    item.fitStatus = status;
    Store.save();
    checkMilestones();
    // Re-render the pushed detail with updated segmented control.
    stack.pop();
    openWardrobeItem(id);
  }

  function toggleItem(id, key) {
    const item = S().wardrobe.find(w => w.id === id);
    if (!item) return;
    item[key] = !item[key];
    Store.save();
    stack.pop();
    openWardrobeItem(id);
  }

  function saveWardrobeItem(id) {
    const item = S().wardrobe.find(w => w.id === id);
    if (!item) return;
    item.targetSize = document.getElementById('wi-size').value;
    item.notes = document.getElementById('wi-notes').value;
    Store.save();
    pop();
  }

  function deleteWardrobeItem(id) {
    const s = S();
    s.wardrobe = s.wardrobe.filter(w => w.id !== id);
    Store.save();
    pop();
  }

  function openAddWardrobe() {
    sheetImageData = null;
    const s = S();
    openSheet(`
      ${sheetHeader('New item')}
      <div class="space-y-2">
        ${input('nw-title', 'Title')}
        <select id="nw-category" class="w-full bg-bg rounded-chip px-4 py-3 text-[15px] outline-none">
          ${Object.keys(CATEGORY_ICONS).map(c => `<option value="${c}">${c[0].toUpperCase() + c.slice(1)}</option>`).join('')}
        </select>
        ${input('nw-size', 'Target size')}
        <select id="nw-collection" class="w-full bg-bg rounded-chip px-4 py-3 text-[15px] outline-none">
          <option value="">No collection</option>
          ${s.collections.map(c => `<option value="${c.id}">${esc(c.name)}</option>`).join('')}
        </select>
        <label class="flex items-center gap-2 text-[15px] py-1"><input id="nw-wishlist" type="checkbox"> Wishlist</label>
        <label class="block bg-bg rounded-chip px-4 py-3 text-[15px] cursor-pointer" style="color:var(--accent)">
          📷 <span id="nw-photo-label">Choose photo</span>
          <input id="nw-photo" type="file" accept="image/*" class="hidden">
        </label>
        <div id="nw-preview"></div>
        ${input('nw-notes', 'Why this piece?')}
        ${primaryBtn('Add', 'App.saveNewWardrobe()', 'mt-2')}
      </div>`);
    document.getElementById('nw-photo').addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        sheetImageData = reader.result;
        document.getElementById('nw-photo-label').textContent = 'Change photo';
        document.getElementById('nw-preview').innerHTML =
          `<img src="${sheetImageData}" class="rounded-chip max-h-40 mx-auto" alt="">`;
      };
      reader.readAsDataURL(file);
    });
  }

  function saveNewWardrobe() {
    const title = document.getElementById('nw-title').value.trim();
    const size = document.getElementById('nw-size').value.trim();
    if (!title || !size) return;
    S().wardrobe.unshift({
      id: Store.uid(), title, category: document.getElementById('nw-category').value,
      targetSize: size, notes: document.getElementById('nw-notes').value,
      wishlist: document.getElementById('nw-wishlist').checked,
      fitStatus: 'dream', pinned: false, image: sheetImageData,
      collectionId: document.getElementById('nw-collection').value || null,
    });
    Store.save();
    closeSheet();
    render();
  }

  // ============================================================
  // Screen: Cycle Planner (CyclePlannerView.swift)
  // ============================================================
  function cycleView() {
    const s = S();
    const state = Engines.cycleState(s.cycles, Store.todayISO());
    if (!state) {
      return `
        <div class="mt-6 text-center px-6">
          <div class="text-4xl mb-3">🌙</div>
          <p class="font-semibold text-[17px]">Cycle planner</p>
          <p class="text-tsecondary text-[15px] mt-1">Log the first day of your period and Aura adapts your targets to each phase automatically.</p>
        </div>
        <div class="mt-6">${primaryBtn('Log period start', 'App.openLogPeriod()')}</div>`;
    }
    const rec = Engines.phaseRecommendation(state.phase);
    const L = state.averageCycleLength, ov = L - 14;
    const segments = [
      ['menstrual', 0, 5], ['follicular', 5, ov - 1], ['ovulation', ov - 1, ov + 1], ['luteal', ov + 1, L],
    ];
    const row = (icon, title, text) => `
      <div class="flex gap-3 items-start">
        <span class="w-6 text-center shrink-0" style="color:var(--cycle)">${icon}</span>
        <div><p class="font-medium text-[15px]">${title}</p>
             <p class="text-[13px] text-tsecondary">${esc(text)}</p></div>
      </div>`;
    return `
      ${glassCard(`
        ${cardTitle('Current phase', '🌙', 'cycle')}
        <p class="font-semibold text-[17px] mt-2">${Engines.PHASE_NAMES[state.phase]} · Day ${state.dayInCycle}</p>
        <p class="text-[13px] text-tsecondary mt-1">Your targets are already adapted for this phase.</p>`)}
      <div class="mt-4">${surfaceCard(`
        ${cardTitle('Your cycle', '📅', 'cycle')}
        <div class="relative mt-3" style="height:14px">
          <div class="flex gap-0.5 h-3.5">
            ${segments.map(([phase, a, b]) => `
              <div class="rounded-full h-full" style="width:${((b - a) / L * 100).toFixed(1)}%;
                background:var(--cycle);opacity:${phase === state.phase ? 0.9 : 0.25}"></div>`).join('')}
          </div>
          <div class="absolute top-0.5 w-2.5 h-2.5 rounded-full" style="background:var(--text-primary);
            left:calc(${((state.dayInCycle - 1) / L * 100).toFixed(1)}% - 5px)"></div>
        </div>
        <div class="flex justify-between text-[11px] text-tsecondary mt-2"><span>Day 1</span><span>Day ${L}</span></div>`)}
      </div>
      <div class="mt-4">${surfaceCard(`
        ${cardTitle('This phase, your body prefers', '💗', 'cycle')}
        <div class="space-y-4 mt-4">
          ${row('💪', 'Workout', rec.workout)}
          ${row('🛌', 'Recovery', rec.recovery)}
          ${row('🏃', 'Cardio', rec.cardio)}
          ${row('🏋️', 'Strength', rec.strength)}
          ${row('😴', 'Sleep', rec.sleep)}
          ${rec.proteinAdj > 0 ? row('🍗', 'Protein', `+${rec.proteinAdj} g added to your target`) : ''}
          ${rec.waterAdj > 0 ? row('💧', 'Hydration', `+${rec.waterAdj} ml added to your target`) : ''}
        </div>`)}
      </div>
      <div class="mt-5">${primaryBtn('Log period start', 'App.openLogPeriod()')}</div>`;
  }

  function openLogPeriod() {
    openSheet(`
      ${sheetHeader('Log period')}
      <input id="period-date" type="date" value="${Store.todayISO()}" max="${Store.todayISO()}"
        class="w-full bg-bg rounded-chip px-4 py-3 text-[15px] outline-none">
      ${primaryBtn('Save', 'App.savePeriod()', 'mt-3')}`);
  }

  function savePeriod() {
    const date = document.getElementById('period-date').value;
    if (!date) return;
    S().cycles.push(date);
    S().cycles.sort();
    Store.save();
    closeSheet();
    render();
  }

  // ============================================================
  // Screen: Me (MeView.swift + subviews)
  // ============================================================
  function renderMe() {
    const s = S();
    const snaps = recentSnapshots(28);
    // MotivationEngine.identityStatements port.
    const identity = [];
    const workoutDays = snaps.filter(x => x.metrics.activity?.workoutCompleted).length;
    if (workoutDays >= 8) identity.push(`I am someone who trains ${Math.max(Math.floor(workoutDays / 4), 2)}× a week.`);
    if (snaps.filter(x => x.metrics.proteinG >= x.targets.proteinG * 0.9).length >= 14) identity.push('I am someone who fuels my body with protein.');
    if (snaps.filter(x => x.metrics.waterMl >= x.targets.waterMl * 0.9).length >= 14) identity.push('I am someone who stays hydrated.');
    if (snaps.length >= 21) identity.push('I am someone who shows up, even on hard days.');

    const nextLetter = s.letters.find(l => !l.deliveredAt);
    const linkCard = (icon, title, subtitle, onclick) => `
      <button onclick="${onclick}" class="w-full text-left">${surfaceCard(`
        <div class="flex items-center gap-4">
          <span class="w-7 text-center text-lg shrink-0">${icon}</span>
          <div class="min-w-0 flex-1">
            <p class="font-medium text-[15px]">${esc(title)}</p>
            <p class="text-[13px] text-tsecondary truncate">${esc(subtitle)}</p>
          </div>
          <span class="text-tsecondary text-[13px]">›</span>
        </div>`)}</button>`;

    return `
      <h1 class="text-[28px] font-bold pt-1">Me</h1>
      <div class="mt-4">
        <button onclick="App.editArtifact('why')" class="w-full text-left">${glassCard(`
          ${cardTitle('Why I started', '🌱', 'accent')}
          <p class="italic text-[15px] mt-2">${esc(s.why || 'Tap to capture your why — the root of everything.')}</p>`)}
        </button>
      </div>
      ${identity.length ? `<div class="mt-4">${surfaceCard(`
        ${cardTitle("Who you're becoming", '🏅', 'celebrate')}
        <ul class="mt-2 space-y-1.5">
          ${identity.map(i => `<li class="flex gap-2 text-[15px]"><span style="color:var(--celebrate)">✓</span>${esc(i)}</li>`).join('')}
        </ul>`)}</div>` : ''}
      <div class="mt-4 space-y-3">
        ${linkCard('🕰️', 'Future me', s.futureMe ? s.futureMe.slice(0, 60) : "Write a picture of who you're becoming", "App.editArtifact('futureMe')")}
        ${linkCard('✉️', 'Letter to myself', nextLetter?.deliverAt ? `Opens ${fmtDate(nextLetter.deliverAt)}` : 'Write to the future you', 'App.push(\'Letters\', App.views.letters)')}
        ${linkCard('🏆', 'Milestones', `${s.milestones.length} unlocked`, 'App.push(\'Milestones\', App.views.milestones)')}
        ${linkCard('📈', 'Transformation timeline', 'Your journey, replayed', 'App.push(\'Timeline\', App.views.timeline)')}
        <div class="h-px bg-black/5 dark:bg-white/5 my-2"></div>
        ${linkCard('🌙', 'Cycle planner', 'Phase-aware targets and training', 'App.push(\'Cycle\', App.views.cycle)')}
        ${linkCard('🧪', 'Prototype data', 'Reload demo data or reset', 'App.push(\'Prototype data\', App.views.devtools)')}
      </div>`;
  }

  function editArtifact(kind) {
    const s = S();
    const prompts = {
      why: 'Why did you start? Your own words will carry you further than any quote.',
      futureMe: 'Describe the person you’re becoming. What does their ordinary Tuesday look like?',
    };
    const titles = { why: 'Why I started', futureMe: 'Future me' };
    push(titles[kind], () => `
      <p class="text-tsecondary text-[15px]">${prompts[kind]}</p>
      <textarea id="artifact-text" rows="6"
        class="w-full bg-surface rounded-card p-4 mt-4 text-[15px] outline-none resize-none">${esc(kind === 'why' ? s.why : s.futureMe)}</textarea>
      <div class="mt-4">${primaryBtn('Save', `App.saveArtifact('${kind}')`)}</div>`);
  }

  function saveArtifact(kind) {
    const text = document.getElementById('artifact-text').value.trim();
    if (kind === 'why') S().why = text; else S().futureMe = text;
    Store.save();
    pop();
  }

  function lettersView() {
    const s = S();
    const today = Store.todayISO();
    // Deliver due letters (MotivationEngine.lettersToDeliver).
    let delivered = false;
    s.letters.forEach(l => {
      if (!l.deliveredAt && l.deliverAt && l.deliverAt <= today) { l.deliveredAt = today; delivered = true; }
    });
    if (delivered) Store.save();
    const defaultDeliver = Store.todayISO(30);
    return `
      <div class="space-y-4">
        ${s.letters.filter(l => l.deliveredAt).map(l => surfaceCard(`
          ${cardTitle('Delivered ' + fmtDate(l.deliveredAt), '💌', 'celebrate')}
          <p class="text-[15px] mt-2">${esc(l.text)}</p>`)).join('')}
        ${s.letters.filter(l => !l.deliveredAt).map(l => surfaceCard(
          cardTitle('Sealed — opens ' + fmtDate(l.deliverAt), '✉️'))).join('')}
        ${surfaceCard(`
          ${cardTitle('New letter', '✍️', 'accent')}
          <textarea id="letter-text" rows="4" placeholder="Dear future me…"
            class="w-full bg-bg rounded-chip p-3 mt-3 text-[15px] outline-none resize-none"></textarea>
          <div class="flex items-center justify-between mt-3 text-[15px]">
            <span>Deliver on</span>
            <input id="letter-date" type="date" value="${defaultDeliver}" min="${Store.todayISO(1)}"
              class="bg-bg rounded-chip px-3 py-2 outline-none">
          </div>
          <div class="mt-3">${primaryBtn('Seal letter', 'App.sealLetter()')}</div>`)}
      </div>`;
  }

  function sealLetter() {
    const text = document.getElementById('letter-text').value.trim();
    const date = document.getElementById('letter-date').value;
    if (!text || !date) return;
    S().letters.push({ id: Store.uid(), text, deliverAt: date, deliveredAt: null });
    Store.save();
    stack.pop();
    push('Letters', lettersView);
  }

  function milestonesView() {
    const list = [...S().milestones].sort((a, b) => b.date.localeCompare(a.date));
    if (!list.length) {
      return `<div class="mt-6 text-center px-6">
        <div class="text-4xl mb-3">🏆</div>
        <p class="font-semibold text-[17px]">Milestones ahead</p>
        <p class="text-tsecondary text-[15px] mt-1">Keep showing up — your first milestone is closer than you think.</p></div>`;
    }
    return `<div class="space-y-3">${list.map(m => surfaceCard(`
      <div class="flex items-center gap-4">
        <span class="text-lg" style="color:var(--celebrate)">🏆</span>
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-[15px]">${esc(m.title)}</p>
          <p class="text-[13px] text-tsecondary">${esc(m.detail)}</p>
        </div>
        <span class="text-[11px] text-tsecondary shrink-0">${fmtDate(m.date)}</span>
      </div>`)).join('')}</div>`;
  }

  function timelineView() {
    const s = S();
    const snaps = recentSnapshots(90);
    return `
      ${s.why ? glassCard(`
        ${cardTitle('Where it began', '🌱', 'accent')}
        <p class="italic text-[15px] mt-2">“${esc(s.why)}”</p>`) : ''}
      ${snaps.length >= 2 ? `<div class="mt-4">${surfaceCard(`
        ${cardTitle('Momentum over time', '🔥', 'accent')}
        <div class="mt-3">${sparkline(snaps.map(x => x.momentum.overall), 'accent', 48)}</div>
        <p class="text-[13px] text-tsecondary mt-2">${snaps.length} days logged on this journey</p>`)}</div>` : `
        <div class="mt-6 text-center px-6">
          <div class="text-4xl mb-3">📈</div>
          <p class="font-semibold text-[17px]">Your story is just starting</p>
          <p class="text-tsecondary text-[15px] mt-1">As days accumulate, this timeline becomes the proof of how far you've come.</p>
        </div>`}`;
  }

  function devtoolsView() {
    return `
      <p class="text-tsecondary text-[15px]">Prototype-only utilities for UX testing.</p>
      <div class="mt-4 space-y-2">
        ${primaryBtn('Load demo data (Elif, day 32)', 'App.demo()')}
        <button onclick="App.resetAll()" class="w-full py-3 text-[15px] font-medium" style="color:var(--cycle)">Reset all data</button>
      </div>`;
  }

  function demo() { Store.loadDemo(); stack = []; tab = 'today'; render(); }
  function resetAll() { Store.reset(); stack = []; tab = 'today'; render(); }

  // ============================================================
  // Screen: Onboarding (OnboardingView.swift)
  // ============================================================
  const Onboarding = (() => {
    let step = 0; // welcome, why, profile, goal, activity, cycle, reveal
    const data = {
      why: '', name: '', age: 32, heightCm: 165, sex: 'female',
      currentWeight: 70, targetWeight: 62, weeklyRate: 0.5,
      activityLevel: 'light', cycleOptIn: false,
    };

    const stepTitle = (title, subtitle) => `
      <h1 class="text-[26px] font-bold mt-2">${title}</h1>
      <p class="text-tsecondary text-[15px] mt-2">${subtitle}</p>`;

    const stepper = (label, value, onMinus, onPlus) => `
      <div class="flex items-center justify-between py-1">
        <span class="text-[15px]">${label}: <b class="tabular">${value}</b></span>
        <div class="flex gap-2">
          <button onclick="${onMinus}" class="w-9 h-9 rounded-full bg-bg text-lg leading-none">−</button>
          <button onclick="${onPlus}" class="w-9 h-9 rounded-full bg-bg text-lg leading-none">＋</button>
        </div>
      </div>`;

    function content() {
      switch (step) {
        case 0: return `
          <div class="text-center pt-16">
            <div class="text-6xl mb-6">🌿</div>
            <h1 class="text-[32px] font-bold">Welcome to Aura</h1>
            <p class="text-tsecondary text-[15px] mt-4 px-2">This isn't a diet app. It's a system for staying connected
              to your goal — on strong days and soft days alike. No shame, no streaks to break. Just momentum.</p>
            <button onclick="App.demo()" class="mt-8 text-[13px] underline text-tsecondary">
              or explore with demo data</button>
          </div>`;
        case 1: return `
          ${stepTitle('Before any numbers…', 'Why did you start? Your own words will matter more than any target we compute.')}
          <textarea id="ob-why" rows="5" placeholder="I want to…"
            class="w-full bg-surface rounded-card p-4 mt-4 text-[15px] outline-none resize-none">${esc(data.why)}</textarea>`;
        case 2: return `
          ${stepTitle('About you', 'Used only to personalize your targets.')}
          <div class="bg-surface rounded-card p-6 mt-4 space-y-3">
            <input id="ob-name" placeholder="Name" value="${esc(data.name)}"
              class="w-full bg-bg rounded-chip px-4 py-3 text-[15px] outline-none">
            ${stepper('Age', data.age, "App.ob('age',-1)", "App.ob('age',1)")}
            ${stepper('Height', data.heightCm + ' cm', "App.ob('heightCm',-1)", "App.ob('heightCm',1)")}
            <div class="grid grid-cols-3 gap-1 bg-bg rounded-chip p-1">
              ${[['female', 'Female'], ['male', 'Male'], ['unspecified', 'Prefer not']].map(([v, l]) => `
                <button onclick="App.obSet('sex','${v}')"
                  class="py-2 rounded-[9px] text-[12px] font-medium ${data.sex === v ? 'bg-surface shadow' : 'text-tsecondary'}">${l}</button>`).join('')}
            </div>
          </div>`;
        case 3: return `
          ${stepTitle('Your goal', "Aura keeps the pace sustainable — that's how you'll actually get there.")}
          <div class="bg-surface rounded-card p-6 mt-4 space-y-3">
            ${stepper('Current weight', data.currentWeight.toFixed(1) + ' kg', "App.ob('currentWeight',-0.5)", "App.ob('currentWeight',0.5)")}
            ${stepper('Target weight', data.targetWeight.toFixed(1) + ' kg', "App.ob('targetWeight',-0.5)", "App.ob('targetWeight',0.5)")}
            <div>
              <p class="text-[15px] mb-1">Pace: <b class="tabular">${data.weeklyRate.toFixed(2)} kg / week</b></p>
              <input type="range" min="0.25" max="0.75" step="0.05" value="${data.weeklyRate}"
                oninput="App.obSet('weeklyRate', parseFloat(this.value))" class="w-full accent-[var(--accent)]">
              <p class="text-[13px] text-tsecondary mt-1">Gentler paces preserve muscle and are far easier to sustain.</p>
            </div>
          </div>`;
        case 4: return `
          ${stepTitle('How active are you?', 'Be honest — targets adjust automatically as your data comes in.')}
          <div class="space-y-3 mt-4">
            ${Object.entries(Engines.ACTIVITY).map(([key, a]) => `
              <button onclick="App.obSet('activityLevel','${key}')" class="w-full text-left bg-surface rounded-card p-5">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="font-medium text-[15px]">${a.label}</p>
                    <p class="text-[13px] text-tsecondary">${a.detail}</p>
                  </div>
                  <span style="color:var(--accent)">${data.activityLevel === key ? '●' : '○'}</span>
                </div>
              </button>`).join('')}
          </div>`;
        case 5: return `
          ${stepTitle('Cycle-aware targets', 'Optional and private. Aura can adapt calories, protein, hydration, and training to your menstrual phase — so a luteal week never feels like failure.')}
          <div class="bg-surface rounded-card p-6 mt-4 flex items-center justify-between">
            <span class="text-[15px]">Enable cycle tracking</span>
            <button onclick="App.obSet('cycleOptIn', ${!data.cycleOptIn})" role="switch" aria-checked="${data.cycleOptIn}"
              class="w-12 h-7 rounded-full relative"
              style="background:${data.cycleOptIn ? 'var(--cycle)' : 'color-mix(in srgb, var(--text-secondary) 30%, transparent)'}">
              <span class="absolute top-0.5 w-6 h-6 bg-white rounded-full transition-all" style="left:${data.cycleOptIn ? '22px' : '2px'}"></span>
            </button>
          </div>
          <p class="text-[13px] text-tsecondary mt-3">Cycle data stays in this browser and can be deleted at any time.</p>`;
        case 6: {
          const profile = { name: data.name, age: data.age, heightCm: data.heightCm, sex: data.sex, activityLevel: data.activityLevel, cycleTracking: data.cycleOptIn && data.sex === 'female' };
          const goal = { kind: 'fatLoss', targetWeightKg: data.targetWeight, weeklyRateKg: data.weeklyRate, startWeightKg: data.currentWeight, startDate: Store.todayISO() };
          const t = Engines.targets(profile, goal, { weightKg: data.currentWeight }, null);
          const pred = Engines.predict([{ daysAgo: 0, weightKg: data.currentWeight }], goal);
          const goalDateStr = pred?.goalDays != null
            ? new Date(Date.now() + pred.goalDays * 86400000).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }) : null;
          const row = (icon, label, value, tintVar) => `
            <div class="flex items-center gap-3">
              <span class="w-6 text-center" style="color:var(--${tintVar})">${icon}</span>
              <span class="text-[15px] flex-1">${label}</span>
              <span class="font-semibold text-[15px] tabular">${value}</span>
            </div>`;
          return `
            ${stepTitle('Your plan', 'Computed for your body — and recomputed automatically as it changes.')}
            <div class="bg-surface rounded-card p-6 mt-4 space-y-3">
              ${row('⚡', 'Calories', `${t.calories} kcal`, 'energy')}
              ${row('🍗', 'Protein', `${t.proteinG} g — based on your lean mass`, 'protein')}
              ${row('💧', 'Water', `${(t.waterMl / 1000).toFixed(1)} L`, 'water')}
              ${row('🚶', 'Steps', t.steps.toLocaleString(), 'accent')}
              ${row('😴', 'Sleep', `${t.sleepHours} h`, 'health')}
            </div>
            ${goalDateStr ? `<div class="mt-4">${glassCard(`
              ${cardTitle('Sustainable estimate', '🎯', 'accent')}
              <p class="font-semibold text-[17px] mt-2">Around ${goalDateStr}</p>
              <p class="text-[13px] text-tsecondary mt-1">At your chosen pace. Real data will refine this every week.</p>`)}</div>` : ''}`;
        }
      }
    }

    function renderView() {
      return `
        <div class="screen px-5 pt-6 pb-8 min-h-full flex flex-col">
          <div class="h-1 rounded-full overflow-hidden" style="background:color-mix(in srgb, var(--accent) 15%, transparent)">
            <div class="h-full rounded-full bar-fill" style="background:var(--accent);width:0%" data-final="${(step / 6 * 100).toFixed(0)}"></div>
          </div>
          <div class="flex-1">${content()}</div>
          <div class="flex gap-3 mt-6">
            ${step > 0 ? `<button onclick="App.obBack()" class="px-5 py-3.5 font-semibold text-[15px]" style="color:var(--accent)">Back</button>` : ''}
            ${primaryBtn(step === 6 ? 'Start my journey' : 'Continue', 'App.obNext()')}
          </div>
        </div>`;
    }

    function next() {
      if (step === 1) data.why = document.getElementById('ob-why')?.value.trim() ?? data.why;
      if (step === 2) {
        data.name = document.getElementById('ob-name')?.value.trim() ?? data.name;
        if (!data.name) return;
      }
      if (step === 6) { complete(); return; }
      step++;
      render();
    }
    function back() { step = Math.max(0, step - 1); render(); }
    function set(key, value) {
      if (step === 1) data.why = document.getElementById('ob-why')?.value ?? data.why;
      if (step === 2) data.name = document.getElementById('ob-name')?.value ?? data.name;
      data[key] = value;
      render();
    }
    function bump(key, delta) {
      const bounds = { age: [14, 100], heightCm: [120, 220], currentWeight: [35, 250], targetWeight: [35, 250] };
      set(key, Engines.clamp(+(data[key] + delta).toFixed(1), ...bounds[key]));
    }

    function complete() {
      const s = S();
      s.profile = { name: data.name, age: data.age, heightCm: data.heightCm, sex: data.sex, activityLevel: data.activityLevel, cycleTracking: data.cycleOptIn && data.sex === 'female' };
      s.goal = { kind: 'fatLoss', targetWeightKg: data.targetWeight, weeklyRateKg: data.weeklyRate, startWeightKg: data.currentWeight, startDate: Store.todayISO() };
      s.why = data.why;
      s.panels.push({ id: Store.uid(), date: Store.todayISO(), weightKg: data.currentWeight });
      Store.save();
      render();
    }

    return { render: renderView, next, back, set, bump };
  })();

  // ---------- Boot ----------
  function init() {
    document.querySelectorAll('.tab-btn').forEach(b =>
      b.addEventListener('click', () => switchTab(b.dataset.tab)));
    render();
  }
  document.addEventListener('DOMContentLoaded', init);

  return {
    // navigation
    push, pop, switchTab, closeSheet, dismissCelebration,
    views: {
      momentumDetail: momentumDetailView, healthDetail: healthDetailView,
      cycle: cycleView, letters: lettersView, milestones: milestonesView,
      timeline: timelineView, devtools: devtoolsView,
    },
    // today
    quickWater,
    // nutrition
    shiftNutritionDay, openAddFood, logFood, logManual, deleteMeal, toggleFavorite, addWater,
    // body
    openAddBIA, saveBIA,
    // wardrobe
    setWardrobeFilter, newCollection, openWardrobeItem, setFit, toggleItem,
    saveWardrobeItem, deleteWardrobeItem, openAddWardrobe, saveNewWardrobe,
    // cycle
    openLogPeriod, savePeriod,
    // me
    editArtifact, saveArtifact, sealLetter, demo, resetAll,
    // onboarding
    obNext: Onboarding.next, obBack: Onboarding.back,
    obSet: Onboarding.set, ob: Onboarding.bump,
  };
})();
