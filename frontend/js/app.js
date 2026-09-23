/**
 * AgriMind Frontend Application
 * Conversational Agricultural Requirement System
 */

'use strict';

// ─── App State ──────────────────────────────────────────────────────────────
const state = {
  sessionId: generateSessionId(),
  messages: [],
  slots: {},
  conflicts: [],
  completionPct: 0,
  isComplete: false,
  isSending: false,
  isRecording: false,
  recognition: null,
  recognitionEn: null,
  voiceLangMode: 'auto',  // 'auto' | 'tamil' | 'english'
  currentDrawerReqId: null,
  allRequirements: [],
  llmProvider: 'local',
  selectedProvider: 'local',
};

const API_BASE = '/api';

// ─── Slot Definitions ────────────────────────────────────────────────────────
const SLOT_META = {
  land_size:           { label: 'Land Area',         icon: '🌱', required: true },
  land_unit:           { label: 'Unit',               icon: '📏', required: true },
  crop_types:          { label: 'Crops',              icon: '🌾', required: true },
  water_source:        { label: 'Water Source',       icon: '💧', required: true },
  motor_hp:            { label: 'Motor HP',           icon: '⚡', required: true },
  irrigation_type:     { label: 'Irrigation Type',   icon: '🚿', required: true },
  soil_type:           { label: 'Soil Type',          icon: '🪨', required: false },
  borewell_depth_ft:   { label: 'Borewell Depth',    icon: '🕳️', required: false },
  open_well_depth_ft:  { label: 'Well Depth',         icon: '🪣', required: false },
  power_supply_phase:  { label: 'Power Phase',        icon: '🔌', required: false },
  power_hours_per_day: { label: 'Power Hours/Day',   icon: '🕐', required: false },
  district:            { label: 'District',            icon: '📍', required: false },
  budget_inr:          { label: 'Budget (₹)',          icon: '💰', required: false },
};

// ─── Init ────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  initChat();
  renderSlotTracker();
  setupVoiceInput();
  setupInputAutoResize();
  loadLLMConfig();
});

// ─── Session ─────────────────────────────────────────────────────────────────
function generateSessionId() {
  return 'agm-' + Date.now().toString(36) + '-' + Math.random().toString(36).substr(2, 6);
}

// ─── Tab Switching ────────────────────────────────────────────────────────────
function switchTab(tab) {
  document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-tab').forEach(t => {
    t.classList.remove('active');
    t.setAttribute('aria-selected', 'false');
  });

  document.getElementById(`panel-${tab}`).classList.add('active');
  const btn = document.getElementById(`tab-${tab}`);
  btn.classList.add('active');
  btn.setAttribute('aria-selected', 'true');

  if (tab === 'dashboard') {
    loadDashboard();
  }
}

// ─── Chat Initialization ──────────────────────────────────────────────────────
function initChat() {
  const greetingMsg = `👋 Welcome to AgriMind! I'm your AI agricultural assistant.

I can understand Tamil, English, and Tanglish (Tamil-English mix). Tell me about your farm — land area, crops, water source, motor, and irrigation needs — and I'll help you create a verified technical requirement report for your irrigation infrastructure.

Try a quick prompt below or type naturally!`;

  appendMessage('assistant', greetingMsg);
}

// ─── Message Rendering ────────────────────────────────────────────────────────
function appendMessage(role, text, animate = true) {
  const container = document.getElementById('chat-messages');

  const msgEl = document.createElement('div');
  msgEl.className = `message ${role}`;

  const avatar = document.createElement('div');
  avatar.className = 'msg-avatar';
  avatar.textContent = role === 'assistant' ? '🤖' : '👤';
  avatar.setAttribute('aria-hidden', 'true');

  const bubble = document.createElement('div');
  bubble.className = 'msg-bubble';
  bubble.textContent = text;

  msgEl.appendChild(avatar);
  msgEl.appendChild(bubble);

  if (!animate) msgEl.style.animation = 'none';

  container.appendChild(msgEl);
  container.scrollTop = container.scrollHeight;

  state.messages.push({ role, text });
}

function showTypingIndicator() {
  const container = document.getElementById('chat-messages');
  const indicator = document.createElement('div');
  indicator.className = 'message assistant';
  indicator.id = 'typing-indicator';

  const avatar = document.createElement('div');
  avatar.className = 'msg-avatar';
  avatar.textContent = '🤖';
  avatar.setAttribute('aria-hidden', 'true');

  const bubble = document.createElement('div');
  bubble.className = 'msg-bubble';
  bubble.innerHTML = `<div class="typing-indicator">
    <div class="typing-dot"></div>
    <div class="typing-dot"></div>
    <div class="typing-dot"></div>
  </div>`;

  indicator.appendChild(avatar);
  indicator.appendChild(bubble);
  container.appendChild(indicator);
  container.scrollTop = container.scrollHeight;
}

