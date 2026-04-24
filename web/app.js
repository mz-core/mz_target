const wrapper = document.getElementById("target-wrapper");
const eye = document.getElementById("target-eye");
const statusCard = document.getElementById("target-status-card");
const statusLabel = document.getElementById("target-status-label");
const statusHint = document.getElementById("target-status-hint");
const menu = document.getElementById("target-menu");
const menuTitle = document.getElementById("target-menu-title");
const menuHint = document.getElementById("target-menu-hint");
const optionsRoot = document.getElementById("target-options");
const optionTemplate = document.getElementById("target-option-template");

const menuState = {
  open: false,
};

function resetEye(kind = "default") {
  eye.className = `target-eye kind-${kind}`;
}

function openTarget() {
  wrapper.classList.remove("is-hidden");
  wrapper.setAttribute("aria-hidden", "false");
  statusCard.classList.add("is-hidden");
  menu.classList.add("is-hidden");
  menu.setAttribute("aria-hidden", "true");
  document.body.classList.remove("menu-open");
  menuState.open = false;
  optionsRoot.innerHTML = "";
  resetEye("default");
}

function closeTarget() {
  wrapper.classList.add("is-hidden");
  wrapper.setAttribute("aria-hidden", "true");
  statusCard.classList.add("is-hidden");
  menu.classList.add("is-hidden");
  menu.setAttribute("aria-hidden", "true");
  document.body.classList.remove("menu-open");
  menuState.open = false;
  optionsRoot.innerHTML = "";
  statusLabel.textContent = "";
  statusHint.textContent = "";
  menuTitle.textContent = "";
  menuHint.textContent = "";
  resetEye("default");
}

function foundTarget(target) {
  const kind = String((target && target.kind) || "default").trim() || "default";
  resetEye(kind);
  eye.classList.add("is-active");
  statusLabel.textContent = String((target && target.label) || "Interagir");
  statusHint.textContent = String(
    (target && target.hint) || "Botao direito para abrir menu",
  );
  statusCard.classList.remove("is-hidden");
  menu.classList.add("is-hidden");
  menu.setAttribute("aria-hidden", "true");
  document.body.classList.remove("menu-open");
  menuState.open = false;
  optionsRoot.innerHTML = "";
}

function leftTarget() {
  statusCard.classList.add("is-hidden");
  menu.classList.add("is-hidden");
  menu.setAttribute("aria-hidden", "true");
  document.body.classList.remove("menu-open");
  menuState.open = false;
  optionsRoot.innerHTML = "";
  resetEye("default");
}

function getOptionBadge(kind) {
  switch (String(kind || "").trim()) {
    case "drop":
      return "DROP";
    case "trunk":
      return "TRK";
    case "glovebox":
      return "BOX";
    default:
      return "USE";
  }
}

function createTargetOption(option) {
  const fragment = optionTemplate.content.cloneNode(true);
  const button = fragment.querySelector(".target-option");
  const badge = fragment.querySelector(".target-option-badge");
  const label = fragment.querySelector(".target-option-label");
  const description = fragment.querySelector(".target-option-description");
  const optionId = String(
    (option && (option.id || option.option_id || option.optionId)) || "",
  ).trim();
  const kind = String((option && option.kind) || "default").trim() || "default";

  button.dataset.optionId = optionId;
  button.classList.add(`kind-${kind}`);
  badge.textContent = getOptionBadge(kind);
  label.textContent = String((option && option.label) || "Interagir");
  description.textContent = String(
    (option && option.description) || "Executar esta acao.",
  );

  return fragment;
}

function validTarget(payload) {
  const target = payload && payload.target ? payload.target : {};
  const kind = String(target.kind || "default").trim() || "default";
  const options = Array.isArray(payload && payload.options) ? payload.options : [];

  resetEye(kind);
  eye.classList.add("is-active");
  statusCard.classList.add("is-hidden");
  menuTitle.textContent = String(target.label || "Interagir");
  menuHint.textContent = String(
    target.hint || "Mouse liberado. Escolha uma opcao.",
  );
  optionsRoot.innerHTML = "";

  options.forEach((option) => {
    optionsRoot.appendChild(createTargetOption(option));
  });

  menu.classList.remove("is-hidden");
  menu.setAttribute("aria-hidden", "false");
  document.body.classList.add("menu-open");
  menuState.open = true;
}

async function postNui(route, payload = {}) {
  try {
    await fetch(`https://${GetParentResourceName()}/${route}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify(payload),
    });
  } catch (error) {
    console.error(`[mz_target/ui] failed to post ${route}`, error);
  }
}

optionsRoot.addEventListener("click", (event) => {
  const button = event.target.closest(".target-option");
  if (!button) {
    return;
  }

  const optionId = String(button.dataset.optionId || "").trim();
  if (!optionId) {
    return;
  }

  void postNui("selectTarget", {
    option_id: optionId,
  });
});

window.addEventListener("contextmenu", (event) => {
  if (menuState.open !== true) {
    return;
  }

  event.preventDefault();
});

window.addEventListener("mousedown", (event) => {
  if (menuState.open !== true) {
    return;
  }

  if (event.button === 2) {
    event.preventDefault();
    void postNui("leftTarget");
  }
});

window.addEventListener("keydown", (event) => {
  if (event.key !== "Escape" && event.key !== "Backspace") {
    return;
  }

  void postNui("closeTarget");
});

window.addEventListener("message", (event) => {
  const payload = event.data || {};

  switch (payload.action) {
    case "openTarget":
      openTarget();
      break;
    case "foundTarget":
      openTarget();
      foundTarget(payload.target);
      break;
    case "validTarget":
      openTarget();
      validTarget(payload);
      break;
    case "leftTarget":
      leftTarget();
      break;
    case "closeTarget":
      closeTarget();
      break;
  }
});

closeTarget();
