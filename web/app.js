/* Based on qb-target 5.5.0 html/js/app.js (GPL-3.0).
   Modified for MZ: local lucide icons, no FontAwesome CDN, localized hint. */
document.addEventListener("DOMContentLoaded", function () {
  const targetWrapper = document.getElementById("target-wrapper");
  const targetEye = document.getElementById("target-eye");
  const targetHint = document.getElementById("target-hint");
  const targetLabel = document.getElementById("target-label");

  function normalizeIconName(name) {
    if (typeof name !== "string") return "";
    return name
      .trim()
      .replace(/_/g, "-")
      .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
      .toLowerCase();
  }

  function toLucideKey(name) {
    const normalized = normalizeIconName(name);
    if (!normalized) return "";
    return normalized
      .split("-")
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join("");
  }

  function hasLucideIcon(name) {
    const key = toLucideKey(name);
    return Boolean(key && window.lucide?.icons?.[key]);
  }

  function applyLucideIcons() {
    if (!window.lucide?.createIcons || !window.lucide?.icons) return;
    window.lucide.createIcons({ icons: window.lucide.icons, root: targetLabel });
  }

  function OpenTarget(hint) {
    targetWrapper.style.display = "block";
    targetEye.style.display = "block";
    targetEye.classList.remove("target-success");
    targetLabel.textContent = "";
    targetHint.textContent = typeof hint === "string" ? hint : "";
    targetHint.style.display = targetHint.textContent ? "block" : "none";
  }

  function CloseTarget() {
    targetWrapper.style.display = "none";
    targetEye.style.display = "none";
    targetEye.classList.remove("target-success");
    targetLabel.textContent = "";
    targetHint.textContent = "";
    targetHint.style.display = "none";
  }

  function createTargetOption(index, itemData) {
    if (itemData === null || itemData === undefined) return;

    index = Number(index) + 1;
    const targetOption = document.createElement("div");
    targetOption.id = `target-option-${index}`;

    const iconName = normalizeIconName(itemData.icon);
    if (iconName && hasLucideIcon(iconName)) {
      const targetIcon = document.createElement("span");
      targetIcon.id = `target-icon-${index}`;
      const icon = document.createElement("i");
      icon.setAttribute("data-lucide", iconName);
      icon.setAttribute("aria-hidden", "true");
      targetIcon.appendChild(icon);
      targetOption.appendChild(targetIcon);
    }

    targetOption.appendChild(document.createTextNode(String(itemData.label || "")));
    targetLabel.appendChild(targetOption);
  }

  function FoundTarget(item) {
    targetEye.classList.add("target-success");
    targetHint.style.display = "none";
    targetLabel.textContent = "";
    for (let [index, itemData] of Object.entries(item.options || {})) {
      createTargetOption(index, itemData);
    }
    applyLucideIcons();
  }

  function ValidTarget(item) {
    targetHint.style.display = "none";
    targetLabel.textContent = "";
    for (let [index, itemData] of Object.entries(item.data || {})) {
      createTargetOption(index, itemData);
    }
    applyLucideIcons();
  }

  function LeftTarget() {
    targetEye.classList.remove("target-success");
    targetLabel.textContent = "";
    targetHint.style.display = "none";
  }

  function post(route, payload) {
    fetch(`https://${GetParentResourceName()}/${route}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: payload === undefined ? "" : JSON.stringify(payload),
    }).catch((error) => console.error(`[mz_target/ui] ${route}`, error));
  }

  function handleMouseDown(event) {
    const option = event.target.closest?.('[id^="target-option-"]');
    if (option && event.button === 0) {
      const parts = option.id.split("-");
      post("selectTarget", parts[2]);
      targetLabel.textContent = "";
      return;
    }

    if (event.button === 2) {
      event.preventDefault();
      LeftTarget();
      post("leftTarget");
    }
  }

  function handleKeyDown(event) {
    if (event.key === "Escape" || event.key === "Backspace") {
      CloseTarget();
      post("closeTarget");
    }
  }

  window.addEventListener("message", function (event) {
    const payload = event.data || {};
    switch (payload.response) {
      case "openTarget":
        OpenTarget(payload.hint);
        break;
      case "closeTarget":
        CloseTarget();
        break;
      case "foundTarget":
        FoundTarget(payload);
        break;
      case "validTarget":
        ValidTarget(payload);
        break;
      case "leftTarget":
        LeftTarget();
        break;
    }
  });

  window.addEventListener("mousedown", handleMouseDown);
  window.addEventListener("keydown", handleKeyDown);
  window.addEventListener("contextmenu", (event) => event.preventDefault());

  CloseTarget();
});
