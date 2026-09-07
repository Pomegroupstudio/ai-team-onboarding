/* ==========================================================================
   Pomodoro Focus Timer — Vanilla JavaScript
   ========================================================================== */

(() => {
  "use strict";

  // --- Configuration -------------------------------------------------------
  const WORK_SECONDS = 25 * 60; // 25 minutes
  const BREAK_SECONDS = 5 * 60; // 5 minutes
  const RING_CIRCUMFERENCE = 754; // 2 * PI * 120 (matches SVG radius)

  // --- State ---------------------------------------------------------------
  const state = {
    mode: "work", // "work" | "break"
    remaining: WORK_SECONDS,
    total: WORK_SECONDS,
    running: false,
    completedSessions: 0,
    intervalId: null,
    endTime: null, // timestamp when the current session should end
  };

  // --- DOM references ------------------------------------------------------
  const body = document.body;
  const modeButtons = document.querySelectorAll(".mode-btn");
  const timerLabel = document.getElementById("timer-label");
  const timerDisplay = document.getElementById("timer-display");
  const ringProgress = document.getElementById("ring-progress");
  const btnStart = document.getElementById("btn-start");
  const btnIcon = document.getElementById("btn-icon");
  const btnText = document.getElementById("btn-text");
  const btnReset = document.getElementById("btn-reset");
  const sessionDots = document.getElementById("session-dots");
  const sessionCount = document.getElementById("session-count");

  // --- Web Audio -----------------------------------------------------------
  let audioCtx = null;

  /**
   * Lazily create (and resume) the AudioContext. Browsers require a user
   * gesture before audio can start, so this is called on the first Start.
   */
  function ensureAudioContext() {
    if (!audioCtx) {
      const AudioCtx =
        window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        audioCtx = new AudioCtx();
      }
    }
    if (audioCtx && audioCtx.state === "suspended") {
      audioCtx.resume();
    }
    return audioCtx;
  }

  /**
   * Play a pleasant two-tone chime using the Web Audio API.
   */
  function playChime() {
    const ctx = ensureAudioContext();
    if (!ctx) return;

    const now = ctx.currentTime;
    const notes = [880, 1174.66]; // A5 then D6 — a gentle rising chime

    notes.forEach((freq, index) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = "sine";
      osc.frequency.setValueAtTime(freq, now + index * 0.18);

      // Envelope: quick attack, smooth decay
      const start = now + index * 0.18;
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.5, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.6);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(start);
      osc.stop(start + 0.65);
    });
  }

  // --- Formatting / rendering ---------------------------------------------
  function formatTime(totalSeconds) {
    const mins = Math.floor(totalSeconds / 60);
    const secs = totalSeconds % 60;
    return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }

  function render() {
    timerDisplay.textContent = formatTime(state.remaining);
    timerLabel.textContent = state.mode === "work" ? "Work" : "Break";

    // Progress ring: how much time has elapsed within the current session
    const elapsed = state.total - state.remaining;
    const fraction = state.total > 0 ? elapsed / state.total : 0;
    ringProgress.style.strokeDashoffset = String(
      RING_CIRCUMFERENCE * (1 - fraction)
    );

    // Start button reflects running state
    const isRunning = state.running;
    btnText.textContent = isRunning ? "Pause" : "Start";
    btnIcon.innerHTML = isRunning ? "&#10074;&#10074;" : "&#9654;";

    // Session counter
    sessionCount.textContent = String(state.completedSessions);
    renderSessionDots();
  }

  function renderSessionDots() {
    const count = state.completedSessions;
    const dotsToShow = Math.max(count, 4); // always show at least 4 slots
    let html = "";
    for (let i = 0; i < dotsToShow; i++) {
      html += `<span class="dot${i < count ? " filled" : ""}"></span>`;
    }
    sessionDots.innerHTML = html;
  }

  function setMode(mode) {
    state.mode = mode;
    state.total = mode === "work" ? WORK_SECONDS : BREAK_SECONDS;
    state.remaining = state.total;
    stopTicking();

    // Update body class for break-mode theming
    body.classList.toggle("is-break", mode === "break");

    // Update active tab styling
    modeButtons.forEach((btn) => {
      const isActive = btn.dataset.mode === mode;
      btn.classList.toggle("is-active", isActive);
      btn.setAttribute("aria-selected", String(isActive));
    });

    render();
  }

  // --- Timer engine --------------------------------------------------------
  function startTicking() {
    if (state.intervalId) return;

    // Anchor to wall-clock time for drift-free counting
    state.endTime = Date.now() + state.remaining * 1000;

    state.intervalId = setInterval(() => {
      const remainingMs = state.endTime - Date.now();
      if (remainingMs <= 0) {
        state.remaining = 0;
        render();
        onSessionComplete();
        return;
      }
      state.remaining = Math.ceil(remainingMs / 1000);
      render();
    }, 250);
  }

  function stopTicking() {
    if (state.intervalId) {
      clearInterval(state.intervalId);
      state.intervalId = null;
    }
    state.endTime = null;
  }

  function toggleRunning() {
    if (state.running) {
      // Pause
      state.running = false;
      stopTicking();
    } else {
      // Start (also unlocks audio on first user gesture)
      ensureAudioContext();
      state.running = true;
      startTicking();
    }
    render();
  }

  function resetTimer() {
    state.running = false;
    stopTicking();
    state.remaining = state.total;
    render();
  }

  /**
   * Called when a session's time reaches zero.
   */
  function onSessionComplete() {
    stopTicking();
    state.running = false;
    playChime();

    if (state.mode === "work") {
      // A full work session finished → increment counter, move to break
      state.completedSessions += 1;
      setMode("break");
    } else {
      // Break finished → back to work
      setMode("work");
    }

    // Render happens inside setMode(); ensure final state is shown.
    render();
  }

  // --- Event wiring --------------------------------------------------------
  btnStart.addEventListener("click", toggleRunning);
  btnReset.addEventListener("click", resetTimer);

  modeButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      // Switching modes manually stops the running timer
      if (state.running) {
        state.running = false;
        stopTicking();
      }
      setMode(btn.dataset.mode);
    });
  });

  // Keyboard shortcuts: Space = start/pause, R = reset
  document.addEventListener("keydown", (e) => {
    // Ignore when focus is on a button to avoid double-triggering via Space
    if (e.target.tagName === "BUTTON") return;

    if (e.code === "Space") {
      e.preventDefault();
      toggleRunning();
    } else if (e.key === "r" || e.key === "R") {
      resetTimer();
    }
  });

  // --- Initial render ------------------------------------------------------
  renderSessionDots();
  render();
})();
