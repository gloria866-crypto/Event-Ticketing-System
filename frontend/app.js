const state = {
  apiUrl: localStorage.getItem("eventglova-api-url") || window.EVENTGLOVA_API_URL || "",
  events: [],
};

const elements = {
  dialog: document.querySelector("#settings-dialog"),
  settingsButton: document.querySelector("#settings-button"),
  settingsForm: document.querySelector("#settings-form"),
  apiUrl: document.querySelector("#api-url"),
  eventsList: document.querySelector("#events-list"),
  eventsMessage: document.querySelector("#events-message"),
  refreshEvents: document.querySelector("#refresh-events"),
  registrationForm: document.querySelector("#registration-form"),
  eventSelect: document.querySelector("#event-id"),
  registerButton: document.querySelector("#register-button"),
  registrationMessage: document.querySelector("#registration-message"),
  lookupForm: document.querySelector("#lookup-form"),
  lookupEmail: document.querySelector("#lookup-email"),
  registrationsMessage: document.querySelector("#registrations-message"),
  registrationsList: document.querySelector("#registrations-list"),
  toast: document.querySelector("#toast"),
};

function apiPath(path) {
  if (!state.apiUrl) {
    throw new Error("Add your API Gateway URL in API settings first.");
  }
  return `${state.apiUrl.replace(/\/$/, "")}${path}`;
}

async function apiFetch(path, options = {}) {
  const response = await fetch(apiPath(path), {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.message || "Something went wrong. Please try again.");
  }
  return payload;
}

function showToast(message, isError = false) {
  elements.toast.textContent = message;
  elements.toast.classList.toggle("is-error", isError);
  elements.toast.classList.add("is-visible");
  window.setTimeout(() => elements.toast.classList.remove("is-visible"), 3600);
}

function formatDate(date) {
  if (!date) return "Date to be announced";
  const parsedDate = new Date(`${date}T12:00:00`);
  return Number.isNaN(parsedDate.valueOf())
    ? date
    : new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric" }).format(parsedDate);
}

function escapeHtml(value = "") {
  const text = String(value);
  return text.replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;",
  }[character]));
}

function renderEvents() {
  elements.eventsList.innerHTML = state.events.map((event) => {
    const isSoldOut = Number(event.availableSpots) <= 0;
    return `
      <article class="event-card">
        <div class="event-card-top">
          <span class="tag">${escapeHtml(event.category || "Event")}</span>
          <span class="event-date">${escapeHtml(formatDate(event.date))}</span>
        </div>
        <h3>${escapeHtml(event.name)}</h3>
        <p>${escapeHtml(event.description || "An event you will not want to miss.")}</p>
        <div class="event-meta"><span>⌖ ${escapeHtml(event.location || "Location TBA")}</span><span>${isSoldOut ? "Sold out" : `${escapeHtml(event.availableSpots)} places left`}</span></div>
        <button class="card-button" type="button" data-event-id="${escapeHtml(event.eventId)}" ${isSoldOut ? "disabled" : ""}>${isSoldOut ? "Unavailable" : "Reserve a place →"}</button>
      </article>`;
  }).join("");

  document.querySelectorAll("[data-event-id]").forEach((button) => {
    button.addEventListener("click", () => {
      elements.eventSelect.value = button.dataset.eventId;
      document.querySelector("#register").scrollIntoView({ behavior: "smooth" });
      elements.registrationForm.querySelector("#name").focus();
    });
  });
}

function populateEventSelect() {
  const availableEvents = state.events.filter((event) => Number(event.availableSpots) > 0);
  elements.eventSelect.innerHTML = '<option value="">Select an event</option>' + availableEvents
    .map((event) => `<option value="${escapeHtml(event.eventId)}">${escapeHtml(event.name)} — ${formatDate(event.date)}</option>`)
    .join("");
  elements.eventSelect.disabled = availableEvents.length === 0;
  elements.registerButton.disabled = availableEvents.length === 0;
}

