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
      saveStreak();
      setMode("break");
      // Trigger viral share modal to celebrate achievement
      setTimeout(() => openShareModal(), 600);
    } else {
      // Break finished → back to work
      setMode("work");
    }

    // Render happens inside setMode(); ensure final state is shown.
    render();
  }

  // --- Ambient Flow Sound Engine -------------------------------------------
  let ambientNoiseNode = null;
  let ambientGainNode = null;
  let isSoundActive = false;

  const btnSound = document.getElementById("btn-sound");
  const soundIcon = document.getElementById("sound-icon");
  const soundText = document.getElementById("sound-text");

  function createAmbientNoise() {
    const ctx = ensureAudioContext();
    if (!ctx) return;

    // Generate 2 seconds of pink/brownian relaxing noise buffer
    const bufferSize = ctx.sampleRate * 2;
    const noiseBuffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    let b0 = 0, b1 = 0, b2 = 0;
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      output[i] = (b0 + b1 + b2) * 0.08;
    }

    const whiteNoise = ctx.createBufferSource();
    whiteNoise.buffer = noiseBuffer;
    whiteNoise.loop = true;

    // Filter to warm deep focus sound
    const filter = ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.setValueAtTime(450, ctx.currentTime);

    ambientGainNode = ctx.createGain();
    ambientGainNode.gain.setValueAtTime(0.001, ctx.currentTime);
    ambientGainNode.gain.exponentialRampToValueAtTime(0.18, ctx.currentTime + 1.5);

    whiteNoise.connect(filter);
    filter.connect(ambientGainNode);
    ambientGainNode.connect(ctx.destination);

    whiteNoise.start();
    ambientNoiseNode = whiteNoise;
  }

  function stopAmbientNoise() {
    if (ambientGainNode && audioCtx) {
      ambientGainNode.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.8);
      setTimeout(() => {
        if (ambientNoiseNode) {
          try { ambientNoiseNode.stop(); } catch (e) {}
          ambientNoiseNode.disconnect();
          ambientNoiseNode = null;
        }
      }, 850);
    }
  }

  function toggleAmbientSound() {
    ensureAudioContext();
    isSoundActive = !isSoundActive;
    if (isSoundActive) {
      createAmbientNoise();
      if (soundIcon) soundIcon.textContent = "🔊";
      if (soundText) soundText.textContent = "Flow";
      btnSound.classList.add("is-active");
    } else {
      stopAmbientNoise();
      if (soundIcon) soundIcon.textContent = "🔇";
      if (soundText) soundText.textContent = "Sound";
      btnSound.classList.remove("is-active");
    }
  }

  if (btnSound) {
    btnSound.addEventListener("click", toggleAmbientSound);
  }

  // --- Streak Persistence & Viral Share Modal ------------------------------
  const STORAGE_KEY = "serene_pomodoro_streak_v1";

  function loadStreak() {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (typeof parsed.completedSessions === "number") {
          state.completedSessions = parsed.completedSessions;
        }
      }
    } catch (e) {
      // LocalStorage fallback
    }
  }

  function saveStreak() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        completedSessions: state.completedSessions,
        lastUpdated: new Date().toISOString()
      }));
    } catch (e) {}
  }

  const shareModal = document.getElementById("share-modal");
  const btnOpenShare = document.getElementById("btn-open-share");
  const btnCloseModal = document.getElementById("btn-close-modal");
  const modalSessionCount = document.getElementById("modal-session-count");
  const modalFocusMinutes = document.getElementById("modal-focus-minutes");
  const streakTag = document.getElementById("streak-tag");
  const btnShareX = document.getElementById("btn-share-x");
  const btnShareLinkedin = document.getElementById("btn-share-linkedin");
  const btnShareWhatsapp = document.getElementById("btn-share-whatsapp");
  const btnCopyStreak = document.getElementById("btn-copy-streak");
  const copyToast = document.getElementById("copy-toast");
  const copyBtnLabel = document.getElementById("copy-btn-label");

  function getLevelTag(sessions) {
    if (sessions >= 10) return "👑 Flow Legend";
    if (sessions >= 6) return "⚡ Deep Work Beast";
    if (sessions >= 4) return "🔥 Focus Champion";
    if (sessions >= 2) return "🎯 In The Zone";
    return "🌱 Getting Started";
  }

  function openShareModal() {
    if (!shareModal) return;
    const sessions = Math.max(state.completedSessions, 1);
    const minutes = sessions * 25;
    const tag = getLevelTag(sessions);

    if (modalSessionCount) modalSessionCount.textContent = String(sessions);
    if (modalFocusMinutes) modalFocusMinutes.textContent = String(minutes);
    if (streakTag) streakTag.textContent = tag;

    // Update social share URLs
    const shareText = `Crushed ${minutes} minutes of deep focus (${sessions} sessions) with Serene Focus & Agentic workflows! 🚀🧘‍♂️\n\nLevel: ${tag}\nBoost your deep work here:`;
    const appUrl = window.location.href.split("#")[0];

    if (btnShareX) {
      btnShareX.href = `https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(appUrl)}&hashtags=DeepWork,Pomodoro,Focus`;
    }
    if (btnShareLinkedin) {
      btnShareLinkedin.href = `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(appUrl)}`;
    }
    if (btnShareWhatsapp) {
      btnShareWhatsapp.href = `https://api.whatsapp.com/send?text=${encodeURIComponent(shareText + " " + appUrl)}`;
    }

    shareModal.classList.add("is-visible");
    shareModal.setAttribute("aria-hidden", "false");
  }

  function closeShareModal() {
    if (!shareModal) return;
    shareModal.classList.remove("is-visible");
    shareModal.setAttribute("aria-hidden", "true");
  }

  if (btnOpenShare) {
    btnOpenShare.addEventListener("click", openShareModal);
  }
  if (btnCloseModal) {
    btnCloseModal.addEventListener("click", closeShareModal);
  }
  if (shareModal) {
    shareModal.addEventListener("click", (e) => {
      if (e.target === shareModal) closeShareModal();
    });
  }

  if (btnCopyStreak) {
    btnCopyStreak.addEventListener("click", () => {
      const sessions = Math.max(state.completedSessions, 1);
      const minutes = sessions * 25;
      const copyText = `🏆 Serene Focus Streak: Completed ${sessions} sessions (${minutes} mins) in Flow State! Try it: ${window.location.href}`;
      
      navigator.clipboard.writeText(copyText).then(() => {
        if (copyToast) {
          copyToast.classList.add("is-visible");
          setTimeout(() => copyToast.classList.remove("is-visible"), 3000);
        }
        if (copyBtnLabel) {
          copyBtnLabel.textContent = "✅ Copied to Clipboard!";
          setTimeout(() => { copyBtnLabel.textContent = "📋 Copy Badge & Link"; }, 2500);
        }
      }).catch(() => {});
    });
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

  // Keyboard shortcuts: Space = start/pause, R = reset, S = share, M = sound
  document.addEventListener("keydown", (e) => {
    // Ignore when focus is on an input or button to avoid conflicts
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;

    if (e.code === "Space") {
      e.preventDefault();
      toggleRunning();
    } else if (e.key === "r" || e.key === "R") {
      resetTimer();
    } else if (e.key === "Escape") {
      closeShareModal();
    }
  });

  // --- Initial load & render -----------------------------------------------
  loadStreak();
  renderSessionDots();
  render();
})();
