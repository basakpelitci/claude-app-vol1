// Mirrors Aura/DesignSystem/Tokens/AuraTheme.swift — colors resolve through
// CSS variables (defined in src/input.css) so light/dark match the SwiftUI
// adaptive tokens.
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./index.html', './js/**/*.js'],
  darkMode: 'media',
  theme: {
    extend: {
      colors: {
        bg:         'var(--bg)',
        surface:    'var(--surface)',
        tprimary:   'var(--text-primary)',
        tsecondary: 'var(--text-secondary)',
        accent:     'var(--accent)',
        health:     'var(--health)',
        protein:    'var(--protein)',
        water:      'var(--water)',
        energy:     'var(--energy)',
        cycle:      'var(--cycle)',
        celebrate:  'var(--celebrate)',
      },
      borderRadius: {
        card: '24px',   // AuraRadius.card
        chip: '12px',   // AuraRadius.chip
        sheet: '32px',  // AuraRadius.sheet
      },
      fontFamily: {
        sf: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Text', 'Segoe UI', 'Roboto', 'sans-serif'],
        rounded: ['ui-rounded', '-apple-system', 'BlinkMacSystemFont', 'SF Pro Rounded', 'Segoe UI', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
