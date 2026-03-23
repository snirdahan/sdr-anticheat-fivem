// ==========================================
//      SDR ANTICHEAT - Admin Panel JS
// ==========================================

let players     = [];
let detections  = [];
let bans        = [];
let modalCallback = null;

// ==========================================
//  NUI MESSAGE HANDLER
// ==========================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            openPanel(data);
            break;
        case 'close':
            closePanel();
            break;
        case 'updatePlayers':
            players = data.players || [];
            renderPlayers();
            break;
        case 'newDetection':
            addDetection(data.detection);
            break;
        case 'updateBans':
            bans = data.bans || [];
            renderBans();
            break;
        case 'updatePlayerStrikes':
            updatePlayerStrikes(data.src, data.strikes);
            break;
    }
});

// ==========================================
//  PANEL OPEN / CLOSE
// ==========================================
function openPanel(data) {
    document.getElementById('panel').classList.remove('hidden');
    if (data.players)    { players    = data.players;    renderPlayers(); }
    if (data.detections) { detections = data.detections; renderDetections(); }
    if (data.bans)       { bans       = data.bans;       renderBans(); }
}

function closePanel() {
    document.getElementById('panel').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closePanel`, {
        method: 'POST', body: JSON.stringify({})
    });
}

// ==========================================
//  TABS
// ==========================================
function switchTab(name, btn) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.getElementById('tab-' + name).classList.add('active');
    btn.classList.add('active');
}

// ==========================================
//  PLAYERS TAB
// ==========================================
function renderPlayers(list) {
    const tbody = document.getElementById('players-tbody');
    const data  = list || players;
    tbody.innerHTML = '';

    if (data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#333;padding:30px">No players connected</td></tr>';
        return;
    }

    data.forEach(p => {
        const strikes = p.strikes || 0;
        const hs      = p.hsRatio != null ? Math.round(p.hsRatio * 100) : null;

        let strikeClass = 'strike-0';
        if      (strikes >= 4) strikeClass = 'strike-high';
        else if (strikes >= 3) strikeClass = 'strike-mid';
        else if (strikes >= 1) strikeClass = 'strike-low';

        let hsHtml = '<span style="color:#333">—</span>';
        if (hs !== null) {
            let hsClass = hs >= 80 ? 'hs-danger' : hs >= 55 ? 'hs-warn' : 'hs-clean';
            hsHtml = `<span class="${hsClass}">${hs}%</span>`;
        }

        const fp = p.fingerprint ? p.fingerprint.substring(0, 20) + '…' : '—';

        tbody.innerHTML += `
            <tr>
                <td style="color:#555;font-family:monospace">${p.id}</td>
                <td style="color:#ddd;font-weight:600">${escHtml(p.name)}</td>
                <td><span class="strike-badge ${strikeClass}">${strikes}/${p.maxStrikes || 5}</span></td>
                <td>${hsHtml}</td>
                <td style="font-family:monospace;font-size:11px;color:#444" title="${escHtml(p.fingerprint || '')}">${fp}</td>
                <td>
                    <div class="actions">
                        <button class="btn btn-kick" onclick="action('kick', ${p.id}, '${escHtml(p.name)}')">Kick</button>
                        <button class="btn btn-warn" onclick="action('warn', ${p.id}, '${escHtml(p.name)}')">Warn</button>
                        <button class="btn btn-ban"  onclick="action('ban',  ${p.id}, '${escHtml(p.name)}')">Ban</button>
                        <button class="btn btn-ss"   onclick="action('ss',   ${p.id}, '${escHtml(p.name)}')">📸</button>
                        <button class="btn btn-tp"   onclick="action('tp',   ${p.id}, '${escHtml(p.name)}')">TP</button>
                    </div>
                </td>
            </tr>`;
    });
}

function filterPlayers() {
    const q = document.getElementById('player-search').value.toLowerCase();
    if (!q) { renderPlayers(); return; }
    renderPlayers(players.filter(p => p.name.toLowerCase().includes(q) || String(p.id).includes(q)));
}

// ==========================================
//  DETECTIONS TAB
// ==========================================
function addDetection(det) {
    detections.unshift(det);
    if (detections.length > 200) detections.pop();
    renderDetections();
}

function renderDetections(list) {
    const feed = document.getElementById('detections-feed');
    const data = list || detections;
    feed.innerHTML = '';

    if (data.length === 0) {
        feed.innerHTML = '<div style="color:#333;text-align:center;padding:40px">No detections yet</div>';
        return;
    }

    data.forEach(d => {
        const card = document.createElement('div');
        card.className = 'det-card';
        card.innerHTML = `
            <div>
                <div class="det-type">${escHtml(d.type)}</div>
                <div class="det-name">${escHtml(d.name)} <span style="color:#444">(${d.src})</span></div>
                <div class="det-detail">${escHtml(d.detail)}</div>
            </div>
            <div style="text-align:left;flex-shrink:0">
                <div class="det-time">${d.time}</div>
                <div style="margin-top:6px;display:flex;gap:4px">
                    <button class="btn btn-ban" onclick="action('ban', ${d.src}, '${escHtml(d.name)}')">Ban</button>
                    <button class="btn btn-ss"  onclick="action('ss',  ${d.src}, '${escHtml(d.name)}')">📸</button>
                </div>
            </div>`;
        feed.appendChild(card);
    });
}

function filterDetections() {
    const f = document.getElementById('det-filter').value;
    if (!f) { renderDetections(); return; }
    renderDetections(detections.filter(d => d.type.includes(f)));
}

function clearDetections() {
    detections = [];
    renderDetections();
}

// ==========================================
//  BANS TAB
// ==========================================
function renderBans(list) {
    const tbody = document.getElementById('bans-tbody');
    const data  = list || bans;
    tbody.innerHTML = '';

    if (data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#333;padding:30px">No bans</td></tr>';
        return;
    }

    data.forEach(b => {
        const date = b.time ? new Date(b.time * 1000).toLocaleDateString('en-US') : '—';
        tbody.innerHTML += `
            <tr>
                <td style="color:#ddd;font-weight:600">${escHtml(b.name)}</td>
                <td style="color:#888">${escHtml(b.reason)}</td>
                <td style="color:#555;font-size:12px">${date}</td>
                <td>
                    <button class="btn btn-unban" onclick="action('unban', '${escHtml(b.license)}', '${escHtml(b.name)}')">Unban</button>
                </td>
            </tr>`;
    });
}

function filterBans() {
    const q = document.getElementById('ban-search').value.toLowerCase();
    if (!q) { renderBans(); return; }
    renderBans(bans.filter(b =>
        b.name.toLowerCase().includes(q) ||
        (b.license && b.license.toLowerCase().includes(q))
    ));
}

// ==========================================
//  ACTIONS
// ==========================================
function action(type, target, name) {
    const messages = {
        kick:  `Kick ${name}?`,
        warn:  `Send a warning to ${name}?`,
        ban:   `Ban ${name}?`,
        ss:    `Take a screenshot of ${name}?`,
        tp:    `Teleport to ${name}?`,
        unban: `Unban ${name}?`,
    };

    confirm(messages[type] || `Perform ${type} on ${name}?`, () => {
        fetch(`https://${GetParentResourceName()}/adminAction`, {
            method: 'POST',
            body: JSON.stringify({ type, target })
        });
    });
}

// ==========================================
//  MODAL CONFIRM
// ==========================================
function confirm(text, callback) {
    document.getElementById('modal-text').textContent = text;
    document.getElementById('modal').classList.remove('hidden');
    modalCallback = callback;
    document.getElementById('modal-confirm').onclick = () => {
        if (modalCallback) modalCallback();
        closeModal();
    };
}

function closeModal() {
    document.getElementById('modal').classList.add('hidden');
    modalCallback = null;
}

// ==========================================
//  LIVE STRIKE UPDATE
// ==========================================
function updatePlayerStrikes(src, strikes) {
    const p = players.find(p => p.id === src);
    if (p) {
        p.strikes = strikes;
        renderPlayers();
    }
}

// ==========================================
//  UTILS
// ==========================================
function escHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'sdr_anticheat';
}

// Close on Escape
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closePanel();
});