async function loadEvents() {
  elements.eventsMessage.textContent = "Loading events…";
  elements.eventsList.innerHTML = "";
  try {
    state.events = await apiFetch("/events");
    if (!state.events.length) {
      elements.eventsMessage.textContent = "There are no events available right now.";
      populateEventSelect();
      return;
    }
    elements.eventsMessage.textContent = "";
    renderEvents();
    populateEventSelect();
  } catch (error) {
    elements.eventsMessage.textContent = error.message;
    elements.eventSelect.disabled = true;
    elements.registerButton.disabled = true;
  }
}

async function loadRegistrations(email) {
  elements.registrationsMessage.textContent = "Finding your tickets…";
  elements.registrationsList.innerHTML = "";
  try {
    const registrations = await apiFetch(`/registrations/${encodeURIComponent(email.trim().toLowerCase())}`);
    if (!registrations.length) {
      elements.registrationsMessage.textContent = "No active registrations were found for this email.";
      return;
    }
    elements.registrationsMessage.textContent = "";
    elements.registrationsList.innerHTML = registrations.map((registration) => `
      <article class="ticket-card">
        <div><span class="tag">${escapeHtml(registration.status || "active")}</span><h3>${escapeHtml(registration.eventId)}</h3><p>Registered ${escapeHtml(formatDate((registration.registeredAt || "").slice(0, 10)))}</p></div>
        <button class="text-button danger" data-registration-id="${escapeHtml(registration.registrationId)}" type="button">Cancel registration</button>
      </article>`).join("");

    document.querySelectorAll("[data-registration-id]").forEach((button) => {
      button.addEventListener("click", () => cancelRegistration(button.dataset.registrationId, email));
    });
  } catch (error) {
    elements.registrationsMessage.textContent = error.message;
  }
}

async function cancelRegistration(registrationId, email) {
  if (!window.confirm("Cancel this registration? This action cannot be undone.")) return;
  try {
    await apiFetch(`/registration/${encodeURIComponent(registrationId)}`, { method: "DELETE" });
    showToast("Registration cancelled.");
    loadEvents();
    loadRegistrations(email);
  } catch (error) {
    showToast(error.message, true);
  }
}

elements.settingsButton.addEventListener("click", () => {
  elements.apiUrl.value = state.apiUrl;
  elements.dialog.showModal();
});

elements.settingsForm.addEventListener("submit", (event) => {
  if (event.submitter?.value !== "save") return;
  event.preventDefault();
  const input = elements.apiUrl.value.trim().replace(/\/$/, "");
  try {
    const parsed = new URL(input);
    if (parsed.protocol !== "https:" || !parsed.hostname.endsWith(".amazonaws.com")) {
      throw new Error();
    }
  } catch {
    showToast("Invalid URL. Must be an HTTPS API Gateway URL (*.amazonaws.com).", true);
    return;
  }
  state.apiUrl = input;
  localStorage.setItem("eventglova-api-url", state.apiUrl);
  elements.dialog.close();
  loadEvents();
});

elements.refreshEvents.addEventListener("click", loadEvents);

elements.registrationForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const formData = new FormData(elements.registrationForm);
  elements.registrationMessage.textContent = "Reserving your place…";
  try {
    const result = await apiFetch("/register", {
      method: "POST",
      body: JSON.stringify(Object.fromEntries(formData)),
    });
    elements.registrationForm.reset();
    elements.registrationMessage.textContent = "";
    showToast(`You are registered! Confirmation ID: ${result.registrationId}`);
    loadEvents();
  } catch (error) {
    elements.registrationMessage.textContent = error.message;
  }
});

elements.lookupForm.addEventListener("submit", (event) => {
  event.preventDefault();
  loadRegistrations(elements.lookupEmail.value);
});

if (state.apiUrl) {
  loadEvents();
} else {
  elements.settingsButton.click();
}