function removeTypingIndicator() {
  const el = document.getElementById('typing-indicator');
  if (el) el.remove();
}

// ─── Send Message ─────────────────────────────────────────────────────────────
async function sendMessage() {
  const input = document.getElementById('chat-input');
  const text = input.value.trim();
  if (!text || state.isSending) return;

  input.value = '';
  input.style.height = 'auto';
  document.getElementById('char-count').textContent = '';

  appendMessage('user', text);
  state.isSending = true;
  document.getElementById('send-btn').disabled = true;
  showTypingIndicator();

  try {
    const resp = await fetch(`${API_BASE}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        session_id: state.sessionId,
        message: text,
        language: 'auto',
        llm_provider: state.llmProvider,
      }),
    });

    if (!resp.ok) throw new Error(`Server error: ${resp.status}`);
    const data = await resp.json();

    removeTypingIndicator();
    appendMessage('assistant', data.reply);

    // Update state
    state.slots = data.extracted_slots || {};
    state.conflicts = data.conflicts || [];
    state.completionPct = data.completion_pct || 0;
    state.isComplete = data.is_complete || false;

    // Update UI
    updateLanguageBadge(data.language_detected, data.extracted_slots?._extraction_method);
    renderSlotTracker();
    renderConflicts();
    updateSubmitButton();

    // Show completion toast if done
    if (state.isComplete && !state._completionToastShown) {
      state._completionToastShown = true;
      showToast('✅ All required details collected! Please fill your name and submit.', 'success');
    }

  } catch (err) {
    removeTypingIndicator();
    appendMessage('assistant', `⚠️ I couldn't connect to the server. Please make sure AgriMind is running on http://localhost:8000\n\nError: ${err.message}`);
    showToast('Connection error. Is the server running?', 'error');
  } finally {
    state.isSending = false;
    document.getElementById('send-btn').disabled = false;
    input.focus();
  }
}

function sendQuickPrompt(el) {
  const text = el.textContent.trim();
  document.getElementById('chat-input').value = text;
  sendMessage();
}

// ─── Language Badge ───────────────────────────────────────────────────────────
function updateLanguageBadge(lang, method) {
  const langEl = document.getElementById('detected-lang-badge');
  const methodEl = document.getElementById('method-badge');

  const langMap = { tamil: '🇮🇳 Tamil', tanglish: '🔀 Tanglish', english: '🇬🇧 English' };
  langEl.textContent = langMap[lang] || lang;

  const methodMap = {
    gemini: '✨ Gemini',
    openai: '🤖 GPT',
    rule_based: '🔧 Local'
  };
  methodEl.textContent = methodMap[method] || method || 'Local';
}

// ─── Slot Tracker ─────────────────────────────────────────────────────────────
function renderSlotTracker() {
  const listEl = document.getElementById('slot-list');
  const pctEl  = document.getElementById('ring-pct');
  const txtEl  = document.getElementById('completion-text');
  const ring   = document.getElementById('ring-progress');

  const pct = state.completionPct;
  const circumference = 283;
  const offset = circumference - (pct / 100) * circumference;

  ring.style.strokeDashoffset = offset;
  pctEl.textContent = `${Math.round(pct)}%`;
  txtEl.textContent = `${Math.round(pct)}%`;

  const entries = Object.entries(SLOT_META);
  listEl.innerHTML = entries.map(([key, meta]) => {
    const value = state.slots[key];
    const filled = value !== null && value !== undefined;
    const displayVal = Array.isArray(value) ? value.join(', ') :
                       key === 'budget_inr' ? `₹${Number(value).toLocaleString('en-IN')}` :
                       key === 'borewell_depth_ft' || key === 'open_well_depth_ft' ? `${value} ft` :
                       key === 'motor_hp' ? `${value} HP` :
                       key === 'power_hours_per_day' ? `${value}h/day` :
                       String(value || '');

    return `<div class="slot-item ${filled ? 'filled' : 'missing'}" title="${meta.label}: ${filled ? displayVal : 'Not yet provided'}">
      <span class="slot-icon" aria-hidden="true">${meta.icon}</span>
      <span class="slot-label">${meta.label}${meta.required ? ' *' : ''}</span>
      ${filled ? `<span class="slot-value" title="${displayVal}">${displayVal}</span>` : ''}
    </div>`;
  }).join('');
}

// ─── Conflict Rendering ───────────────────────────────────────────────────────
function renderConflicts() {
  const card = document.getElementById('conflicts-card');
  const list = document.getElementById('conflict-list');
  const count = document.getElementById('conflict-count');

  if (!state.conflicts || state.conflicts.length === 0) {
    card.style.display = 'none';
    return;
  }

  card.style.display = 'block';
  count.textContent = `${state.conflicts.length} issue${state.conflicts.length > 1 ? 's' : ''}`;

  list.innerHTML = state.conflicts.map(c => `
    <div class="conflict-item ${c.severity}">
      <div class="conflict-type">
        ${c.severity === 'high' ? '🔴' : c.severity === 'medium' ? '🟡' : '🔵'}
        ${c.type.replace(/_/g, ' ').toUpperCase()}
      </div>
      <div style="margin-bottom:0.3rem;font-size:0.76rem">${c.message}</div>
      <div style="font-size:0.72rem;opacity:0.85">💡 ${c.recommendation}</div>
    </div>
  `).join('');
}

// ─── Submit — opens PDF Preview modal first ───────────────────────────────────
function updateSubmitButton() {
  const btn = document.getElementById('submit-btn');
  btn.disabled = !state.isComplete;
}

function submitRequirement() {
  // Open preview instead of submitting directly
  openPDFPreview();
}

function openPDFPreview() {
  const modal = document.getElementById('pdf-preview-modal');
  const tbody = document.getElementById('preview-table-body');
  const missingWarn = document.getElementById('preview-missing-warning');
  const missingList = document.getElementById('preview-missing-list');
  const scoreSection = document.getElementById('preview-score-section');

  // Pre-fill name/phone from form if already entered
  const existingName = document.getElementById('farmer-name')?.value?.trim();
  const existingPhone = document.getElementById('farmer-phone')?.value?.trim();
  if (existingName) document.getElementById('preview-name').value = existingName;
  if (existingPhone) document.getElementById('preview-phone').value = existingPhone;

  // Build table rows
  const rows = Object.entries(SLOT_META).map(([key, meta]) => {
    const value = state.slots[key];
    const filled = value !== null && value !== undefined;
    let displayVal = '';
    if (filled) {
      displayVal = Array.isArray(value) ? value.join(', ')
        : key === 'budget_inr' ? `₹${Number(value).toLocaleString('en-IN')}`
        : key === 'borewell_depth_ft' || key === 'open_well_depth_ft' ? `${value} ft`
        : key === 'motor_hp' ? `${value} HP`
        : key === 'power_hours_per_day' ? `${value} h/day`
        : String(value);
    }
    const statusIcon = filled
      ? '<span style="color:#10b981">&#10003; Captured</span>'
      : meta.required
      ? '<span style="color:#f87171">&#10007; Missing (required)</span>'
      : '<span style="color:#9ca3af">&#8211; Optional</span>';

    return `<tr>
      <td>${meta.icon} ${meta.label}${meta.required ? ' <sup style="color:#f87171">*</sup>' : ''}</td>
      <td>${filled ? `<strong>${displayVal}</strong>` : '<em style="opacity:0.5">Not provided</em>'}</td>
      <td>${statusIcon}</td>
    </tr>`;
  }).join('');
  tbody.innerHTML = rows;

  // Missing fields warning
  const requiredSlots = Object.entries(SLOT_META)
    .filter(([k, m]) => m.required && (state.slots[k] == null || state.slots[k] === ''))
    .map(([k, m]) => m.label);

  if (requiredSlots.length > 0) {
    missingWarn.style.display = 'flex';
    missingList.textContent = requiredSlots.join(', ');
  } else {
    missingWarn.style.display = 'none';
  }

  // Feasibility score
  if (state.completionPct > 0) {
    scoreSection.style.display = 'block';
    const badge = document.getElementById('preview-score-badge');
    badge.textContent = `${Math.round(state.completionPct)}%`;
    badge.style.background = state.completionPct >= 70 ? '#10b981' : state.completionPct >= 40 ? '#f59e0b' : '#ef4444';
  }

  modal.style.display = 'flex';
  document.body.style.overflow = 'hidden';
  document.getElementById('preview-name').focus();
}

function closePDFPreview() {
  document.getElementById('pdf-preview-modal').style.display = 'none';
  document.body.style.overflow = '';
}

async function confirmAndSubmit() {
  const name = document.getElementById('preview-name').value.trim();
  const phone = document.getElementById('preview-phone').value.trim();

  if (!name) {
    showToast('Please enter your name before generating the report.', 'warning');
    document.getElementById('preview-name').focus();
    return;
  }

  const generateBtn = document.getElementById('preview-generate-btn');
  generateBtn.disabled = true;
  generateBtn.innerHTML = '&#9203; Generating & Submitting...';

  try {
    const resp = await fetch(`${API_BASE}/requirements/submit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        session_id: state.sessionId,
        farmer_name: name,
        farmer_phone: phone || null,
        confirm: true,
      }),
    });

    if (!resp.ok) throw new Error(`Server error: ${resp.status}`);
    const data = await resp.json();

    closePDFPreview();

    appendMessage('assistant',
      `✅ Thank you, ${name}! Your requirement has been submitted successfully.\n\n` +
      `📋 Report ID: AGM-${String(data.requirement_id).padStart(4,'0')}\n` +
      `📈 Feasibility Score: ${data.feasibility_score}/100\n` +
      `${data.conflicts_count > 0 ? `⚠️ ${data.conflicts_count} engineering concern(s) flagged for review\n` : '✅ No engineering conflicts detected\n'}` +
      `📄 PDF report generated and sent to the admin dashboard.\n\n` +
      `Our team will contact you within 24 hours.${phone ? ' We will call you on ' + phone + '.' : ''}`
    );

    showToast(`Report AGM-${String(data.requirement_id).padStart(4,'0')} submitted! ✅`, 'success');

    // Update submit button
    const btn = document.getElementById('submit-btn');
    if (btn) { btn.textContent = '✅ Submitted!'; btn.disabled = true; }

  } catch (err) {
    generateBtn.disabled = false;
    generateBtn.innerHTML = '&#128640; Generate Report &amp; Submit';
    showToast('Submission failed. Check server connection.', 'error');
  }
}

function startNewChat() {
  state.sessionId = generateSessionId();
  state.slots = {};
  state.conflicts = [];
  state.completionPct = 0;
  state.isComplete = false;
  state._completionToastShown = false;

  document.getElementById('chat-messages').innerHTML = '';
  document.getElementById('farmer-name').value = '';
  document.getElementById('farmer-phone').value = '';
  document.getElementById('conflicts-card').style.display = 'none';

  renderSlotTracker();
  updateSubmitButton();
  initChat();
  showToast('New conversation started.', 'info');
}

// ─── Voice Input ──────────────────────────────────────────────────────────────
function setupVoiceInput() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) {
    document.getElementById('voice-btn').style.display = 'none';
    return;
  }

  // Create two recognizers: Tamil and English
  function makeRecognizer(lang) {
    const r = new SpeechRecognition();
    r.continuous = false;
    r.interimResults = true;
    r.lang = lang;
    return r;
  }

  state.recognition   = makeRecognizer('ta-IN');
  state.recognitionEn = makeRecognizer('en-IN');

  function onResult(preferred, fallback) {
    return (e) => {
      let transcript = '';
      for (const result of e.results) {
        transcript += result[0].transcript;
      }
      // Only commit if this result is longer (more confident)
      const current = document.getElementById('chat-input').value;
      if (transcript.length >= current.length) {
        document.getElementById('chat-input').value = transcript;
      }
    };
  }

  function onEnd(label) {
    return () => {
      // Check if both are done
      state._voiceDoneCount = (state._voiceDoneCount || 0) + 1;
      if (state._voiceDoneCount >= state._voiceStartedCount || state._voiceDoneCount >= 2) {
        const btn = document.getElementById('voice-btn');
        btn.classList.remove('recording');
        btn.textContent = '🎤';
        state.isRecording = false;
        document.getElementById('voice-status').textContent = '';
        document.getElementById('voice-waveform').classList.remove('active');

        const text = document.getElementById('chat-input').value.trim();
        if (text) sendMessage();
      }
    };
  }

  function onError(e) {
    if (e.error !== 'aborted' && e.error !== 'no-speech') {
      showToast(`Voice error: ${e.error}`, 'warning');
    }
    // Let onEnd handle cleanup
  }

  state.recognition.onresult   = onResult('ta-IN', 'en-IN');
  state.recognitionEn.onresult = onResult('en-IN', 'ta-IN');
  state.recognition.onend   = onEnd('Tamil');
  state.recognitionEn.onend = onEnd('English');
  state.recognition.onerror   = onError;
  state.recognitionEn.onerror = onError;
}

function setVoiceLang(mode) {
  state.voiceLangMode = mode;
  document.querySelectorAll('.lang-toggle-btn').forEach(b => {
    b.classList.remove('active');
    b.setAttribute('aria-pressed', 'false');
  });
  const btn = document.getElementById(`lang-${mode}`);
  if (btn) { btn.classList.add('active'); btn.setAttribute('aria-pressed', 'true'); }
}

function toggleVoice() {
  if (!state.recognition) {
    showToast('Voice input is not supported in this browser.', 'warning');
    return;
  }

  const btn = document.getElementById('voice-btn');
  const status = document.getElementById('voice-status');
  const waveform = document.getElementById('voice-waveform');

  if (state.isRecording) {
    try { state.recognition.stop(); } catch(e){}
    try { if (state.recognitionEn) state.recognitionEn.stop(); } catch(e){}
    btn.classList.remove('recording');
    btn.textContent = '🎤';
    state.isRecording = false;
    status.textContent = '';
    waveform.classList.remove('active');
  } else {
    document.getElementById('chat-input').value = '';
    state._voiceDoneCount = 0;

    const mode = state.voiceLangMode;
    let startedCount = 0;

    if (mode === 'auto' || mode === 'tamil') {
      try { state.recognition.start(); startedCount++; } catch(e){}
    }
    if (mode === 'auto' || mode === 'english') {
      // Small delay so browser doesn't reject dual start
      setTimeout(() => {
        try { state.recognitionEn.start(); } catch(e){}
      }, 80);
      startedCount++;
    }

    state._voiceStartedCount = startedCount;
    btn.classList.add('recording');
    btn.textContent = '⏹';
    state.isRecording = true;
    waveform.classList.add('active');

    const langLabel = mode === 'tamil' ? 'Tamil' : mode === 'english' ? 'English' : 'Tamil + English';
    status.textContent = `🎙️ Listening (${langLabel})...`;
  }
}

// ─── Input Auto-resize ────────────────────────────────────────────────────────
function setupInputAutoResize() {
  const input = document.getElementById('chat-input');

  input.addEventListener('input', () => {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 120) + 'px';
    const chars = input.value.length;
    document.getElementById('char-count').textContent = chars > 50 ? `${chars} chars` : '';
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });
}

// ─── Dashboard ────────────────────────────────────────────────────────────────
async function loadDashboard() {
  try {
    const [statsResp, reqResp] = await Promise.all([
      fetch(`${API_BASE}/stats`),
      fetch(`${API_BASE}/requirements?limit=100`),
    ]);

    if (!statsResp.ok || !reqResp.ok) throw new Error('Failed to load data');

    const stats = await statsResp.json();
    const reqData = await reqResp.json();

    // Update KPIs
    document.getElementById('kpi-total').textContent   = stats.total_requirements;
    document.getElementById('kpi-pending').textContent = stats.pending;
    document.getElementById('kpi-review').textContent  = stats.under_review;
    document.getElementById('kpi-feasible').textContent= stats.feasible;
    document.getElementById('kpi-quoted').textContent  = stats.quoted;
    document.getElementById('kpi-score').textContent   = stats.avg_feasibility_score > 0
      ? `${stats.avg_feasibility_score}%` : '—';

    state.allRequirements = reqData.items || [];
    renderRequirementsTable(state.allRequirements);

  } catch (err) {
    console.error('Dashboard load error:', err);
    showToast('Could not load dashboard data. Is the server running?', 'error');
  }
}

function renderRequirementsTable(items) {
  const tbody = document.getElementById('requirements-tbody');

  if (!items || items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="9">
      <div class="empty-state">
        <div class="empty-icon">🌾</div>
        <div class="empty-text">No requirements found. Submit one from the Farmer Portal!</div>
      </div>
    </td></tr>`;
    return;
  }

  tbody.innerHTML = items.map(req => {
    const crops = Array.isArray(req.crop_types) ? req.crop_types.join(', ') : req.crop_types || '—';
    const land = req.land_size ? `${req.land_size} ${req.land_unit || 'acres'}` : '—';
    const score = req.feasibility_score || 0;
    const scoreClass = score >= 75 ? 'high' : score >= 50 ? 'medium' : 'low';
    const scoreColor = score >= 75 ? 'var(--emerald-400)' : score >= 50 ? 'var(--amber-500)' : 'var(--red-600)';
    const conflictCount = Array.isArray(req.conflicts) ? req.conflicts.length : 0;
    const dateStr = req.created_at ? new Date(req.created_at).toLocaleDateString('en-IN', { day:'2-digit', month:'short' }) : '—';

    return `<tr onclick="openDrawer(${req.id})" role="button" tabindex="0" aria-label="View requirement ${req.id}">
      <td>
        <span style="font-family:var(--font-display);font-weight:700;color:var(--emerald-400)">AGM-${String(req.id).padStart(4,'0')}</span>
        <div style="font-size:0.7rem;color:var(--text-muted)">${dateStr}</div>
      </td>
      <td>
        <div style="font-weight:600">${req.farmer_name || 'Anonymous'}</div>
        ${req.farmer_phone ? `<div class="text-sm text-muted">${req.farmer_phone}</div>` : ''}
      </td>
      <td>${req.district || '—'}</td>
      <td>${land}</td>
      <td>
        <span title="${crops}" style="max-width:120px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;display:block">${crops}</span>
      </td>
      <td>${req.irrigation_type || '—'}</td>
      <td>
        <div class="score-bar-wrap">
          <div class="score-bar">
            <div class="score-fill ${scoreClass}" style="width:${score}%"></div>
          </div>
          <span class="score-val" style="color:${scoreColor}">${score}%</span>
        </div>
        ${conflictCount > 0 ? `<div style="font-size:0.68rem;color:var(--amber-500);margin-top:2px">⚠️ ${conflictCount} conflict${conflictCount > 1 ? 's' : ''}</div>` : ''}
      </td>
      <td><span class="status-badge ${req.status || 'pending'}">${(req.status || 'pending').replace('_', ' ')}</span></td>
      <td onclick="event.stopPropagation()">
        <div style="display:flex;gap:0.4rem;flex-wrap:nowrap">
          <button class="btn-sm review" onclick="openDrawer(${req.id})" aria-label="View details for AGM-${req.id}">View</button>
          <button class="btn-sm download" onclick="downloadPDFById(${req.id})" aria-label="Download PDF for AGM-${req.id}">📄</button>
        </div>
      </td>
    </tr>`;
  }).join('');
}

function filterTable() {
  const search = document.getElementById('dashboard-search').value.toLowerCase();
  const status = document.getElementById('status-filter').value;

  const filtered = state.allRequirements.filter(req => {
    const matchSearch = !search ||
      (req.farmer_name || '').toLowerCase().includes(search) ||
      (req.district || '').toLowerCase().includes(search) ||
      (req.irrigation_type || '').toLowerCase().includes(search) ||
      (Array.isArray(req.crop_types) ? req.crop_types.join(' ') : '').toLowerCase().includes(search);

    const matchStatus = !status || req.status === status;
    return matchSearch && matchStatus;
  });

  renderRequirementsTable(filtered);
}

function filterByStatus(status) {
  document.getElementById('status-filter').value = status;
  switchTab('dashboard');
  filterTable();
}

// ─── Detail Drawer ────────────────────────────────────────────────────────────
async function openDrawer(reqId) {
  state.currentDrawerReqId = reqId;

  document.getElementById('drawer-overlay').classList.add('open');
  document.getElementById('detail-drawer').classList.add('open');
  document.getElementById('drawer-title').textContent = `AGM-${String(reqId).padStart(4,'0')}`;
  document.getElementById('drawer-subtitle').textContent = 'Loading...';
  document.getElementById('drawer-body').innerHTML = '<div class="empty-state"><div class="empty-icon">⏳</div><div class="empty-text">Loading details...</div></div>';

  try {
    const resp = await fetch(`${API_BASE}/requirements/${reqId}`);
    if (!resp.ok) throw new Error('Not found');
    const req = await resp.json();

    renderDrawerContent(req);
    document.getElementById('drawer-status-select').value = req.status || 'pending';
    document.getElementById('drawer-subtitle').textContent = `${req.farmer_name || 'Unknown'} · ${req.district || 'N/A'}`;

  } catch (err) {
    document.getElementById('drawer-body').innerHTML =
      `<div class="empty-state"><div class="empty-text">Failed to load: ${err.message}</div></div>`;
  }
}

function renderDrawerContent(req) {
  const crops = Array.isArray(req.crop_types) ? req.crop_types.join(', ') : req.crop_types || 'N/A';
  const score = req.feasibility_score || 0;
  const scoreColor = score >= 75 ? 'var(--emerald-400)' : score >= 50 ? 'var(--amber-500)' : 'var(--red-600)';
  const conflicts = req.conflicts || [];
  const details = req.feasibility_details || {};

  document.getElementById('drawer-body').innerHTML = `
    <!-- Farmer -->
    <div class="detail-section">
      <div class="detail-section-title">🧑‍🌾 Farmer Profile</div>
      <div class="detail-grid">
        <div class="detail-item"><div class="detail-item-label">Name</div><div class="detail-item-value">${req.farmer_name || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Phone</div><div class="detail-item-value">${req.farmer_phone || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">District</div><div class="detail-item-value">${req.district || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Language</div><div class="detail-item-value">${(req.language || 'English').charAt(0).toUpperCase() + (req.language || 'english').slice(1)}</div></div>
      </div>
    </div>

    <!-- Farm Specs -->
    <div class="detail-section">
      <div class="detail-section-title">🌱 Farm Specifications</div>
      <div class="detail-grid">
        <div class="detail-item"><div class="detail-item-label">Land Area</div><div class="detail-item-value">${req.land_size ? `${req.land_size} ${req.land_unit || 'acres'}` : 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Crops</div><div class="detail-item-value">${crops}</div></div>
        <div class="detail-item"><div class="detail-item-label">Soil Type</div><div class="detail-item-value">${req.soil_type || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Irrigation</div><div class="detail-item-value">${req.irrigation_type || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Budget</div><div class="detail-item-value">${req.budget_inr ? `₹${Number(req.budget_inr).toLocaleString('en-IN')}` : 'N/A'}</div></div>
      </div>
    </div>

    <!-- Water & Power -->
    <div class="detail-section">
      <div class="detail-section-title">💧 Water & Power</div>
      <div class="detail-grid">
        <div class="detail-item"><div class="detail-item-label">Water Source</div><div class="detail-item-value">${req.water_source || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Borewell Depth</div><div class="detail-item-value">${req.borewell_depth_ft ? `${req.borewell_depth_ft} ft` : req.open_well_depth_ft ? `${req.open_well_depth_ft} ft (open)` : 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Motor HP</div><div class="detail-item-value">${req.motor_hp ? `${req.motor_hp} HP` : 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Power Phase</div><div class="detail-item-value">${req.power_supply_phase || 'N/A'}</div></div>
        <div class="detail-item"><div class="detail-item-label">Power Hours/Day</div><div class="detail-item-value">${req.power_hours_per_day ? `${req.power_hours_per_day}h` : 'N/A'}</div></div>
      </div>
    </div>

    <!-- Feasibility -->
    <div class="detail-section">
      <div class="detail-section-title">📈 Feasibility Assessment</div>
      <div style="background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:var(--radius-md);padding:1rem;margin-bottom:0.75rem">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:0.75rem">
          <span style="font-size:0.85rem;font-weight:600">Overall Score</span>
          <span style="font-family:var(--font-display);font-size:1.5rem;font-weight:800;color:${scoreColor}">${score}/100</span>
        </div>
        <div class="score-bar" style="height:10px">
          <div class="score-fill ${score>=75?'high':score>=50?'medium':'low'}" style="width:${score}%"></div>
        </div>
      </div>
      ${Object.entries(details).map(([k,v]) => `
        <div style="display:flex;justify-content:space-between;padding:0.4rem 0;border-bottom:1px solid rgba(255,255,255,0.04);font-size:0.8rem">
          <span style="color:var(--text-muted)">${k.replace(/_/g,' ').replace(/\b\w/g,c=>c.toUpperCase())}</span>
          <span style="color:var(--text-primary);font-weight:500;text-align:right;max-width:200px">${v}</span>
        </div>
      `).join('')}
    </div>

    <!-- Conflicts -->
    ${conflicts.length > 0 ? `
    <div class="detail-section">
      <div class="detail-section-title">⚠️ Engineering Conflicts (${conflicts.length})</div>
      <div class="conflict-list">
        ${conflicts.map(c => `
          <div class="conflict-item ${c.severity}">
            <div class="conflict-type">${c.severity === 'high' ? '🔴' : c.severity === 'medium' ? '🟡' : '🔵'} ${(c.type||'').replace(/_/g,' ').toUpperCase()}</div>
            <div style="margin-bottom:0.3rem;font-size:0.78rem">${c.message}</div>
            <div style="font-size:0.72rem;opacity:0.85">💡 ${c.recommendation}</div>
          </div>
        `).join('')}
      </div>
    </div>` : `
    <div class="detail-section">
      <div class="detail-section-title">✅ Engineering Status</div>
      <div style="color:var(--emerald-400);font-size:0.85rem;padding:0.75rem;background:rgba(16,185,129,0.08);border-radius:var(--radius-md);border:1px solid rgba(16,185,129,0.2)">
        No engineering conflicts detected. System specifications are coherent.
      </div>
    </div>`}
  `;
}

function closeDrawer() {
  document.getElementById('drawer-overlay').classList.remove('open');
  document.getElementById('detail-drawer').classList.remove('open');
  state.currentDrawerReqId = null;
}

async function updateDrawerStatus() {
  if (!state.currentDrawerReqId) return;
  const newStatus = document.getElementById('drawer-status-select').value;

  try {
    const resp = await fetch(`${API_BASE}/requirements/${state.currentDrawerReqId}/status`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus }),
    });
    if (!resp.ok) throw new Error('Update failed');

    showToast(`Status updated to: ${newStatus.replace('_', ' ')}`, 'success');

    // Refresh the row in the table
    const req = state.allRequirements.find(r => r.id === state.currentDrawerReqId);
    if (req) req.status = newStatus;
    renderRequirementsTable(state.allRequirements);

  } catch (err) {
    showToast('Status update failed.', 'error');
  }
}

