const http = require("http");
const { URL } = require("url");

const { getAttackDistance, calculateDamage } = require("./utils/balanceUtils");
const { calculateFinalStats } = require("./services/statService");
const { processStepDistance } = require("./services/stepService");
const { upgradeStat } = require("./services/growthService");

const PORT = Number(process.env.PORT || 3000);
const DEFAULT_STRIDE_M = 0.75;
const GPS_TOLERANCE_RATIO = 0.35;
const GPS_TOLERANCE_MIN_M = 80;
const MONSTER_ATTACK_DISTANCE_M = 100;

const baseStats = { hp: 100, attack: 10, defense: 5, agility: 5 };
let upgradedStats = { hp: 20, attack: 3, defense: 2, agility: 1 };
const equipmentStats = { hp: 50, attack: 5, defense: 4, agility: 3 };
const monsterTemplate = {
  id: "training_slime",
  name: "훈련 슬라임",
  hp: 100,
  attack: 8,
  defense: 3,
  rewardCoin: 80,
};

let character = createInitialCharacter();
let monster = createMonster();
let monsterAttackGaugeM = 0;
let logs = [];

function getFinalStats() {
  return calculateFinalStats(baseStats, upgradedStats, equipmentStats);
}

function createInitialCharacter() {
  const finalStats = getFinalStats();
  return {
    id: "test_character",
    name: "테스트 캐릭터",
    coinBalance: 100,
    attackCountBalance: 0,
    currentHp: finalStats.hp,
  };
}

function createMonster() {
  return {
    ...monsterTemplate,
    currentHp: monsterTemplate.hp,
  };
}

function addLog(type, title, data = {}) {
  const log = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    type,
    title,
    data,
    createdAt: new Date().toLocaleTimeString("ko-KR"),
  };
  logs = [log, ...logs].slice(0, 40);
  return log;
}

function buildGpsCheck(motionDistanceM, gpsDistanceM) {
  if (!Number.isFinite(gpsDistanceM) || gpsDistanceM <= 0) {
    return {
      checked: false,
      suspicious: false,
      message: "GPS 측정값이 아직 없습니다.",
      reason: "gps_not_provided",
    };
  }

  const differenceM = Math.abs(motionDistanceM - gpsDistanceM);
  const allowedDifferenceM = Math.max(
    GPS_TOLERANCE_MIN_M,
    Math.max(motionDistanceM, gpsDistanceM) * GPS_TOLERANCE_RATIO
  );
  const suspicious = differenceM > allowedDifferenceM;

  return {
    checked: true,
    suspicious,
    motionDistanceM: Number(motionDistanceM.toFixed(1)),
    gpsDistanceM: Number(gpsDistanceM.toFixed(1)),
    differenceM: Number(differenceM.toFixed(1)),
    allowedDifferenceM: Number(allowedDifferenceM.toFixed(1)),
    message: suspicious
      ? "움직임 추정 거리와 GPS 거리가 많이 다릅니다. 부정 가능성이 있습니다."
      : "움직임과 GPS 차이가 허용 범위 안입니다.",
    reason: suspicious ? "distance_mismatch" : "ok",
  };
}

function getState() {
  const finalStats = getFinalStats();
  return {
    character,
    baseStats,
    upgradedStats,
    equipmentStats,
    finalStats,
    monster,
    defaultStrideM: DEFAULT_STRIDE_M,
    attackDistanceM: Number(getAttackDistance(finalStats.agility).toFixed(2)),
    playerDamagePerAttack: calculateDamage(finalStats.attack, monster.defense),
    monsterDamagePerAttack: calculateDamage(monster.attack, finalStats.defense),
    monsterAttackGaugeM: Number(monsterAttackGaugeM.toFixed(2)),
    monsterAttackDistanceM: MONSTER_ATTACK_DISTANCE_M,
    logs,
  };
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

function sendText(res, contentType, body) {
  res.writeHead(200, { "Content-Type": contentType });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        reject(new Error("Request body is too large."));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
  });
}

