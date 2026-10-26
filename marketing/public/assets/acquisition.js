/* Coarse website counts only. No cookies, storage, visitor IDs, or journal data. */
(() => {
  if (location.hostname !== 'isome.isolated.tech' || navigator.globalPrivacyControl || navigator.doNotTrack === '1') return;
  let enabled = false;
  let source = 'direct';
  try {
    const referrer = new URL(document.referrer);
    source = referrer.hostname === location.hostname ? 'internal' :
      /(^|\.)(google\.[a-z.]+|bing\.com|duckduckgo\.com|search\.yahoo\.com)$/.test(referrer.hostname) ? 'search' : 'other';
  } catch { /* Empty or unreadable referrer. */ }

  function count(event, placement) {
    if (!enabled) return;
    // Never send the query string, referrer URL, anchor label, or visitor identifier.
    fetch('/api/v1/acquisition', {
      method: 'POST', credentials: 'omit', keepalive: true, referrerPolicy: 'no-referrer',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ event, page: location.pathname, placement, source }),
    }).catch(() => {});
  }
  document.addEventListener('click', event => {
    const link = event.target.closest?.('a[href]');
    if (!link) return;
    let target;
    try { target = new URL(link.href); } catch { return; }
    if (target.hostname !== 'apps.apple.com' || !target.pathname.includes('id6761960794')) return;
    const placement = link.dataset.placement || (link.closest('footer') ? 'footer' :
      link.closest('nav') ? 'header' : 'inline');
    count('app_store_clicked', placement);
  });
  fetch('https://img-host.costream.workers.dev/analytics-gate', {
    cache: 'no-store', mode: 'cors', credentials: 'omit', referrerPolicy: 'no-referrer',
  }).then(response => response.ok ? response.json() : { track: false })
    .then(gate => {
      enabled = gate?.track === true;
      count('page_view', 'page');
    }).catch(() => {}); // Fail closed, preserving the existing exclusion gate.
})();