async function downloadPDF() {
  if (!state.currentDrawerReqId) return;
  downloadPDFById(state.currentDrawerReqId);
}

async function downloadPDFById(reqId) {
  showToast('Generating PDF report...', 'info');
  try {
    const url = `${API_BASE}/requirements/${reqId}/pdf`;
    const a = document.createElement('a');
    a.href = url;
    a.download = `AgriMind_Report_AGM-${String(reqId).padStart(4,'0')}.pdf`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    showToast('PDF download started! ✅', 'success');
  } catch (err) {
    showToast('PDF generation failed.', 'error');
  }
}

// ─── LLM Config Modal ─────────────────────────────────────────────────────────
async function loadLLMConfig() {
  try {
    const resp = await fetch(`${API_BASE}/config/llm`);
    if (!resp.ok) return;
    const cfg = await resp.json();
    state.llmProvider = cfg.provider;
    updateLLMBadge(cfg.provider);
    highlightProviderBtn(cfg.provider);
  } catch {}
}

function openLLMModal() {
  document.getElementById('llm-modal').classList.add('open');
}

function closeLLMModal() {
  document.getElementById('llm-modal').classList.remove('open');
}

function selectProvider(provider) {
  state.selectedProvider = provider;
  highlightProviderBtn(provider);

  const keySection = document.getElementById('api-key-section');
  const modelSection = document.getElementById('model-section');

  if (provider === 'local') {
    keySection.style.display = 'none';
    modelSection.style.display = 'none';
  } else {
    keySection.style.display = 'block';
    modelSection.style.display = 'block';
    const placeholder = provider === 'gemini'
      ? 'AIza... (Google Gemini API key)'
      : 'sk-... (OpenAI API key)';
    document.getElementById('api-key-input').placeholder = placeholder;
    document.getElementById('model-input').placeholder = provider === 'gemini'
      ? 'e.g. gemini-1.5-flash'
      : 'e.g. gpt-4o-mini';
  }
}