function earnAttackCount(distanceM, source, meta) {
  const finalStats = getFinalStats();
  const stepResult = processStepDistance(distanceM, finalStats.agility);
  character.attackCountBalance += stepResult.earnedAttackCount;
  const autoAttacks = [];

  const result = {
    ...stepResult,
    source,
    appliedDistanceM: distanceM,
    ...meta,
  };

  if (stepResult.earnedAttackCount > 0) {
    addLog(
      "activity",
      `${distanceM}m 이동 -> 공격 ${stepResult.earnedAttackCount}회 획득`,
      result
    );

    for (let i = 0; i < stepResult.earnedAttackCount; i += 1) {
      autoAttacks.push(attackMonsterOnce());
    }
  }

  return {
    ...result,
    autoAttacks,
    monsterRemainingHp: monster.currentHp,
    attackCountBalance: character.attackCountBalance,
  };
}

function attackMonsterOnce() {
  const finalStats = getFinalStats();

  if (character.attackCountBalance <= 0) {
    return {
      success: false,
      message: "보유 공격 횟수가 없습니다.",
    };
  }

  if (monster.currentHp <= 0) {
    monster = createMonster();
    monsterAttackGaugeM = 0;
  }

  const attackDistanceM = getAttackDistance(finalStats.agility);
  const playerDamage = calculateDamage(finalStats.attack, monster.defense);
  character.attackCountBalance -= 1;
  monsterAttackGaugeM += attackDistanceM;
  monster.currentHp = Math.max(monster.currentHp - playerDamage, 0);

  let monsterDamage = 0;
  let monsterAttacked = false;
  if (monster.currentHp > 0 && monsterAttackGaugeM >= MONSTER_ATTACK_DISTANCE_M) {
    monsterAttacked = true;
    monsterDamage = calculateDamage(monster.attack, finalStats.defense);
    character.currentHp = Math.max(character.currentHp - monsterDamage, 0);
    monsterAttackGaugeM -= MONSTER_ATTACK_DISTANCE_M;
  }

  let rewardCoin = 0;
  let defeated = false;
  if (monster.currentHp <= 0) {
    defeated = true;
    rewardCoin = monster.rewardCoin;
    character.coinBalance += rewardCoin;
    monsterAttackGaugeM = 0;
    addLog("battle", `몬스터 처치 성공, 코인 ${rewardCoin} 획득`, {
      playerDamage,
      rewardCoin,
    });
  } else {
    addLog("battle", `몬스터에게 ${playerDamage} 데미지`, {
      playerDamage,
      monsterDamage,
    });
  }

  return {
    success: true,
    defeated,
    playerDamage,
    monsterDamage,
    monsterAttacked,
    attackDistanceM,
    monsterAttackGaugeM: Number(monsterAttackGaugeM.toFixed(2)),
    monsterAttackDistanceM: MONSTER_ATTACK_DISTANCE_M,
    rewardCoin,
    monsterRemainingHp: monster.currentHp,
    characterRemainingHp: character.currentHp,
    attackCountBalance: character.attackCountBalance,
  };
}

