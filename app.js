document.addEventListener("DOMContentLoaded", () => {
  // ========= HELPERS =========
  const $ = (id) => document.getElementById(id);
  const on = (el, ev, fn) => el && el.addEventListener(ev, fn);

  function shuffleInPlace(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }
  function shuffledCopy(arr) {
    return shuffleInPlace(arr.slice());
  }
  function clamp(n, min, max) {
    return Math.max(min, Math.min(max, n));
  }

  // ========= PAGE / NAV =========
  const pageHome = $("homePage");
  const pageGames = $("gamesPage");
  const navHomeBtn = $("navHomeBtn");
  const navGamesBtn = $("navGamesBtn");
  const startGamesBtn = $("startGamesBtn");
  const startQuizFromHomeBtn = $("startQuizFromHome");

  const gamesListView = $("gamesListView");
  const gamePlayView = $("gamePlayView");
  const backToListBtn = $("backToListBtn");
  const currentGameLabel = $("currentGameLabel");

  // ========= SCORE GLOBAL =========
  const globalScoreEl = $("globalScore");
  let globalScore = 0;

  // ========= PERSISTENCE (localStorage) =========
  const STORAGE_KEY = "pl_minigames_state_v1";
  let isRestoring = false;


  let currentGameKey = null;

  let quizChosenIndex = null;
  let quizTimedOut = false;
  let quizEndsAt = null;


  let diagChosenIndex = null;

  function updateGlobalScore(points) {
    globalScore += points;
    if (globalScoreEl) globalScoreEl.textContent = String(globalScore);
    saveState();
  }

  function showPage(name) {
    if (!pageHome || !pageGames) return;

    if (name === "home") {
      pageHome.classList.add("active");
      pageGames.classList.remove("active");
      navHomeBtn && navHomeBtn.classList.add("active");
      navGamesBtn && navGamesBtn.classList.remove("active");
    } else {
      pageHome.classList.remove("active");
      pageGames.classList.add("active");
      navHomeBtn && navHomeBtn.classList.remove("active");
      navGamesBtn && navGamesBtn.classList.add("active");
    }

    saveState();
  }

  // ========= MINI-JEUX : ROUTAGE INTERNE =========
  const gameQuizEl = $("game-quiz");
  const gameDiagEl = $("game-diagnostic");
  const gameMemImgEl = $("game-memory-images");

  const gameMap = {
    quiz: gameQuizEl,
    diagnostic: gameDiagEl,
    memoryImages: gameMemImgEl,
  };

  const gameLabels = {
    quiz: "⚡ Quiz Mécano Expert",
    diagnostic: "🧠 Diagnostic avancé",
    memoryImages: "🖼️ Mémo Images",
  };

  function hideAllGames() {
    Object.values(gameMap).forEach((el) => {
      if (el) el.style.display = "none";
    });
  }

  function showGamesList() {
    currentGameKey = null;
    if (gamePlayView) gamePlayView.style.display = "none";
    if (gamesListView) gamesListView.style.display = "block";
    hideAllGames();
    if (currentGameLabel) currentGameLabel.textContent = "";
    saveState();
  }

  function openGame(key) {

    if (!gameMap[key]) {
      showPage("games");
      showGamesList();
      return;
    }

    currentGameKey = key;
    showPage("games");
    if (gamesListView) gamesListView.style.display = "none";
    if (gamePlayView) gamePlayView.style.display = "block";
    hideAllGames();
    gameMap[key].style.display = "block";
    if (currentGameLabel) currentGameLabel.textContent = gameLabels[key] || "";
    saveState();
  }

  // ========= NAV EVENTS =========
  on(navHomeBtn, "click", () => showPage("home"));
  on(navGamesBtn, "click", () => {
    showPage("games");
    showGamesList();
  });
  on(startGamesBtn, "click", () => {
    showPage("games");
    showGamesList();
  });
  on(backToListBtn, "click", showGamesList);

  document.querySelectorAll("[data-open-game]").forEach((btn) => {
    on(btn, "click", () => {
      const key = btn.getAttribute("data-open-game");
      openGame(key);
    });
  });

  on(startQuizFromHomeBtn, "click", () => openGame("quiz"));

  // ========= BOUTON RESET GLOBAL =========
  const resetAllBtn = $("resetAllBtn");
  on(resetAllBtn, "click", () => {
    if (!confirm("Réinitialiser tous les scores et remettre les jeux à zéro ?")) return;

    globalScore = 0;
    if (globalScoreEl) globalScoreEl.textContent = "0";

    resetQuiz(true);
    resetDiagnostic(true);
    resetMemoryImages(true);

    localStorage.removeItem(STORAGE_KEY);
    alert("Tous les jeux et scores ont été remis à zéro.");
    saveState();
  });

  // ============================================================
  // ====================== JEU 1 : QUIZ =========================
  // ============================================================

  // Base (non randomisée)
  const baseQuizData = [
    {
      question:
        "Situation : Un camion a beaucoup de mal à démarrer à froid. À chaud, le moteur démarre normalement.\u00A0Quelle est la cause la plus probable ?",
      choices: ["Batterie trop puissante", "Injecteurs trop propres", "Bougies de préchauffage défectueuses", "Filtre à air neuf"],
      correctIndex: 2,
      explanation:
        "Les bougies de préchauffage chauffent la chambre de combustion à froid. Si elles sont HS, le démarrage devient difficile uniquement à froid.",
    },
    {
      question:
        "Situation : Le camion démarre, mais cale lors des accélérations ou en montée. \u00A0Quelle panne est la plus probable ?",
      choices: ["Filtre à carburant colmaté", "Pression des pneus trop basse", "Niveau d’huile trop élevé", "Alternateur neuf"],
      correctIndex: 0,
      explanation: "Un filtre bouché limite l’arrivée de carburant, surtout quand le moteur demande plus de débit.",
    },
    {
      question:
        "Situation : Le moteur chauffe rapidement et le voyant température s’allume, même sur de courts trajets. \u00A0Quelle est la cause la plus logique ?",
      choices: ["Batterie faible", "Thermostat bloqué fermé", "Capteur ABS défectueux", "Filtre à gasoil encrassé"],
      correctIndex: 1,
      explanation: "Un thermostat bloqué empêche le liquide de refroidissement de circuler vers le radiateur.",
    },
    {
      question:
        "Situation : La pression d’air monte très lentement et un sifflement constant est audible. \u00A0Quelle est la panne la plus probable ?",
      choices: ["Plaquettes de frein usées", "Compresseur trop puissant", "Fuite sur le circuit d’air", "Liquide de frein trop ancien"],
      correctIndex: 2,
      explanation: "Une fuite empêche la pression de monter normalement et provoque un bruit d’échappement d’air.",
    },
    {
      question:
        "Situation : Le moteur cale à chaud et redémarre seulement après refroidissement. \u00A0Quel élément est souvent en cause ?",
      choices: ["Filtre à air propre", "Capteur PMH (vilebrequin) défectueux", "Réservoir trop plein", "Silencieux d’échappement percé"],
      correctIndex: 1,
      explanation: "Le capteur PMH peut tomber en panne à chaud et empêcher le calculateur de connaître le régime moteur.",
    },
  ];


  let quizDeck = [];

  function buildQuizDeck() {

    const qShuffled = shuffledCopy(baseQuizData);


    return qShuffled.map((q) => {
      const items = q.choices.map((text, originalIndex) => ({ text, originalIndex }));
      shuffleInPlace(items);
      const newChoices = items.map((x) => x.text);
      const newCorrectIndex = items.findIndex((x) => x.originalIndex === q.correctIndex);

      return {
        question: q.question,
        choices: newChoices,
        correctIndex: newCorrectIndex,
        explanation: q.explanation,
      };
    });
  }

  let quizIndex = 0;
  let quizScore = 0;
  let quizTimer = null;
  let quizTimeLeft = 40;
  let quizAnswered = false;

  const quizTimerEl = $("quizTimer");
  const quizScoreEl = $("quizScore");
  const quizScoreInlineEl = $("quizScoreInline");
  const quizQuestionIndexEl = $("quizQuestionIndex");
  const quizTotalEl = $("quizTotal");
  const quizQuestionTextEl = $("quizQuestionText");
  const quizChoicesEl = $("quizChoices");
  const quizFeedbackEl = $("quizFeedback");
  const quizNextBtn = $("quizNextBtn");
  const quizIntroEl = $("quizIntro");
  const quizPlayEl = $("quizPlay");
  const quizResultEl = $("quizResult");
  const quizResultTextEl = $("quizResultText");
  const quizStartBtn = $("quizStartBtn");
  const quizRestartBtn = $("quizRestartBtn");

  function syncQuizTotal() {
    if (quizTotalEl) quizTotalEl.textContent = String(quizDeck.length || baseQuizData.length);
  }


  syncQuizTotal();

  function startQuiz() {
    quizDeck = buildQuizDeck();
    syncQuizTotal();

    quizIndex = 0;
    quizScore = 0;
    quizAnswered = false;
    quizChosenIndex = null;
    quizTimedOut = false;
    quizEndsAt = null;

    quizScoreEl && (quizScoreEl.textContent = "0");
    quizScoreInlineEl && (quizScoreInlineEl.textContent = "0");

    quizIntroEl && (quizIntroEl.style.display = "none");
    quizResultEl && (quizResultEl.style.display = "none");
    quizPlayEl && (quizPlayEl.style.display = "block");
    quizRestartBtn && (quizRestartBtn.style.display = "none");

    loadQuizQuestion();
    saveState();
  }

  function resetQuiz(skipAlert) {
    clearInterval(quizTimer);
    quizTimer = null;

    quizIndex = 0;
    quizScore = 0;
    quizAnswered = false;
    quizChosenIndex = null;
    quizTimedOut = false;
    quizEndsAt = null;

    quizTimerEl && (quizTimerEl.textContent = "–");
    quizScoreEl && (quizScoreEl.textContent = "0");
    quizScoreInlineEl && (quizScoreInlineEl.textContent = "0");

    quizIntroEl && (quizIntroEl.style.display = "block");
    quizPlayEl && (quizPlayEl.style.display = "none");
    quizResultEl && (quizResultEl.style.display = "none");
    quizRestartBtn && (quizRestartBtn.style.display = "none");

    if (quizFeedbackEl) {
      quizFeedbackEl.textContent = "";
      quizFeedbackEl.classList.remove("error", "success");
    }
    quizNextBtn && (quizNextBtn.disabled = true);

    saveState();
    if (!skipAlert) alert("Le quiz a été remis à zéro.");
  }

  function getCurrentQuizItem() {
    const deck = quizDeck.length ? quizDeck : baseQuizData;
    return deck[quizIndex];
  }

  function renderQuizQuestionOnly() {
    const current = getCurrentQuizItem();
    if (!current) return;

    quizQuestionIndexEl && (quizQuestionIndexEl.textContent = String(quizIndex + 1));
    quizQuestionTextEl && (quizQuestionTextEl.textContent = current.question);
    quizQuestionTextEl && (quizQuestionTextEl.textContent = current.question.replaceAll("&nbsp;", "\u00A0"));


    if (!quizChoicesEl) return;
    quizChoicesEl.innerHTML = "";
    current.choices.forEach((choice, idx) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "choice-btn";
      btn.textContent = choice;
      btn.addEventListener("click", () => selectQuizChoice(idx));
      quizChoicesEl.appendChild(btn);
    });
  }

  function loadQuizQuestion() {
    clearInterval(quizTimer);

    quizAnswered = false;
    quizTimedOut = false;
    quizChosenIndex = null;

    quizNextBtn && (quizNextBtn.disabled = true);
    if (quizFeedbackEl) {
      quizFeedbackEl.textContent = "";
      quizFeedbackEl.classList.remove("error", "success");
    }

    quizEndsAt = Date.now() + 40 * 1000;

    renderQuizQuestionOnly();
    saveState();

    quizTimer = setInterval(() => {
      const left = Math.max(0, Math.ceil((quizEndsAt - Date.now()) / 1000));
      quizTimeLeft = left;
      quizTimerEl && (quizTimerEl.textContent = left + " s");

      if (left <= 0) {
        clearInterval(quizTimer);
        if (!quizAnswered) {
          quizAnswered = true;
          quizTimedOut = true;

          if (quizFeedbackEl) {
            quizFeedbackEl.textContent = "⏱️ Temps écoulé. La bonne réponse apparaît en vert.";
            quizFeedbackEl.classList.remove("success");
            quizFeedbackEl.classList.add("error");
          }

          markQuizCorrectAnswerOnly();
          quizNextBtn && (quizNextBtn.disabled = false);

          saveState();
        }
      }
    }, 250);
  }

  function markQuizCorrectAnswerOnly() {
    const current = getCurrentQuizItem();
    if (!quizChoicesEl || !current) return;

    const buttons = quizChoicesEl.querySelectorAll(".choice-btn");
    buttons.forEach((btn, idx) => {
      btn.classList.add("disabled");
      if (idx === current.correctIndex) btn.classList.add("correct");
    });
  }

  function selectQuizChoice(idx) {
    if (quizAnswered) return;

    quizChosenIndex = idx;
    quizTimedOut = false;

    quizAnswered = true;
    clearInterval(quizTimer);

    const current = getCurrentQuizItem();
    const buttons = quizChoicesEl ? quizChoicesEl.querySelectorAll(".choice-btn") : [];
    buttons.forEach((btn, bIdx) => {
      btn.classList.add("disabled");
      if (bIdx === current.correctIndex) btn.classList.add("correct");
      else if (bIdx === idx && bIdx !== current.correctIndex) btn.classList.add("wrong");
    });

    if (idx === current.correctIndex) {
      quizScore += 15;
      quizScoreEl && (quizScoreEl.textContent = String(quizScore));
      quizScoreInlineEl && (quizScoreInlineEl.textContent = String(quizScore));
      if (quizFeedbackEl) {
        quizFeedbackEl.textContent = "✅ Bonne réponse ! " + current.explanation;
        quizFeedbackEl.classList.remove("error");
        quizFeedbackEl.classList.add("success");
      }
    } else {
      if (quizFeedbackEl) {
        quizFeedbackEl.textContent = "❌ Mauvaise réponse. " + current.explanation;
        quizFeedbackEl.classList.remove("success");
        quizFeedbackEl.classList.add("error");
      }
    }

    quizNextBtn && (quizNextBtn.disabled = false);
    saveState();
  }

  function nextQuizQuestion() {
    if (!quizAnswered) return;

    const deckLen = (quizDeck.length ? quizDeck.length : baseQuizData.length);
    quizIndex++;
    if (quizIndex >= deckLen) endQuiz();
    else loadQuizQuestion();

    saveState();
  }

  function endQuiz() {
    clearInterval(quizTimer);

    quizPlayEl && (quizPlayEl.style.display = "none");
    quizResultEl && (quizResultEl.style.display = "block");
    quizRestartBtn && (quizRestartBtn.style.display = "inline-flex");

    const deckLen = (quizDeck.length ? quizDeck.length : baseQuizData.length);
    const maxScore = deckLen * 15;

    quizResultTextEl &&
      (quizResultTextEl.innerHTML = `Tu as obtenu <strong>${quizScore}</strong> / ${maxScore} points sur ce quiz.`);

    if (quizScore > 0) updateGlobalScore(quizScore);

    saveState();
  }

  on(quizStartBtn, "click", startQuiz);
  on(quizRestartBtn, "click", () => {
    startQuiz();
    saveState();
  });
  on(quizNextBtn, "click", nextQuizQuestion);

  // ============================================================
  // ================== JEU 2 : DIAGNOSTIC ======================
  // ============================================================

  // Base (non randomisée)
  const baseDiagData = [
    {
      symptom:
        "1) Le moteur&nbsp;Définition : Partie du véhicule qui transforme le carburant en énergie pour faire avancer le camion.&nbsp;Quelle est la bonne réponse ?",
      choices: ["A. Boîte de vitesses", "B. Moteur", "C. Tableau de bord", "D. Radiateur", "E. Réservoir"],
      correctIndex: 1,
      explanation: "Le moteur transforme le carburant en énergie mécanique pour faire avancer le camion.",
    },
    {
      symptom:
        "2) Le pont différentiel&nbsp;Définition : Mécanisme qui permet aux roues d’un même essieu de tourner à des vitesses différentes, surtout dans les virages.&nbsp;Quelle est la bonne réponse ?",
      choices: ["A. Amortisseur", "B. Pont différentiel", "C. Volant", "D. Alternateur", "E. Châssis"],
      correctIndex: 1,
      explanation: "Le pont différentiel permet aux roues d’un même essieu de tourner à des vitesses différentes en virage.",
    },
    {
      symptom:
        "3) L'essieu&nbsp;Définition : Ensemble sur lequel sont montées les roues du camion.&nbsp;Quelle est la bonne réponse ?",
      choices: ["A. Essieu", "B. Filtre à air", "C. Pare-brise", "D. Batterie", "E. Échappement"],
      correctIndex: 0,
      explanation: "L’essieu est l’ensemble mécanique qui supporte et porte les roues.",
    },
    {
      symptom:
        "4) Les roues&nbsp;Définition : Éléments circulaires qui permettent le contact avec la route et le déplacement du camion.&nbsp;Quelle est la bonne réponse ?",
      choices: ["A. Pneumatiques / roues", "B. Siège conducteur", "C. Rétroviseurs", "D. Embrayage", "E. Ventilateur moteur"],
      correctIndex: 0,
      explanation: "Les pneumatiques/roues assurent le contact avec la route et permettent le déplacement.",
    },
    {
      symptom:
        "5) La boîte de vitesses&nbsp;Définition : Ensemble mécanique qui permet de changer la vitesse et le couple transmis du moteur aux roues.&nbsp;Quelle est la bonne réponse ?",
      choices: ["A. Boîte de vitesses", "B. Klaxon", "C. Filtre à huile", "D. Pare-chocs", "E. Direction assistée"],
      correctIndex: 0,
      explanation: "La boîte de vitesses sert à adapter la vitesse et le couple transmis aux roues.",
    },
    {
      symptom:
        "6) Le radiateur&nbsp;Définition : Élément du système de refroidissement qui permet d’évacuer la chaleur du moteur.&nbsp;Quelle est la bonne réponse ?",
      choices: ["A. Radiateur", "B. Rétroviseur", "C. Silencieux d’échappement", "D. Filtre à carburant", "E. Siège passager"],
      correctIndex: 0,
      explanation: "Le radiateur évacue la chaleur du moteur en refroidissant le liquide de refroidissement.",
    },
  ];

  let diagDeck = [];

  function buildDiagDeck() {
    const dShuffled = shuffledCopy(baseDiagData);

    return dShuffled.map((d) => {
      const items = d.choices.map((text, originalIndex) => ({ text, originalIndex }));
      shuffleInPlace(items);
      const newChoices = items.map((x) => x.text);
      const newCorrectIndex = items.findIndex((x) => x.originalIndex === d.correctIndex);

      return {
        symptom: d.symptom,
        choices: newChoices,
        correctIndex: newCorrectIndex,
        explanation: d.explanation,
      };
    });
  }

  let diagIndex = 0;
  let diagScore = 0;
  let diagAnswered = false;

  const diagScoreEl = $("diagScore");
  const diagScoreInlineEl = $("diagScoreInline");
  const diagIndexEl = $("diagIndex");
  const diagTotalEl = $("diagTotal");
  const diagSymptomEl = $("diagSymptom");
  const diagChoicesEl = $("diagChoices");
  const diagFeedbackEl = $("diagFeedback");
  const diagNextBtn = $("diagNextBtn");
  const diagIntroEl = $("diagIntro");
  const diagPlayEl = $("diagPlay");
  const diagResultEl = $("diagResult");
  const diagResultTextEl = $("diagResultText");
  const diagStartBtn = $("diagStartBtn");

  function syncDiagTotal() {
    if (diagTotalEl) diagTotalEl.textContent = String(diagDeck.length || baseDiagData.length);
  }
  syncDiagTotal();

  function getCurrentDiagItem() {
    const deck = diagDeck.length ? diagDeck : baseDiagData;
    return deck[diagIndex];
  }

  function startDiagnostic() {
    diagDeck = buildDiagDeck();
    syncDiagTotal();

    diagIndex = 0;
    diagScore = 0;
    diagAnswered = false;
    diagChosenIndex = null;

    diagScoreEl && (diagScoreEl.textContent = "0");
    diagScoreInlineEl && (diagScoreInlineEl.textContent = "0");

    diagIntroEl && (diagIntroEl.style.display = "none");
    diagResultEl && (diagResultEl.style.display = "none");
    diagPlayEl && (diagPlayEl.style.display = "block");

    loadDiagCase();
    saveState();
  }

  function resetDiagnostic(skipAlert) {
    diagIndex = 0;
    diagScore = 0;
    diagAnswered = false;
    diagChosenIndex = null;

    diagScoreEl && (diagScoreEl.textContent = "0");
    diagScoreInlineEl && (diagScoreInlineEl.textContent = "0");

    diagIntroEl && (diagIntroEl.style.display = "block");
    diagPlayEl && (diagPlayEl.style.display = "none");
    diagResultEl && (diagResultEl.style.display = "none");

    if (diagFeedbackEl) {
      diagFeedbackEl.textContent = "";
      diagFeedbackEl.classList.remove("error", "success");
    }
    diagNextBtn && (diagNextBtn.disabled = true);

    saveState();
    if (!skipAlert) alert("Le jeu de diagnostic a été remis à zéro.");
  }

  function loadDiagCase() {
    diagAnswered = false;
    diagChosenIndex = null;

    diagNextBtn && (diagNextBtn.disabled = true);
    if (diagFeedbackEl) {
      diagFeedbackEl.textContent = "";
      diagFeedbackEl.classList.remove("error", "success");
    }

    const current = getCurrentDiagItem();
    if (!current) return;

    diagIndexEl && (diagIndexEl.textContent = String(diagIndex + 1));
    diagSymptomEl && (diagSymptomEl.textContent = current.symptom);

    if (!diagChoicesEl) return;
    diagChoicesEl.innerHTML = "";
    current.choices.forEach((choice, idx) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "choice-btn";
      btn.textContent = choice;
      btn.addEventListener("click", () => selectDiagChoice(idx));
      diagChoicesEl.appendChild(btn);
    });

    saveState();
  }

  function selectDiagChoice(idx) {
    if (diagAnswered) return;
    diagAnswered = true;
    diagChosenIndex = idx;

    const current = getCurrentDiagItem();
    const buttons = diagChoicesEl ? diagChoicesEl.querySelectorAll(".choice-btn") : [];
    buttons.forEach((btn, bIdx) => {
      btn.classList.add("disabled");
      if (bIdx === current.correctIndex) btn.classList.add("correct");
      else if (bIdx === idx && bIdx !== current.correctIndex) btn.classList.add("wrong");
    });

    if (idx === current.correctIndex) {
      diagScore += 15;
      diagScoreEl && (diagScoreEl.textContent = String(diagScore));
      diagScoreInlineEl && (diagScoreInlineEl.textContent = String(diagScore));
      if (diagFeedbackEl) {
        diagFeedbackEl.textContent = "✅ Bonne réponse. " + current.explanation;
        diagFeedbackEl.classList.remove("error");
        diagFeedbackEl.classList.add("success");
      }
    } else {
      if (diagFeedbackEl) {
        diagFeedbackEl.textContent = "❌ Mauvaise réponse. " + current.explanation;
        diagFeedbackEl.classList.remove("success");
        diagFeedbackEl.classList.add("error");
      }
    }

    diagNextBtn && (diagNextBtn.disabled = false);
    saveState();
  }

  function nextDiagCase() {
    if (!diagAnswered) return;

    const deckLen = (diagDeck.length ? diagDeck.length : baseDiagData.length);
    diagIndex++;
    if (diagIndex >= deckLen) endDiagnostic();
    else loadDiagCase();

    saveState();
  }

  function endDiagnostic() {
    diagPlayEl && (diagPlayEl.style.display = "none");
    diagResultEl && (diagResultEl.style.display = "block");

    const deckLen = (diagDeck.length ? diagDeck.length : baseDiagData.length);
    const maxScore = deckLen * 15;

    diagResultTextEl &&
      (diagResultTextEl.innerHTML = `Tu as obtenu <strong>${diagScore}</strong> / ${maxScore} points sur ce jeu.`);

    if (diagScore > 0) updateGlobalScore(diagScore);
    saveState();
  }

  on(diagStartBtn, "click", startDiagnostic);
  on(diagNextBtn, "click", nextDiagCase);

  // ============================================================
  // ============ JEU 3 : MÉMO IMAGES (TRIPLETS) =================
  // ============================================================

  const memoryImgPairsData = [
    { id: "i1", label: "image1", src: "assets/image1.jpg" },
    { id: "i2", label: "image2", src: "assets/image2.jpg" },
    { id: "i3", label: "image3", src: "assets/image3.jpg" },
    { id: "i4", label: "image4", src: "assets/image4.png" },
    { id: "i5", label: "image5", src: "assets/image5.jpg" },
  ];

  const memoryImgScoreEl = $("memoryImgScore");
  const memoryImgStartBtn = $("memoryImgStartBtn");
  const memoryImgRestartBtn = $("memoryImgRestartBtn");
  const memoryImgBoardCard = $("memoryImgBoardCard");
  const memoryImgGridEl = $("memoryImgGrid");
  const memoryImgMovesEl = $("memoryImgMoves");
  const memoryImgFoundEl = $("memoryImgFound");
  const memoryImgTotalPairsEl = $("memoryImgTotalPairs");
  const memoryImgMessageEl = $("memoryImgMessage");

  let memImgMoves = 0;
  let memImgFound = 0;
  let memImgCards = [];
  let memImgLock = false;
  let memImgScore = 0;
  let memImgSelected = [];

  if (memoryImgTotalPairsEl) memoryImgTotalPairsEl.textContent = String(memoryImgPairsData.length);

  function buildMemoryImgDeck() {
    const deck = [];
    memoryImgPairsData.forEach((pair) => {
      for (let k = 0; k < 3; k++) deck.push({ id: pair.id, src: pair.src, label: pair.label });
    });
    return shuffleInPlace(deck); 
  }

  function renderMemoryImagesBoard(deck) {
    memImgCards = Array.isArray(deck) ? deck : [];
    if (!memoryImgGridEl) return;

    memoryImgGridEl.innerHTML = "";

    memImgCards.forEach((card, idx) => {
      const cardEl = document.createElement("div");
      cardEl.className = "memory-card memory-img-card";
      cardEl.dataset.pairId = card.id;
      cardEl.dataset.cardIndex = String(idx);

      const inner = document.createElement("div");
      inner.className = "memory-card-inner";

      const back = document.createElement("div");
      back.className = "memory-face memory-back";

      const backIcon = document.createElement("div");
      backIcon.className = "memory-back-icon";
      backIcon.textContent = "🖼️";
      const backText = document.createElement("div");
      backText.textContent = "Carte image";
      back.appendChild(backIcon);
      back.appendChild(backText);

      const front = document.createElement("div");
      front.className = "memory-face memory-front";
      const img = document.createElement("img");
      img.className = "memory-img";
      img.src = card.src;
      img.alt = card.label;
      front.appendChild(img);

      inner.appendChild(back);
      inner.appendChild(front);
      cardEl.appendChild(inner);

      cardEl.addEventListener("click", () => onMemoryImgCardClick(cardEl));
      memoryImgGridEl.appendChild(cardEl);
    });
  }

  function startMemoryImages() {
    memImgSelected = [];
    memImgScore = 0;
    memImgMoves = 0;
    memImgFound = 0;
    memImgLock = false;

    memoryImgScoreEl && (memoryImgScoreEl.textContent = "0");
    memoryImgMovesEl && (memoryImgMovesEl.textContent = "0");
    memoryImgFoundEl && (memoryImgFoundEl.textContent = "0");

    if (memoryImgMessageEl) {
      memoryImgMessageEl.textContent = "";
      memoryImgMessageEl.className = "alert";
    }

    memoryImgBoardCard && (memoryImgBoardCard.style.display = "block");
    memoryImgRestartBtn && (memoryImgRestartBtn.style.display = "inline-flex");

    renderMemoryImagesBoard(buildMemoryImgDeck());
    saveState();
  }

  function resetMemoryImages(skipAlert) {
    memImgScore = 0;
    memImgMoves = 0;
    memImgFound = 0;
    memImgLock = false;
    memImgCards = [];
    memImgSelected = [];

    memoryImgScoreEl && (memoryImgScoreEl.textContent = "0");
    memoryImgMovesEl && (memoryImgMovesEl.textContent = "0");
    memoryImgFoundEl && (memoryImgFoundEl.textContent = "0");

    if (memoryImgGridEl) memoryImgGridEl.innerHTML = "";
    memoryImgBoardCard && (memoryImgBoardCard.style.display = "none");
    memoryImgRestartBtn && (memoryImgRestartBtn.style.display = "none");

    if (memoryImgMessageEl) {
      memoryImgMessageEl.textContent = "";
      memoryImgMessageEl.className = "alert";
    }

    saveState();
    if (!skipAlert) alert("Le Mémo Images a été remis à zéro.");
  }

  function onMemoryImgCardClick(cardEl) {
    if (memImgLock) return;
    if (cardEl.classList.contains("matched")) return;
    if (cardEl.classList.contains("revealed")) return;

    cardEl.classList.add("revealed");
    memImgSelected.push(cardEl);
    saveState();

    if (memImgSelected.length < 3) return;

    memImgLock = true;
    memImgMoves++;
    memoryImgMovesEl && (memoryImgMovesEl.textContent = String(memImgMoves));

    const [a, b, c] = memImgSelected;
    const isTriplet = a.dataset.pairId === b.dataset.pairId && a.dataset.pairId === c.dataset.pairId;

    if (isTriplet) {
      setTimeout(() => {
        memImgSelected.forEach((el) => el.classList.add("matched"));

        memImgFound++; 
        memoryImgFoundEl && (memoryImgFoundEl.textContent = String(memImgFound));

        memImgScore += 12;
        memoryImgScoreEl && (memoryImgScoreEl.textContent = String(memImgScore));

        if (memoryImgMessageEl) {
          memoryImgMessageEl.textContent = "✅ Triplet trouvé !";
          memoryImgMessageEl.classList.remove("error");
          memoryImgMessageEl.classList.add("success");
        }

        memImgSelected = [];
        memImgLock = false;

        if (memImgFound === memoryImgPairsData.length) {
          if (memoryImgMessageEl) {
            memoryImgMessageEl.textContent = "🎉 Tous les triplets sont trouvés ! +20 points ajoutés au score global.";
          }
          updateGlobalScore(20);
        }

        saveState();
      }, 450);
    } else {
      setTimeout(() => {
        memImgSelected.forEach((el) => el.classList.remove("revealed"));

        if (memoryImgMessageEl) {
          memoryImgMessageEl.textContent = "❌ Mauvais triplet. Observe bien les détails des pièces.";
          memoryImgMessageEl.classList.remove("success");
          memoryImgMessageEl.classList.add("error");
        }

        memImgSelected = [];
        memImgLock = false;

        saveState();
      }, 750);
    }
  }

  on(memoryImgStartBtn, "click", startMemoryImages);
  on(memoryImgRestartBtn, "click", startMemoryImages);

  // ========= PERSISTENCE UTILS =========
  function getCardIndices(gridEl, className) {
    if (!gridEl) return [];
    const cards = Array.from(gridEl.querySelectorAll(".memory-card"));
    const out = [];
    cards.forEach((c) => {
      if (c.classList.contains(className)) out.push(Number(c.dataset.cardIndex));
    });
    return out.filter((n) => Number.isFinite(n));
  }

  function applyIndices(gridEl, indices, className) {
    if (!gridEl || !Array.isArray(indices)) return;
    const cards = Array.from(gridEl.querySelectorAll(".memory-card"));
    indices.forEach((i) => {
      const el = cards.find((c) => Number(c.dataset.cardIndex) === i);
      if (el) el.classList.add(className);
    });
  }

  function saveState() {
    if (isRestoring) return;

    const quizStage =
      quizResultEl && quizResultEl.style.display === "block"
        ? "result"
        : quizPlayEl && quizPlayEl.style.display === "block"
        ? "play"
        : "intro";

    const diagStage =
      diagResultEl && diagResultEl.style.display === "block"
        ? "result"
        : diagPlayEl && diagPlayEl.style.display === "block"
        ? "play"
        : "intro";

    const state = {
      view: {
        page: pageHome && pageHome.classList.contains("active") ? "home" : "games",
        gamesMode: gamePlayView && gamePlayView.style.display === "block" ? "play" : "list",
        currentGameKey,
      },
      globalScore,

      quiz: {
        stage: quizStage,
        deck: quizDeck,
        index: quizIndex,
        score: quizScore,
        answered: quizAnswered,
        chosenIndex: quizChosenIndex,
        timedOut: quizTimedOut,
        endsAt: quizEndsAt,
      },

      diag: {
        stage: diagStage,
        deck: diagDeck,
        index: diagIndex,
        score: diagScore,
        answered: diagAnswered,
        chosenIndex: diagChosenIndex,
      },

      memImg: {
        boardVisible: !!(memoryImgBoardCard && memoryImgBoardCard.style.display === "block"),
        deck: memImgCards,
        moves: memImgMoves,
        found: memImgFound,
        score: memImgScore,
        matchedIdx: getCardIndices(memoryImgGridEl, "matched"),
        revealedIdx: getCardIndices(memoryImgGridEl, "revealed"),
        selectedIdx: memImgSelected.map((el) => Number(el.dataset.cardIndex)).filter((n) => Number.isFinite(n)),
      },
    };

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {}
  }

  function restoreState() {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;

    let state;
    try {
      state = JSON.parse(raw);
    } catch {
      return;
    }

    isRestoring = true;


    globalScore = Number(state.globalScore || 0);
    globalScoreEl && (globalScoreEl.textContent = String(globalScore));


    const page = state.view?.page || "home";
    const gamesMode = state.view?.gamesMode || "list";
    currentGameKey = state.view?.currentGameKey || null;

    if (page === "home") {
      showPage("home");
    } else {
      showPage("games");
      if (gamesMode === "play" && currentGameKey) openGame(currentGameKey);
      else showGamesList();
    }

    // ===== QUIZ restore =====
    if (state.quiz) {
      quizDeck = Array.isArray(state.quiz.deck) ? state.quiz.deck : [];
      syncQuizTotal();

      const deckLen = (quizDeck.length ? quizDeck.length : baseQuizData.length);
      quizIndex = clamp(Number(state.quiz.index ?? 0), 0, Math.max(0, deckLen - 1));
      quizScore = Number(state.quiz.score ?? 0);
      quizAnswered = !!state.quiz.answered;
      quizChosenIndex = state.quiz.chosenIndex ?? null;
      quizTimedOut = !!state.quiz.timedOut;
      quizEndsAt = state.quiz.endsAt ?? null;

      quizScoreEl && (quizScoreEl.textContent = String(quizScore));
      quizScoreInlineEl && (quizScoreInlineEl.textContent = String(quizScore));

      const stage = state.quiz.stage || "intro";

      if (stage === "intro") {
        quizIntroEl && (quizIntroEl.style.display = "block");
        quizPlayEl && (quizPlayEl.style.display = "none");
        quizResultEl && (quizResultEl.style.display = "none");
        quizRestartBtn && (quizRestartBtn.style.display = "none");
      }

      if (stage === "result") {
        clearInterval(quizTimer);
        quizIntroEl && (quizIntroEl.style.display = "none");
        quizPlayEl && (quizPlayEl.style.display = "none");
        quizResultEl && (quizResultEl.style.display = "block");
        quizRestartBtn && (quizRestartBtn.style.display = "inline-flex");

        const maxScore = deckLen * 15;
        quizResultTextEl &&
          (quizResultTextEl.innerHTML = `Tu as obtenu <strong>${quizScore}</strong> / ${maxScore} points sur ce quiz.`);
      }

      if (stage === "play") {
        quizIntroEl && (quizIntroEl.style.display = "none");
        quizResultEl && (quizResultEl.style.display = "none");
        quizPlayEl && (quizPlayEl.style.display = "block");
        quizRestartBtn && (quizRestartBtn.style.display = "none");

        renderQuizQuestionOnly();

        if (quizAnswered) {
          const current = getCurrentQuizItem();
          const buttons = quizChoicesEl ? quizChoicesEl.querySelectorAll(".choice-btn") : [];
          buttons.forEach((btn, bIdx) => {
            btn.classList.add("disabled");
            if (bIdx === current.correctIndex) btn.classList.add("correct");
            else if (quizChosenIndex !== null && bIdx === quizChosenIndex) btn.classList.add("wrong");
          });
          quizNextBtn && (quizNextBtn.disabled = false);
          quizTimerEl && (quizTimerEl.textContent = "–");
        } else {
          clearInterval(quizTimer);

          if (quizEndsAt && quizEndsAt > Date.now()) {
            quizTimer = setInterval(() => {
              const left = Math.max(0, Math.ceil((quizEndsAt - Date.now()) / 1000));
              quizTimeLeft = left;
              quizTimerEl && (quizTimerEl.textContent = left + " s");

              if (left <= 0) {
                clearInterval(quizTimer);
                if (!quizAnswered) {
                  quizAnswered = true;
                  quizTimedOut = true;
                  if (quizFeedbackEl) {
                    quizFeedbackEl.textContent = "⏱️ Temps écoulé. La bonne réponse apparaît en vert.";
                    quizFeedbackEl.classList.add("error");
                  }
                  markQuizCorrectAnswerOnly();
                  quizNextBtn && (quizNextBtn.disabled = false);
                }
                saveState();
              }
            }, 250);
          } else {
            quizAnswered = true;
            quizTimedOut = true;
            quizTimerEl && (quizTimerEl.textContent = "0 s");
            if (quizFeedbackEl) {
              quizFeedbackEl.textContent = "⏱️ Temps écoulé. La bonne réponse apparaît en vert.";
              quizFeedbackEl.classList.add("error");
            }
            markQuizCorrectAnswerOnly();
            quizNextBtn && (quizNextBtn.disabled = false);
          }
        }
      }
    }

    // ===== DIAG restore =====
    if (state.diag) {
      diagDeck = Array.isArray(state.diag.deck) ? state.diag.deck : [];
      syncDiagTotal();

      const deckLen = (diagDeck.length ? diagDeck.length : baseDiagData.length);
      diagIndex = clamp(Number(state.diag.index ?? 0), 0, Math.max(0, deckLen - 1));
      diagScore = Number(state.diag.score ?? 0);
      diagAnswered = !!state.diag.answered;
      diagChosenIndex = state.diag.chosenIndex ?? null;

      diagScoreEl && (diagScoreEl.textContent = String(diagScore));
      diagScoreInlineEl && (diagScoreInlineEl.textContent = String(diagScore));

      const stage = state.diag.stage || "intro";

      if (stage === "intro") {
        diagIntroEl && (diagIntroEl.style.display = "block");
        diagPlayEl && (diagPlayEl.style.display = "none");
        diagResultEl && (diagResultEl.style.display = "none");
      }

      if (stage === "result") {
        diagIntroEl && (diagIntroEl.style.display = "none");
        diagPlayEl && (diagPlayEl.style.display = "none");
        diagResultEl && (diagResultEl.style.display = "block");

        const maxScore = deckLen * 15;
        diagResultTextEl &&
          (diagResultTextEl.innerHTML = `Tu as obtenu <strong>${diagScore}</strong> / ${maxScore} points sur ce jeu.`);
      }

      if (stage === "play") {
        diagIntroEl && (diagIntroEl.style.display = "none");
        diagResultEl && (diagResultEl.style.display = "none");
        diagPlayEl && (diagPlayEl.style.display = "block");

        const current = getCurrentDiagItem();
        if (current) {
          diagIndexEl && (diagIndexEl.textContent = String(diagIndex + 1));
          diagSymptomEl && (diagSymptomEl.textContent = current.symptom);

          if (diagChoicesEl) {
            diagChoicesEl.innerHTML = "";
            current.choices.forEach((choice, idx) => {
              const btn = document.createElement("button");
              btn.type = "button";
              btn.className = "choice-btn";
              btn.textContent = choice;
              btn.addEventListener("click", () => selectDiagChoice(idx));
              diagChoicesEl.appendChild(btn);
            });
          }

          if (diagAnswered) {
            const buttons = diagChoicesEl ? diagChoicesEl.querySelectorAll(".choice-btn") : [];
            buttons.forEach((btn, bIdx) => {
              btn.classList.add("disabled");
              if (bIdx === current.correctIndex) btn.classList.add("correct");
              else if (diagChosenIndex !== null && bIdx === diagChosenIndex) btn.classList.add("wrong");
            });
            diagNextBtn && (diagNextBtn.disabled = false);
          } else {
            diagNextBtn && (diagNextBtn.disabled = true);
          }
        }
      }
    }

    // ===== MEMO IMAGES restore =====
    if (state.memImg) {
      memImgMoves = Number(state.memImg.moves ?? 0);
      memImgFound = Number(state.memImg.found ?? 0);
      memImgScore = Number(state.memImg.score ?? 0);

      memoryImgMovesEl && (memoryImgMovesEl.textContent = String(memImgMoves));
      memoryImgFoundEl && (memoryImgFoundEl.textContent = String(memImgFound));
      memoryImgScoreEl && (memoryImgScoreEl.textContent = String(memImgScore));

      const boardVisible = !!state.memImg.boardVisible;
      memoryImgBoardCard && (memoryImgBoardCard.style.display = boardVisible ? "block" : "none");
      memoryImgRestartBtn && (memoryImgRestartBtn.style.display = boardVisible ? "inline-flex" : "none");

      memImgSelected = [];
      memImgLock = false;

      if (Array.isArray(state.memImg.deck) && state.memImg.deck.length > 0) {
        renderMemoryImagesBoard(state.memImg.deck);
        applyIndices(memoryImgGridEl, state.memImg.matchedIdx || [], "matched");

        const sel = Array.isArray(state.memImg.selectedIdx) ? state.memImg.selectedIdx : [];
        const cleanSel = sel.filter((i) => Number.isFinite(i)).slice(0, 2);

        cleanSel.forEach((i) => {
          const el = memoryImgGridEl.querySelector(`.memory-card[data-card-index="${i}"]`);
          if (el && !el.classList.contains("matched")) {
            el.classList.add("revealed");
            memImgSelected.push(el);
          }
        });
      }
    }

    isRestoring = false;
    saveState(); 
  }

  // Sauvegarde auto à chaque refresh/fermeture
  window.addEventListener("beforeunload", saveState);

  // Restore au chargement
  restoreState();
});