function highlightProviderBtn(provider) {
  ['local', 'gemini', 'openai'].forEach(p => {
    const btn = document.getElementById(`btn-provider-${p}`);
    btn.classList.toggle('active', p === provider);
    btn.setAttribute('aria-pressed', p === provider ? 'true' : 'false');
  });
}

async function saveLLMConfig() {
  const provider = state.selectedProvider;
  const apiKey  = document.getElementById('api-key-input').value.trim();
  const model   = document.getElementById('model-input').value.trim();

  if (provider !== 'local' && !apiKey) {
    showToast('Please enter your API key.', 'warning');
    return;
  }

  try {
    const resp = await fetch(`${API_BASE}/config/llm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider, api_key: apiKey || null, model: model || null }),
    });

    if (!resp.ok) throw new Error('Config failed');
    const data = await resp.json();

    state.llmProvider = provider;
    updateLLMBadge(provider);
    closeLLMModal();
    showToast(`LLM provider set to ${data.provider} ✅`, 'success');

  } catch (err) {
    showToast('Failed to configure LLM provider.', 'error');
  }
}

function updateLLMBadge(provider) {
  const el = document.getElementById('llm-badge-label');
  const methodEl = document.getElementById('method-badge');
  const labels = { local: 'Local Engine', gemini: 'Google Gemini', openai: 'OpenAI GPT' };
  el.textContent = labels[provider] || provider;
  if (methodEl) {
    const short = { local: '🔧 Local', gemini: '✨ Gemini', openai: '🤖 GPT' };
    methodEl.textContent = short[provider] || provider;
  }
}

// ─── Toast Notifications ──────────────────────────────────────────────────────
function showToast(message, type = 'info', duration = 4000) {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;

  const icons = { success: '✅', error: '❌', info: 'ℹ️', warning: '⚠️' };
  toast.innerHTML = `<span>${icons[type] || 'ℹ️'}</span><span>${message}</span>`;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(20px)';
    toast.style.transition = '0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// ─── Keyboard Navigation ──────────────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeDrawer();
    closeLLMModal();
  }
});

// ─── Drawer keyboard activation ───────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && e.target.getAttribute('role') === 'button') {
    e.target.click();
  }
});