async function handleApi(req, res, pathname) {
  if (req.method === "GET" && pathname === "/api/state") {
    sendJson(res, 200, getState());
    return;
  }

  if (req.method === "POST" && pathname === "/api/reset") {
    upgradedStats = { hp: 20, attack: 3, defense: 2, agility: 1 };
    character = createInitialCharacter();
    monster = createMonster();
    monsterAttackGaugeM = 0;
    logs = [];
    addLog("system", "테스트 상태 초기화");
    sendJson(res, 200, getState());
    return;
  }

  if (req.method === "POST" && pathname === "/api/activity-delta") {
    const body = await readBody(req);
    const distanceM = Math.max(0, Math.round(Number(body.distanceM || 0)));
    const motionDistanceM = Number(body.motionDistanceM || 0);
    const gpsDistanceM = Number(body.gpsDistanceM || 0);
    const gpsCheck = buildGpsCheck(motionDistanceM, gpsDistanceM);
    const result = earnAttackCount(distanceM, body.source || "activity", {
      motionStepCount: Math.max(0, Math.floor(Number(body.motionStepCount || 0))),
      motionDistanceM: Number(motionDistanceM.toFixed(1)),
      gpsDistanceM: Number(gpsDistanceM.toFixed(1)),
      gpsCheck,
    });

    sendJson(res, 200, {
      result,
      state: getState(),
    });
    return;
  }

  if (req.method === "POST" && pathname === "/api/attack-one") {
    const result = attackMonsterOnce();
    sendJson(res, 200, {
      result,
      state: getState(),
    });
    return;
  }

  if (req.method === "POST" && pathname === "/api/monster-reset") {
    monster = createMonster();
    monsterAttackGaugeM = 0;
    addLog("battle", "몬스터 리셋");
    sendJson(res, 200, getState());
    return;
  }

  if (req.method === "POST" && pathname === "/api/upgrade") {
    const body = await readBody(req);
    const statType = body.statType || "attack";
    const finalStats = getFinalStats();
    const result = upgradeStat(finalStats, statType, character.coinBalance);

    if (result.success) {
      upgradedStats[statType] += 1;
      character.coinBalance = result.afterCoin;
      if (statType === "hp") character.currentHp += 1;
    }

    addLog("upgrade", `${statType} 강화 ${result.success ? "성공" : "실패"}`, result);
    sendJson(res, 200, { result, state: getState() });
    return;
  }

  if (req.method === "POST" && pathname === "/api/debug-stat") {
    const body = await readBody(req);
    const statType = body.statType || "attack";
    const amount = Math.max(1, Math.floor(Number(body.amount || 1)));

    if (!Object.prototype.hasOwnProperty.call(upgradedStats, statType)) {
      sendJson(res, 400, { message: "없는 스탯입니다." });
      return;
    }

    upgradedStats[statType] += amount;
    if (statType === "hp") character.currentHp += amount;
    addLog("upgrade", `${statType} 테스트 +${amount}`);
    sendJson(res, 200, {
      result: { success: true, statType, amount, upgradedStats },
      state: getState(),
    });
    return;
  }

  sendJson(res, 404, { message: "API not found" });
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);

    if (url.pathname === "/") {
      sendText(res, "text/html; charset=utf-8", html);
      return;
    }
    if (url.pathname === "/manifest.webmanifest") {
      sendJson(res, 200, manifest);
      return;
    }
    if (url.pathname === "/sw.js") {
      sendText(res, "text/javascript; charset=utf-8", serviceWorker);
      return;
    }
    if (url.pathname === "/icon.svg") {
      sendText(res, "image/svg+xml; charset=utf-8", iconSvg);
      return;
    }
    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url.pathname);
      return;
    }

    sendJson(res, 404, { message: "Not found" });
  } catch (error) {
    sendJson(res, 500, { message: error.message });
  }
});

server.listen(PORT, () => {
  console.log(`Simple test app: http://localhost:${PORT}`);
});

const manifest = {
  name: "걸음 전투 테스트",
  short_name: "걸음전투",
  start_url: "/",
  scope: "/",
  display: "standalone",
  background_color: "#f4f7f8",
  theme_color: "#246b61",
  icons: [
    {
      src: "/icon.svg",
      sizes: "any",
      type: "image/svg+xml",
      purpose: "any maskable",
    },
  ],
};

const serviceWorker = String.raw`const CACHE_NAME = "step-battle-test-v5";
const APP_SHELL = ["/", "/manifest.webmanifest", "/icon.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  event.respondWith(fetch(event.request).catch(() => caches.match(event.request)));
});`;

const iconSvg = String.raw`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="96" fill="#246b61"/>
  <path d="M145 342c43-13 70-41 81-83 8-31 26-52 57-61 28-8 57-2 86 18" fill="none" stroke="#ffffff" stroke-width="34" stroke-linecap="round"/>
  <circle cx="164" cy="354" r="32" fill="#f5d36c"/>
  <path d="M318 266l76-76M362 178l44 44" fill="none" stroke="#f5d36c" stroke-width="34" stroke-linecap="round"/>
</svg>`;

