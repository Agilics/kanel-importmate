/* aurora-theme.js — Dark / Light mode toggle, persisted in localStorage */
(function () {
  const STORAGE_KEY = 'importmate-theme';
  const ICONS = { light: '🌙', dark: '☀️' };
  const TIPS  = { light: 'Mode sombre', dark: 'Mode clair' };

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(STORAGE_KEY, theme);
    const btn = document.querySelector('.theme-toggle');
    if (btn) { btn.textContent = ICONS[theme]; btn.title = TIPS[theme]; }
  }

  // On load: restore saved theme
  const saved = localStorage.getItem(STORAGE_KEY)
    || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  applyTheme(saved);

  // Expose toggle function
  window.toggleTheme = function () {
    const current = document.documentElement.getAttribute('data-theme') || 'light';
    applyTheme(current === 'light' ? 'dark' : 'light');
  };
})();
