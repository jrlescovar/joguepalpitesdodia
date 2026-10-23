// This small stable file also runs when an old hashed entry script no longer exists.
window.setTimeout(function () {
  if (document.documentElement.dataset.appReady === 'true') return;
  var notice = document.getElementById('startup-recovery');
  if (notice) notice.hidden = false;
}, 8000);
