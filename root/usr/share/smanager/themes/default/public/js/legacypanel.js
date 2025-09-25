document.addEventListener('DOMContentLoaded', function() {
  var obj = document.getElementById('legacy-embedded');
  if (obj && obj.dataset.legacyHeight) {
    obj.style.height = obj.dataset.legacyHeight;
  }
});