const html = String.raw`<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="theme-color" content="#246b61" />
  <meta name="mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <link rel="manifest" href="/manifest.webmanifest" />
  <link rel="icon" href="/icon.svg" />
  <title>걸음 전투 테스트</title>
  <style>
    :root {
      color-scheme: light;
      font-family: Arial, "Malgun Gothic", sans-serif;
      background: #f4f7f8;
      color: #1d2a2e;
    }
    * { box-sizing: border-box; }
    body { margin: 0; padding: 14px; }
    main { width: min(1120px, 100%); margin: 0 auto; display: grid; gap: 12px; }
    header, section { background: #fff; border: 1px solid #dce5e8; border-radius: 8px; padding: 14px; }
    h1, h2 { margin: 0 0 10px; line-height: 1.25; }
    h1 { font-size: 22px; }
    h2 { font-size: 17px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 12px; }
    .stat { display: flex; justify-content: space-between; gap: 10px; padding: 8px 0; border-bottom: 1px solid #edf1f3; }
    .stat:last-child { border-bottom: 0; }
    .row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
    .row > * { flex: 1 1 140px; }
    button, input, select { min-height: 40px; border: 1px solid #bdcbd0; border-radius: 6px; font: inherit; }
    button { padding: 0 12px; background: #246b61; color: #fff; cursor: pointer; }
    button.secondary { background: #fff; color: #1d2a2e; }
    button.danger { background: #9d352d; }
    button.hidden { display: none; }
    input, select { width: 100%; padding: 0 10px; background: #fff; }
    progress { width: 100%; height: 18px; accent-color: #246b61; }
    pre { margin: 0; padding: 10px; max-height: 230px; overflow: auto; border-radius: 6px; background: #102025; color: #d6f0e5; font-size: 12px; line-height: 1.45; white-space: pre-wrap; }
    .status { min-height: 24px; color: #486166; font-size: 14px; }
    .warning { display: none; padding: 10px; border-radius: 6px; background: #fff2cc; border: 1px solid #e0b642; color: #654b00; }
    .warning.show { display: block; }
    .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(135px, 1fr)); gap: 8px; margin-top: 10px; }
    .metric { border: 1px solid #edf1f3; border-radius: 6px; padding: 10px; background: #fbfcfc; }
    .metric strong { display: block; margin-top: 6px; font-size: 22px; }
    .muted { color: #697d82; font-size: 13px; }
    .log { display: grid; gap: 8px; }
    .log-item { border: 1px solid #edf1f3; border-radius: 6px; padding: 8px; background: #fbfcfc; }
  </style>
</head>
<body>
  <main>
    <header>
      <h1>걸음 / GPS 전투 테스트</h1>
      <div class="status" id="sensorStatus">측정 시작을 누르고 걸으면 공격 횟수가 자동으로 찹니다.</div>
      <div class="row" style="margin-top: 10px;">
        <button class="secondary hidden" id="installButton">앱처럼 설치</button>
      </div>
    </header>

    <section>
      <h2>실시간 측정</h2>
      <div class="row">
        <button id="startButton">측정 시작</button>
        <button class="secondary" id="stopButton">측정 정지</button>
        <button class="secondary" id="clearMeasureButton">측정값 초기화</button>
      </div>
      <div class="metric-grid">
        <div class="metric">움직임 추정 걸음<strong id="motionSteps">0</strong></div>
        <div class="metric">걸음 추정 거리<strong id="motionDistance">0.0m</strong></div>
        <div class="metric">GPS 거리<strong id="trackedDistance">0.0m</strong></div>
        <div class="metric">자동 반영 거리<strong id="creditedDistance">0.0m</strong></div>
      </div>
      <div style="margin-top: 10px;">
        <div class="muted">다음 공격까지</div>
        <progress id="attackProgress" max="1" value="0"></progress>
        <div class="muted" id="progressText">0.0m / 0.0m</div>
      </div>
      <div class="warning" id="fraudWarning"></div>
      <div class="row" style="margin-top: 10px;">
        <input id="strideM" type="number" min="0.1" step="0.01" value="0.75" aria-label="보폭" />
      </div>
      <p class="muted">웹 테스트라 공식 만보기 값 대신 움직임 센서로 걸음을 추정합니다. GPS와 차이가 크면 경고가 뜹니다.</p>
    </section>

    <div class="grid">
      <section>
        <h2>캐릭터</h2>
        <div id="characterStats"></div>
      </section>
      <section>
        <h2>몬스터</h2>
        <div id="monsterStats"></div>
        <progress id="monsterHpBar" max="100" value="100"></progress>
      </section>
      <section>
        <h2>스탯 테스트</h2>
        <div id="finalStats"></div>
        <div class="row" style="margin-top: 10px;">
          <button data-stat="attack">공격 +1</button>
          <button data-stat="defense">방어 +1</button>
          <button data-stat="agility">민첩 +1</button>
          <button data-stat="hp">체력 +1</button>
        </div>
      </section>
    </div>

    <section>
      <h2>전투</h2>
      <div class="row">
        <button id="attackButton">1회 공격</button>
        <button class="secondary" id="monsterResetButton">몬스터 리셋</button>
        <select id="statType">
          <option value="attack">공격 강화</option>
          <option value="defense">방어 강화</option>
          <option value="agility">민첩 강화</option>
          <option value="hp">체력 강화</option>
        </select>
        <button id="upgradeButton">코인으로 강화</button>
        <button class="danger" id="resetButton">전체 초기화</button>
      </div>
    </section>

    <section>
      <h2>최근 결과</h2>
      <pre id="latestResult">{}</pre>
    </section>

    <section>
      <h2>로그</h2>
      <div class="log" id="logs"></div>
    </section>
  </main>

  <script>
    let state = null;
    let watchId = null;
    let lastPosition = null;
    let trackedDistanceM = 0;
    let motionStepCount = 0;
    let motionActive = false;
    let lastStepAt = 0;
    let filteredMagnitude = 9.8;
    let creditedDistanceM = 0;
    let earningNow = false;
    let deferredInstallPrompt = null;

    const els = {
      sensorStatus: document.querySelector("#sensorStatus"),
      characterStats: document.querySelector("#characterStats"),
      finalStats: document.querySelector("#finalStats"),
      monsterStats: document.querySelector("#monsterStats"),
      monsterHpBar: document.querySelector("#monsterHpBar"),
      motionSteps: document.querySelector("#motionSteps"),
      motionDistance: document.querySelector("#motionDistance"),
      trackedDistance: document.querySelector("#trackedDistance"),
      creditedDistance: document.querySelector("#creditedDistance"),
      attackProgress: document.querySelector("#attackProgress"),
      progressText: document.querySelector("#progressText"),
      fraudWarning: document.querySelector("#fraudWarning"),
      strideM: document.querySelector("#strideM"),
      statType: document.querySelector("#statType"),
      latestResult: document.querySelector("#latestResult"),
      logs: document.querySelector("#logs"),
    };

    if ("serviceWorker" in navigator) navigator.serviceWorker.register("/sw.js");

    window.addEventListener("beforeinstallprompt", (event) => {
      event.preventDefault();
      deferredInstallPrompt = event;
      document.querySelector("#installButton").classList.remove("hidden");
    });

    document.querySelector("#installButton").addEventListener("click", async () => {
      if (!deferredInstallPrompt) return;
      deferredInstallPrompt.prompt();
      await deferredInstallPrompt.userChoice;
      deferredInstallPrompt = null;
      document.querySelector("#installButton").classList.add("hidden");
    });

    function meterDistance(a, b) {
      const radiusM = 6371000;
      const toRad = (degree) => degree * Math.PI / 180;
      const dLat = toRad(b.latitude - a.latitude);
      const dLon = toRad(b.longitude - a.longitude);
      const lat1 = toRad(a.latitude);
      const lat2 = toRad(b.latitude);
      const value = Math.sin(dLat / 2) ** 2 +
        Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
      return 2 * radiusM * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
    }

    async function request(path, body) {
      const options = body
        ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) }
        : undefined;
      const response = await fetch(path, options);
      const data = await response.json();
      if (!response.ok) throw new Error(data.message || "요청 실패");
      return data;
    }

    function renderStats(target, data) {
      target.innerHTML = Object.entries(data)
        .map(([key, value]) => '<div class="stat"><span>' + key + '</span><strong>' + value + '</strong></div>')
        .join("");
    }

    function getMotionDistanceM() {
      return motionStepCount * Number(els.strideM.value || 0.75);
    }

    function getAppliedDistanceM() {
      return Math.max(getMotionDistanceM(), trackedDistanceM);
    }

    function localGpsCheck() {
      const motion = getMotionDistanceM();
      const gps = trackedDistanceM;
      if (Math.max(motion, gps) < 20) return { suspicious: false, message: "" };
      const diff = Math.abs(motion - gps);
      const allowed = Math.max(80, Math.max(motion, gps) * 0.35);
      return {
        suspicious: diff > allowed,
        message: "경고: 움직임 추정 거리와 GPS 거리가 많이 다릅니다. 부정 가능성이 있습니다.",
      };
    }

    function renderMeasurement() {
      const attackDistance = state ? state.attackDistanceM : 1;
      const applied = getAppliedDistanceM();
      const pending = Math.max(applied - creditedDistanceM, 0);
      const progress = attackDistance > 0 ? Math.min(pending / attackDistance, 1) : 0;
      const check = localGpsCheck();

      els.motionSteps.textContent = motionStepCount;
      els.motionDistance.textContent = getMotionDistanceM().toFixed(1) + "m";
      els.trackedDistance.textContent = trackedDistanceM.toFixed(1) + "m";
      els.creditedDistance.textContent = creditedDistanceM.toFixed(1) + "m";
      els.attackProgress.value = progress;
      els.progressText.textContent = pending.toFixed(1) + "m / " + attackDistance.toFixed(1) + "m";
      els.fraudWarning.classList.toggle("show", check.suspicious);
      els.fraudWarning.textContent = check.message;
    }

    function render() {
      if (!state) return;

      renderStats(els.characterStats, {
        이름: state.character.name,
        체력: state.character.currentHp + " / " + state.finalStats.hp,
        코인: state.character.coinBalance,
        "공격 횟수": state.character.attackCountBalance,
      });

      renderStats(els.finalStats, {
        체력: state.finalStats.hp,
        공격: state.finalStats.attack,
        방어: state.finalStats.defense,
        민첩: state.finalStats.agility,
        "공격 1회 필요 거리": state.attackDistanceM + "m",
        "1회 데미지": state.playerDamagePerAttack,
      });

      renderStats(els.monsterStats, {
        이름: state.monster.name,
        체력: state.monster.currentHp + " / " + state.monster.hp,
        공격: state.monster.attack,
        방어: state.monster.defense,
        보상코인: state.monster.rewardCoin,
      });
      els.monsterHpBar.max = state.monster.hp;
      els.monsterHpBar.value = state.monster.currentHp;

      els.logs.innerHTML = state.logs.length
        ? state.logs.map((log) =>
            '<div class="log-item"><strong>[' + log.createdAt + '] ' + log.title + '</strong><div class="muted">' + log.type + '</div></div>'
          ).join("")
        : '<div class="muted">아직 로그가 없습니다.</div>';

      renderMeasurement();
    }

    async function refresh() {
      state = await request("/api/state");
      els.strideM.value = state.defaultStrideM;
      render();
    }

    async function autoEarnIfReady() {
      if (!state || earningNow) return;

      const applied = getAppliedDistanceM();
      const pending = applied - creditedDistanceM;
      if (pending < state.attackDistanceM) {
        renderMeasurement();
        return;
      }

      const earnableDistance = Math.floor(pending / state.attackDistanceM) * state.attackDistanceM;
      earningNow = true;
      const data = await request("/api/activity-delta", {
        distanceM: earnableDistance,
        source: trackedDistanceM > getMotionDistanceM() ? "gps" : "motion",
        motionStepCount,
        motionDistanceM: getMotionDistanceM(),
        gpsDistanceM: trackedDistanceM,
      });
      creditedDistanceM += earnableDistance;
      state = data.state;
      els.latestResult.textContent = JSON.stringify(data.result, null, 2);
      earningNow = false;
      render();
    }

    function handleMotion(event) {
      if (!motionActive) return;
      const acc = event.accelerationIncludingGravity || event.acceleration;
      if (!acc) return;

      const x = acc.x || 0;
      const y = acc.y || 0;
      const z = acc.z || 0;
      const magnitude = Math.sqrt(x * x + y * y + z * z);
      filteredMagnitude = filteredMagnitude * 0.85 + magnitude * 0.15;

      const now = Date.now();
      if (magnitude - filteredMagnitude > 1.7 && now - lastStepAt > 350) {
        motionStepCount += 1;
        lastStepAt = now;
        renderMeasurement();
        autoEarnIfReady();
      }
    }

    async function startMotion() {
      if (!window.DeviceMotionEvent) {
        els.sensorStatus.textContent = "이 브라우저는 움직임 센서를 지원하지 않습니다.";
        return;
      }
      if (typeof DeviceMotionEvent.requestPermission === "function") {
        const permission = await DeviceMotionEvent.requestPermission();
        if (permission !== "granted") {
          els.sensorStatus.textContent = "움직임 센서 권한이 거부되었습니다.";
          return;
        }
      }
      motionActive = true;
      window.addEventListener("devicemotion", handleMotion);
    }

    function stopMotion() {
      motionActive = false;
      window.removeEventListener("devicemotion", handleMotion);
    }

    function startGps() {
      if (!navigator.geolocation) {
        els.sensorStatus.textContent = "이 브라우저는 GPS를 지원하지 않습니다.";
        return;
      }
      lastPosition = null;
      watchId = navigator.geolocation.watchPosition(
        (position) => {
          const current = position.coords;
          if (lastPosition) {
            const moved = meterDistance(lastPosition, current);
            if (moved >= 1 && current.accuracy <= 80) trackedDistanceM += moved;
          }
          lastPosition = current;
          els.sensorStatus.textContent = "측정 중입니다. GPS 정확도 " + Math.round(current.accuracy) + "m";
          renderMeasurement();
          autoEarnIfReady();
        },
        (error) => { els.sensorStatus.textContent = "GPS 오류: " + error.message; },
        { enableHighAccuracy: true, maximumAge: 1000, timeout: 10000 }
      );
    }

    async function startTracking() {
      await startMotion();
      startGps();
      els.sensorStatus.textContent = "측정 중입니다. 공격 1회 거리만큼 걸으면 자동으로 공격 횟수가 찹니다.";
    }

    function stopTracking() {
      stopMotion();
      if (watchId !== null) {
        navigator.geolocation.clearWatch(watchId);
        watchId = null;
      }
      els.sensorStatus.textContent = "측정을 정지했습니다.";
    }

    function clearMeasurement() {
      motionStepCount = 0;
      trackedDistanceM = 0;
      creditedDistanceM = 0;
      lastPosition = null;
      renderMeasurement();
    }

    document.querySelector("#startButton").addEventListener("click", startTracking);
    document.querySelector("#stopButton").addEventListener("click", stopTracking);
    document.querySelector("#clearMeasureButton").addEventListener("click", () => {
      clearMeasurement();
      els.sensorStatus.textContent = "측정값을 초기화했습니다.";
    });

    document.querySelector("#attackButton").addEventListener("click", async () => {
      const data = await request("/api/attack-one", {});
      state = data.state;
      els.latestResult.textContent = JSON.stringify(data.result, null, 2);
      render();
    });

    document.querySelector("#monsterResetButton").addEventListener("click", async () => {
      state = await request("/api/monster-reset", {});
      render();
    });

    document.querySelectorAll("[data-stat]").forEach((button) => {
      button.addEventListener("click", async () => {
        const data = await request("/api/debug-stat", { statType: button.dataset.stat, amount: 1 });
        state = data.state;
        els.latestResult.textContent = JSON.stringify(data.result, null, 2);
        render();
      });
    });

    document.querySelector("#upgradeButton").addEventListener("click", async () => {
      const data = await request("/api/upgrade", { statType: els.statType.value });
      state = data.state;
      els.latestResult.textContent = JSON.stringify(data.result, null, 2);
      render();
    });

    document.querySelector("#resetButton").addEventListener("click", async () => {
      state = await request("/api/reset", {});
      els.latestResult.textContent = "{}";
      stopTracking();
      clearMeasurement();
      render();
    });

    refresh();
  </script>
</body>
</html>`;
