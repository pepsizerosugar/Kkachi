// Tracks decorative tab chips so the hero can imply pruning without modeling real browser data.
const tabs = Array.from(document.querySelectorAll(".tab"));
// Keeps the restore rail animation synchronized with the decorative tab cycle.
const rail = document.querySelector(".restore-rail");

// Alternates a few chips into a tucked state; reduced-motion users skip this entirely below.
function cycleScene() {
  tabs.forEach((tab, index) => {
    // Offsets each chip so the motion reads as a rotating queue instead of one synchronized flash.
    const tucked = (Date.now() / 1800 + index) % tabs.length < 2;
    tab.classList.toggle("is-tucked", tucked);
  });
  rail?.classList.toggle("is-active");
}

if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  cycleScene();
  window.setInterval(cycleScene, 2600);
}
