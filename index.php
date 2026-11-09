<?php
// @cocxace Repository Server-Side Entrypoint
header('Content-Type: text/html; charset=utf-8');
header('X-Clacks-Overhead: GNU Terry Pratchett');
header('X-Platform: iOS 12.0-12.5.8 (arm64 Apple A7)');
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <title>cocxace Repo — Pure Minecraft Monochrome (iOS 12)</title>
  <meta name="description" content="Pure monochrome Minecraft-style jailbreak repository for iOS 12.0 - 12.5.8 (iPhone 5s / A7). Glint Dynamic Island, Camera60Enabler5s, Aura, ActionButton12.">
  <link rel="icon" type="image/png" href="CydiaIcon.png">
  <link rel="stylesheet" href="style.css">
</head>
<body>

  <!-- Toast Notification -->
  <div class="toast-msg" id="toastMsg">URL COPIED!</div>

  <!-- SINGLE VERTICAL STACK CONTAINER -->
  <main class="stack-container">

    <!-- 1. TOP HEADER -->
    <header class="top-header">
      <div class="hero-logo">@COCXACE REPO</div>
      <div class="px-title" style="font-size:0.56rem;">ARM64 • IOS 12.0 — 12.5.8</div>
      <div class="header-meta">
        <span class="px-tag">A7 OPTIMIZED</span>
        <span class="px-tag">PURE GNU TAR</span>
        <span class="px-tag">ZERO SAFE-MODE</span>
        <span class="px-tag">v1.2.3 LIVE</span>
      </div>
    </header>

    <!-- 2. DYNAMIC ISLAND SIMULATOR -->
    <section class="island-box">
      <div class="island-statusbar">
        <span id="simClock" title="Click to toggle 12/24h">09:41:00 AM</span>
        <span>21°C • 100% ⚡</span>
      </div>

      <div class="island-wrap">
        <div class="dynamic-island state-compact" id="liveIsland" title="Click to toggle / Long-press for Sparkles">
          <!-- Compact View -->
          <div id="islandCompactView" style="display:flex; justify-content:space-between; align-items:center; width:100%;">
            <div style="font-family:var(--pixel-font); font-size:0.5rem; color:#ffffff; display:flex; align-items:center; gap:6px;">
              <span id="islandModeIcon">🏝️</span>
              <span id="islandModeText">GLINT</span>
            </div>
            <div style="display:flex; align-items:center; gap:5px;">
              <div class="pixel-eq" id="pixelEq">
                <div class="pixel-eq-bar" style="height:6px;"></div>
                <div class="pixel-eq-bar" style="height:12px;"></div>
                <div class="pixel-eq-bar" style="height:15px;"></div>
                <div class="pixel-eq-bar" style="height:8px;"></div>
              </div>
              <span id="islandSecIcon" style="font-size:0.6rem;">🎧</span>
            </div>
          </div>

          <!-- Expanded Card View -->
          <div id="islandExpandedView" style="display:none; width:100%;">
            <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px dashed #333; padding-bottom:6px; margin-bottom:8px;">
              <div style="font-family:var(--pixel-font); font-size:0.48rem; color:#fff;">NOW PLAYING</div>
              <button class="px-btn-sm" id="btnCloseIsland" style="padding:2px 6px;">✕</button>
            </div>
            <div style="font-size:0.75rem; color:#ccc;">Track: Starlight Beat (Safari)</div>
            <div style="font-size:0.68rem; color:#888;">Artist: @cocxace • 60 FPS Sync</div>
            <div style="display:flex; justify-content:space-around; margin-top:8px;">
              <button class="px-btn-sm" onclick="showToast('⏮ PREV')">⏮</button>
              <button class="px-btn-sm" onclick="showToast('⏸ PAUSE')">⏸</button>
              <button class="px-btn-sm" onclick="showToast('⏭ NEXT')">⏭</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Island Mode Pickers -->
      <div class="sim-controls">
        <button class="px-btn-sm active" onclick="setIslandState('music')">🎵 MUSIC EQ</button>
        <button class="px-btn-sm" onclick="setIslandState('timer')">⏱️ TIMER</button>
        <button class="px-btn-sm" onclick="setIslandState('charging')">⚡ CHARGING</button>
        <button class="px-btn-sm" onclick="setIslandState('compact')">🏝️ CAPSULE</button>
      </div>
    </section>

    <!-- 3. USER PHONE WALKTHROUGH (HDJDJW.HTML CAROUSEL) -->
    <section class="phone-box">
      <div class="phone-track"><div class="phone-fill" id="uFill"></div></div>
      <div class="scenes-wrap" id="uWrap">

        <!-- Scene 0 -->
        <div class="user-scene active">
          <div class="u-logo"><svg viewBox="0 0 24 24"><path d="M13 2L3 14h7l-1 8 10-12h-7l1-8z"/></svg></div>
          <h2 class="u-title">GLINT</h2>
          <p class="u-subtitle">Dynamic Island for iOS 12.<br>Spring physics · Timer · Music equalizer.</p>
        </div>

        <!-- Scene 1 -->
        <div class="user-scene">
          <div class="u-feat"><div class="u-fi">01</div><div class="u-ft">Dynamic Island for iOS 12</div><div class="u-fnum">[OK]</div></div>
          <div class="u-feat"><div class="u-fi">02</div><div class="u-ft">Spring expansion animation</div><div class="u-fnum">[OK]</div></div>
          <div class="u-feat"><div class="u-fi">03</div><div class="u-ft">Live countdown timer MM:SS</div><div class="u-fnum">[OK]</div></div>
          <div class="u-feat"><div class="u-fi">04</div><div class="u-ft">Zero Safe Mode · Pure GNU deb</div><div class="u-fnum">[OK]</div></div>
        </div>

        <!-- Scene 2 -->
        <div class="user-scene">
          <div class="u-step"><div class="u-sn">01</div><div class="u-sc"><div class="u-st">OPEN SILEO</div><div class="u-sd">Launch package manager on your device</div></div></div>
          <div class="u-step"><div class="u-sn">02</div><div class="u-sc"><div class="u-st">ADD REPO</div><div class="u-sd">Sources → + → paste repository URL</div><span class="u-su">https://abulhketus-collab.github.io/repo/</span></div></div>
          <div class="u-step"><div class="u-sn">03</div><div class="u-sc"><div class="u-st">FIND GLINT</div><div class="u-sd">Search Glint in package search tab</div></div></div>
          <div class="u-step"><div class="u-sn">04</div><div class="u-sc"><div class="u-st">INSTALL</div><div class="u-sd">Tap Install & confirm respring</div></div></div>
        </div>

        <!-- Scene 3 -->
        <div class="user-scene">
          <div class="u-chk">✓ READY</div>
          <div class="px-title" style="font-size:0.68rem; margin-bottom:6px;">ADD REPO TO DEVICE</div>
          <div class="u-urlbox" id="uBox" role="button" tabindex="0">
            <span id="uTxt">https://abulhketus-collab.github.io/repo/</span>
            <span style="font-family:var(--pixel-font); font-size:0.42rem;">[COPY]</span>
          </div>
          <a class="btn-pixel-big" id="iBtn" href="sileo://source/https://abulhketus-collab.github.io/repo/">
            ⚡ ADD TO SILEO
          </a>
          <button class="btn-pixel-sub" id="cBtn" style="margin-top:8px; width:100%;">
            📋 COPY REPOSITORY URL
          </button>
        </div>

      </div>

      <!-- Controls -->
      <div class="u-ctrl">
        <div class="u-dots" id="uDots">
          <div class="u-dot active" data-s="0"></div>
          <div class="u-dot" data-s="1"></div>
          <div class="u-dot" data-s="2"></div>
          <div class="u-dot" data-s="3"></div>
        </div>
        <div class="u-row">
          <button class="btn-pixel-sub" id="pBtn" style="flex:1;">PAUSE</button>
          <button class="btn-pixel-sub" id="rBtn" style="flex:1;">RESTART</button>
        </div>
      </div>
    </section>

    <!-- 4. PACKAGE MANAGERS CTA BUTTONS -->
    <section>
      <a href="sileo://source/https://abulhketus-collab.github.io/repo/" class="btn-pixel-big" style="margin-bottom:8px;">
        👉 ADD REPOSITORY TO SILEO
      </a>
      <div class="sub-btns-grid">
        <a href="zbra://sources/add/https://abulhketus-collab.github.io/repo/" class="btn-pixel-sub">ZEBRA</a>
        <a href="cydia://url/https://cydia.saurik.com/api/share#?source=https://abulhketus-collab.github.io/repo/" class="btn-pixel-sub">CYDIA</a>
        <button class="btn-pixel-sub" onclick="copyRepoUrl()">COPY</button>
      </div>
    </section>

    <!-- 5. CAMERA 60 FPS INTERACTIVE HUB -->
    <section class="pixel-card highlight">
      <div class="px-title" style="margin-bottom:8px;">📷 CAMERA60ENABLER5S STUDIO</div>
      <div class="px-sub" style="margin-bottom:10px;">Hardware unlock: 1080p 60 FPS on iPhone 5s stock camera app.</div>
      
      <div class="cam-vis-box">
        <div style="font-family:var(--pixel-font); font-size:0.44rem; color:#888; margin-bottom:6px;">SMOOTHNESS BENCHMARK</div>
        <div class="cam-track">
          <div class="cam-block fps-60" id="camBlock"></div>
        </div>
        <div style="display:flex; gap:6px;">
          <button class="px-btn-sm active" id="btnFps60" style="flex:1;" onclick="setFpsDemo(60)">60 FPS (SMOOTH)</button>
          <button class="px-btn-sm" id="btnFps30" style="flex:1;" onclick="setFpsDemo(30)">30 FPS (STOCK)</button>
        </div>
      </div>

      <div class="setting-row">
        <span>1080p 60 FPS Force:</span>
        <span class="pixel-switch active">ENABLED</span>
      </div>
      <div class="setting-row">
        <span>4K Mode:</span>
        <span class="pixel-switch">LOCKED (A7 MAX 1080P)</span>
      </div>
      <div class="setting-row">
        <span>Crash Safeguard (@try/@catch):</span>
        <span class="pixel-switch active">ACTIVE</span>
      </div>

      <div style="display:grid; grid-template-columns:1fr 1fr; gap:6px; margin-top:10px;">
        <button class="px-btn-sm active" onclick="showToast('MAX 1080P60 APPLIED')">MAX QUALITY</button>
        <button class="px-btn-sm" onclick="showToast('BALANCED PROFILE APPLIED')">BALANCED</button>
      </div>
    </section>

    <!-- 6. ALL 7 TWEAKS (SINGLE VERTICAL STACK) -->
    <section>
      <div class="px-title" style="margin-bottom:12px; font-size:0.75rem;">📦 VERIFIED TWEAKS (v1.2.3)</div>

      <!-- Tweak 1: Glint -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">🏝️ GLINT</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">True Dynamic Island for iOS 12.5.8. Timer MM:SS beside clock, Safari music with live equalizer, 1s edge glow & rainbow mode, charging indicator.</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ PURE GNU • 0 PAX</span>
          <a href="debs/com.cocxace.glint_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'Glint')">DOWNLOAD .DEB</a>
        </div>
      </article>

      <!-- Tweak 2: Camera60Enabler5s -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">📷 CAMERA60ENABLER5S</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">Unlocks 1080p 60 FPS recording in Camera app on iPhone 5s. Injects settings bundle directly into iOS Settings with quality presets.</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ 60 FPS VERIFIED</span>
          <a href="debs/com.cocxace.cam60enabler5s_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'Camera60Enabler5s')">DOWNLOAD .DEB</a>
        </div>
      </article>

      <!-- Tweak 3: Aura -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">✨ AURA</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">Action Button HUD with Apple spring physics (damping: 0.7). Dark glass blur, 2x2 grid, direct app workspace launch via SBUIController.</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ ZERO SAFE-MODE</span>
          <a href="debs/com.cocxace.aura_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'Aura')">DOWNLOAD .DEB</a>
        </div>
      </article>

      <!-- Tweak 4: ActionButton12 -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">🔘 ACTIONBUTTON12</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">Action Button HUD with volume & brightness sliders. Long-press Power (0.6s) trigger, 100% lazy UIWindow instantiation.</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ PURE GNU • 0 PAX</span>
          <a href="debs/com.cocxace.actionbutton12_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'ActionButton12')">DOWNLOAD .DEB</a>
        </div>
      </article>

      <!-- Tweak 5: Lumina -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">🌙 LUMINA</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">Always-On Display lockscreen with UltraLight clock and smooth alpha cross-dissolve transition. Sub-0.1% CPU battery consumption.</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ BATTERY OPTIMIZED</span>
          <a href="debs/com.cocxace.lumina_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'Lumina')">DOWNLOAD .DEB</a>
        </div>
      </article>

      <!-- Tweak 6: Echo -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">📡 ECHO</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">Custom carrier string in iOS 12 status bar. Darwin notification instant update without respring.</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ INSTANT APPLY</span>
          <a href="debs/com.cocxace.echo_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'Echo')">DOWNLOAD .DEB</a>
        </div>
      </article>

      <!-- Tweak 7: Volt -->
      <article class="tweak-item">
        <div class="tweak-top-row">
          <span class="tweak-title">🔋 VOLT</span>
          <span class="tweak-ver">v1.2.3</span>
        </div>
        <p class="tweak-desc">Numerical battery percentage in iOS 12 status bar with dynamic color gradient tinting (Green > Yellow > Red).</p>
        <div class="tweak-meta-row">
          <span class="tweak-status-txt">✓ A7 TESTED</span>
          <a href="debs/com.cocxace.volt_1.2.3_iphoneos-arm.deb" class="btn-pixel-sub" onclick="handleDebDownload(event, 'Volt')">DOWNLOAD .DEB</a>
        </div>
      </article>
    </section>

    <!-- 7. ISLAND LIGHTING & CONTROLS STUDIO -->
    <section class="pixel-card">
      <div class="px-title" style="margin-bottom:8px;">🎛️ ISLAND LIGHTING STUDIO</div>
      
      <div class="setting-row">
        <span>🌈 Rainbow Cycle:</span>
        <button class="pixel-switch" id="btnToggleRainbow" onclick="toggleRainbowMode()">OFF</button>
      </div>

      <div class="setting-row">
        <span>✨ 1s Breathing Blink:</span>
        <button class="pixel-switch" id="btnToggleBlink" onclick="toggleBlinkMode()">OFF</button>
      </div>

      <div class="setting-row">
        <span>🥁 Beat Pulse Sync:</span>
        <button class="pixel-switch active" id="btnToggleBeat" onclick="toggleBeatPulse()">ON</button>
      </div>

      <div style="margin-top:10px;">
        <button class="btn-pixel-sub" style="width:100%;" onclick="playTimerBell()">🔔 TEST AUDIO CHIME BELL</button>
      </div>
    </section>

    <!-- 8. FILZA 1-2-3 MANUAL INSTALLATION -->
    <section class="pixel-card">
      <div class="px-title" style="margin-bottom:6px;">📥 FILZA 1-2-3 GUIDE</div>
      <div style="font-size:0.75rem; color:#aaa; line-height:1.6;">
        1. Download any .deb file above in Safari.<br>
        2. Tap "Open in Filza".<br>
        3. Tap the package → Install (code 0) → Respring!
      </div>
    </section>

    <!-- FOOTER -->
    <footer style="text-align:center; padding:20px 0; font-family:var(--pixel-font); font-size:0.42rem; color:#666;">
      DEVELOPED BY @COCXACE • 2026<br>
      NO AI SLOP • PURE RETRO MINECRAFT MONO
    </footer>

  </main>

  <!-- Strictly iOS 12 Safari Compatible JavaScript (No ?., No ??, No Array.at) -->
  <script>
    var currentIslandMode = 'music';
    var isExpanded = false;
    var timerSeconds = 300;
    var timerInterval = null;
    var audioCtx = null;
    var beatPulseEnabled = true;
    var rainbowActive = false;
    var blinkActive = false;
    var use24hTime = false;

    // 1. Clock
    function updateClock() {
      var d = new Date();
      var h = d.getHours();
      var m = d.getMinutes();
      var s = d.getSeconds();
      var ampm = '';
      if (!use24hTime) {
        ampm = h >= 12 ? ' PM' : ' AM';
        h = h % 12;
        if (h === 0) h = 12;
      }
      var strH = (h < 10 ? '0' : '') + h;
      var strM = (m < 10 ? '0' : '') + m;
      var strS = (s < 10 ? '0' : '') + s;
      var el = document.getElementById('simClock');
      if (el) el.textContent = strH + ':' + strM + ':' + strS + ampm;
    }
    setInterval(updateClock, 1000);
    updateClock();

    var clockEl = document.getElementById('simClock');
    if (clockEl) {
      clockEl.addEventListener('click', function() {
        use24hTime = !use24hTime;
        updateClock();
        showToast(use24hTime ? 'CLOCK: 24-HOUR' : 'CLOCK: 12-HOUR');
      });
    }

    // 2. Island Controller
    function setIslandState(state) {
      currentIslandMode = state;
      var island = document.getElementById('liveIsland');
      var compactView = document.getElementById('islandCompactView');
      var expandedView = document.getElementById('islandExpandedView');
      var icon = document.getElementById('islandModeIcon');
      var text = document.getElementById('islandModeText');
      var secIcon = document.getElementById('islandSecIcon');

      var pills = document.querySelectorAll('.sim-controls .px-btn-sm');
      for (var i = 0; i < pills.length; i++) pills[i].className = 'px-btn-sm';

      if (state === 'compact') {
        island.className = 'dynamic-island state-compact' + getGlowClasses();
        compactView.style.display = 'flex';
        expandedView.style.display = 'none';
        icon.textContent = '🏝️';
        text.textContent = 'GLINT';
        secIcon.textContent = '⚡';
        stopTimer();
      } else if (state === 'timer') {
        island.className = 'dynamic-island state-timer' + getGlowClasses();
        compactView.style.display = 'flex';
        expandedView.style.display = 'none';
        icon.textContent = '⏱️';
        text.textContent = formatTimerTime(timerSeconds);
        secIcon.textContent = '🔔';
        startTimer();
      } else if (state === 'music') {
        island.className = 'dynamic-island state-music' + getGlowClasses();
        compactView.style.display = 'flex';
        expandedView.style.display = 'none';
        icon.textContent = '🎵';
        text.textContent = 'STARLIGHT';
        secIcon.textContent = '🎧';
        stopTimer();
      } else if (state === 'charging') {
        island.className = 'dynamic-island state-compact' + getGlowClasses();
        compactView.style.display = 'flex';
        expandedView.style.display = 'none';
        icon.textContent = '⚡';
        text.textContent = '100%';
        secIcon.textContent = '🔋';
        stopTimer();
        showToast('CHARGING: 100% FAST PULSE');
      }
    }

    function getGlowClasses() {
      var cls = '';
      if (rainbowActive) cls += ' rainbow-mode';
      if (blinkActive) cls += ' breathing-mode';
      return cls;
    }

    var islandEl = document.getElementById('liveIsland');
    if (islandEl) {
      islandEl.addEventListener('click', function(e) {
        if (e.target && e.target.tagName === 'BUTTON') return;
        isExpanded = !isExpanded;
        var compactView = document.getElementById('islandCompactView');
        var expandedView = document.getElementById('islandExpandedView');
        if (isExpanded) {
          islandEl.className = 'dynamic-island state-expanded' + getGlowClasses();
          compactView.style.display = 'none';
          expandedView.style.display = 'block';
        } else {
          setIslandState(currentIslandMode);
        }
      });
    }

    var btnCloseIsland = document.getElementById('btnCloseIsland');
    if (btnCloseIsland) {
      btnCloseIsland.addEventListener('click', function(e) {
        e.stopPropagation();
        isExpanded = false;
        setIslandState(currentIslandMode);
      });
    }

    // 3. Pixel Equalizer & Beat Pulse
    function animateEq() {
      var bars = document.querySelectorAll('.pixel-eq-bar');
      for (var i = 0; i < bars.length; i++) {
        var h = Math.floor(Math.random() * 14) + 4;
        bars[i].style.height = h + 'px';
      }
      if (beatPulseEnabled && currentIslandMode === 'music' && Math.random() > 0.65) {
        var island = document.getElementById('liveIsland');
        if (island && !isExpanded) {
          island.className = 'dynamic-island state-' + currentIslandMode + getGlowClasses() + ' beat-pulse';
          setTimeout(function() {
            if (island) island.className = 'dynamic-island state-' + currentIslandMode + getGlowClasses();
          }, 140);
        }
      }
    }
    setInterval(animateEq, 160);

    // 4. Timer
    function formatTimerTime(sec) {
      var m = Math.floor(sec / 60);
      var s = sec % 60;
      return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }
    function startTimer() {
      if (timerInterval) clearInterval(timerInterval);
      timerInterval = setInterval(function() {
        if (timerSeconds > 0) {
          timerSeconds--;
          var text = document.getElementById('islandModeText');
          if (text && currentIslandMode === 'timer') text.textContent = formatTimerTime(timerSeconds);
        } else {
          clearInterval(timerInterval);
          playTimerBell();
          showToast('⏱️ TIMER FINISHED!');
        }
      }, 1000);
    }
    function stopTimer() {
      if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
    }

    // 5. Audio Bell
    function playTimerBell() {
      try {
        var AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) return;
        if (!audioCtx) audioCtx = new AudioContextClass();
        if (audioCtx.state === 'suspended') audioCtx.resume();
        var osc = audioCtx.createOscillator();
        var gain = audioCtx.createGain();
        osc.type = 'square'; // retro 8-bit sound
        osc.frequency.setValueAtTime(880, audioCtx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(440, audioCtx.currentTime + 0.4);
        gain.gain.setValueAtTime(0.2, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.4);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.4);
        showToast('🔔 CHIME BELL PLAYED');
      } catch (e) {
        console.log(e);
      }
    }

    // 6. Toggles
    function toggleRainbowMode() {
      rainbowActive = !rainbowActive;
      var btn = document.getElementById('btnToggleRainbow');
      if (btn) {
        btn.textContent = rainbowActive ? 'ON' : 'OFF';
        btn.className = rainbowActive ? 'pixel-switch active' : 'pixel-switch';
      }
      setIslandState(currentIslandMode);
      showToast(rainbowActive ? 'RAINBOW MODE ON' : 'RAINBOW MODE OFF');
    }

    function toggleBlinkMode() {
      blinkActive = !blinkActive;
      var btn = document.getElementById('btnToggleBlink');
      if (btn) {
        btn.textContent = blinkActive ? 'ON' : 'OFF';
        btn.className = blinkActive ? 'pixel-switch active' : 'pixel-switch';
      }
      setIslandState(currentIslandMode);
      showToast(blinkActive ? '1S BREATHING GLOW ON' : 'BREATHING GLOW OFF');
    }

    function toggleBeatPulse() {
      beatPulseEnabled = !beatPulseEnabled;
      var btn = document.getElementById('btnToggleBeat');
      if (btn) {
        btn.textContent = beatPulseEnabled ? 'ON' : 'OFF';
        btn.className = beatPulseEnabled ? 'pixel-switch active' : 'pixel-switch';
      }
      showToast(beatPulseEnabled ? 'BEAT PULSE ON' : 'BEAT PULSE OFF');
    }

    // 7. Camera Visualizer
    function setFpsDemo(fps) {
      var block = document.getElementById('camBlock');
      var b60 = document.getElementById('btnFps60');
      var b30 = document.getElementById('btnFps30');
      if (!block) return;
      if (fps === 60) {
        block.className = 'cam-block fps-60';
        b60.className = 'px-btn-sm active';
        b30.className = 'px-btn-sm';
        showToast('60 FPS PREVIEW ACTIVE');
      } else {
        block.className = 'cam-block fps-30';
        b60.className = 'px-btn-sm';
        b30.className = 'px-btn-sm active';
        showToast('30 FPS STOCK PREVIEW');
      }
    }

    // 8. Toast
    var toastTimeout = null;
    function showToast(msg) {
      var toast = document.getElementById('toastMsg');
      if (!toast) return;
      toast.textContent = msg;
      toast.className = 'toast-msg show';
      if (toastTimeout) clearTimeout(toastTimeout);
      toastTimeout = setTimeout(function() {
        toast.className = 'toast-msg';
      }, 2200);
    }

    function copyRepoUrl() {
      var repoUrl = 'https://abulhketus-collab.github.io/repo/';
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(repoUrl).then(function() {
          showToast('URL COPIED!');
        });
      } else {
        var input = document.createElement('input');
        input.value = repoUrl;
        document.body.appendChild(input);
        input.select();
        document.execCommand('copy');
        document.body.removeChild(input);
        showToast('URL COPIED!');
      }
    }

    function handleDebDownload(e, name) {
      showToast('DOWNLOADING ' + name + ' (PURE GNU TAR)...');
    }

    // ==============================================
    // 9. USER PHONE WALKTHROUGH ENGINE (HDJDJW.HTML)
    // ==============================================
    (function(){
      var D = [4, 5, 7, 4], T = 20;
      var sc = document.querySelectorAll('.user-scene');
      var dt = document.querySelectorAll('.u-dot');
      var fl = document.getElementById('uFill');
      var w = document.getElementById('uWrap');
      var pB = document.getElementById('pBtn');
      var rB = document.getElementById('rBtn');
      var uB = document.getElementById('uBox');
      var cB = document.getElementById('cBtn');
      var cur = 0, el = 0, pz = false, fin = false, lt = 0, tk = null;

      function render(){
        var idx = 3, acc = 0;
        for (var i = 0; i < 4; i++) {
          acc += D[i] * 1000;
          if (el < acc) { idx = i; break; }
        }
        cur = idx;
        for (var k = 0; k < 4; k++) {
          if (sc[k]) sc[k].className = (k === idx ? 'user-scene active' : 'user-scene');
          if (dt[k]) dt[k].className = (k === idx ? 'u-dot active' : 'u-dot');
        }
        if (fl) fl.style.width = Math.min(100, el / (T * 1000) * 100) + '%';
      }

      function tick(){
        var n = performance.now();
        if (!lt) lt = n;
        var d = Math.min(500, Math.max(0, n - lt));
        lt = n;
        if (!pz && !fin) {
          el += d;
          if (el >= T * 1000) { el = T * 1000; fin = true; }
          render();
        }
      }

      function start(){
        if (tk) clearInterval(tk);
        lt = 0;
        tk = setInterval(tick, 100);
      }
      function stop(){
        if (tk) { clearInterval(tk); tk = null; }
      }
      function ui(){
        if (pB) pB.textContent = pz ? 'RESUME' : 'PAUSE';
      }
      function go(i){
        if (i < 0 || i > 3) return;
        var o = 0;
        for (var k = 0; k < i; k++) o += D[k] * 1000;
        el = o; fin = false; pz = false; lt = 0;
        render(); ui();
        if (!tk) start();
      }
      function reset(){
        stop(); cur = 0; el = 0; pz = false; fin = false; lt = 0;
        render(); ui(); start();
      }

      // Gestures
      var sx = 0, sy = 0, sw = 0, ax = null;
      function st(x, y){ sx = x; sy = y; sw = 1; ax = null; }
      function mv(x, y){
        if (!sw) return;
        var dx = x - sx, dy = y - sy;
        if (ax === null && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
          ax = Math.abs(dx) > Math.abs(dy) ? 'x' : 'y';
        }
      }
      function en(x, y){
        if (!sw) return;
        sw = 0;
        var dx = x - sx;
        if (ax === 'x' && Math.abs(dx) > 50) go(dx < 0 ? cur + 1 : cur - 1);
        ax = null;
      }

      if (w) {
        w.addEventListener('touchstart', function(e){ st(e.touches[0].clientX, e.touches[0].clientY); }, { passive: true });
        w.addEventListener('touchmove', function(e){ mv(e.touches[0].clientX, e.touches[0].clientY); }, { passive: true });
        w.addEventListener('touchend', function(e){ en(e.changedTouches[0].clientX, e.changedTouches[0].clientY); }, { passive: true });
      }

      if (pB) {
        pB.addEventListener('click', function(){
          if (pz) {
            if (fin) { reset(); return; }
            pz = false; lt = 0; ui();
            if (!tk) start();
          } else {
            if (fin) return;
            pz = true; ui();
          }
        });
      }
      if (rB) rB.addEventListener('click', reset);

      for (var d = 0; d < 4; d++) {
        (function(b, idx){
          if (b) b.addEventListener('click', function(){ go(idx); });
        })(dt[d], d);
      }

      if (uB) uB.addEventListener('click', copyRepoUrl);
      if (cB) cB.addEventListener('click', copyRepoUrl);

      start();
    })();
  </script>
</body>
</html>
