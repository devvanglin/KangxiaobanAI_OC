// ============================================================
// AsVox 语音评估问答 - 前端
// 布局: 左上角题目卡 / 中间五色声浪块 / 下方被评估者语音与倒计时
// ============================================================

// --- 状态 ---
let ws = null;
let isWsConnected = false;
let assessActive = false;
let assessTimeout = 15;        // 每题作答窗口(秒), 由 assess_begin 下发
let cdTimer = null;            // 前端倒计时可视化
let recordingForAssess = false;

// --- DOM ---
const statusDisplay = document.getElementById('status-display');
const questionCard = document.getElementById('question-card');
const qIndexText = document.getElementById('q-index-text');
const qTopic = document.getElementById('q-topic');
const qText = document.getElementById('q-text');
const ackLine = document.getElementById('ack-line');
const vizBars = document.querySelectorAll('.viz-bar');
const landing = document.getElementById('landing');
const landingStartBtn = document.getElementById('landing-start-btn');
const speechPanel = document.getElementById('speech-panel');
const userSpeechEl = document.getElementById('user-speech');
const countdownEl = document.getElementById('countdown');
const cdFill = document.getElementById('cd-fill');
const cdNum = document.getElementById('cd-num');
const cdHint = document.getElementById('cd-hint');
const assessFooter = document.getElementById('assess-footer');
const recordBtn = document.getElementById('record-btn');
const textInput = document.getElementById('text-input');
const sendBtn = document.getElementById('send-btn');
const progressText = document.getElementById('progress-text');
const assessStopBtn = document.getElementById('assess-stop-btn');
const assessPanel = document.getElementById('assess-panel');
const assessOpenBtns = [landingStartBtn];
const assessCloseBtn = document.getElementById('assess-close-btn');
const assessForm = document.getElementById('assess-form');
const assessStartBtn = document.getElementById('assess-start-btn');
const assessHistoryList = document.getElementById('assess-history-list');
const reportModal = document.getElementById('report-modal');
const reportCloseBtn = document.getElementById('report-close-btn');
const reportBody = document.getElementById('report-body');
const reportLink = document.getElementById('report-link');
const assessNewBtn = document.getElementById('assess-new-btn');
const audioPlayer = document.getElementById('audio-player');

// ============================================================
// 音频核心: AudioContext / 麦克风 / 播放队列 (保留已验证的 AEC 结构)
// ============================================================
let audioContext, analyser, dataArray;
let micAnalyser, micDataArray;
let isAudioInit = false;

function initAudioContext() {
    if (!audioContext) {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
        analyser = audioContext.createAnalyser();
        analyser.fftSize = 256;
        analyser.smoothingTimeConstant = 0.8;
        dataArray = new Uint8Array(analyser.frequencyBinCount);

        micAnalyser = audioContext.createAnalyser();
        micAnalyser.fftSize = 256;
        micAnalyser.smoothingTimeConstant = 0.8;
        micDataArray = new Uint8Array(micAnalyser.frequencyBinCount);

        isAudioInit = true;
        // 直接连到 destination，让浏览器接管标准 AEC 流同步
        analyser.connect(audioContext.destination);
    }
    if (audioContext.state === 'suspended') {
        audioContext.resume();
    }
}

let isRecording = false;
let currentMicStream = null;
let pcmWorklet = null;
let workletModuleLoaded = false;

async function startRecording() {
    if (isRecording) return;
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            audio: {
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: false,
                channelCount: 1
            }
        });
        currentMicStream = stream;
        if (isWsConnected) {
            ws.send(JSON.stringify({ type: 'control', action: 'start' }));
        }
        isRecording = true;
        recordBtn.classList.add('recording');
        setStatus('聆听中…', 'busy');

        initAudioContext();
        const hpf = audioContext.createBiquadFilter();
        hpf.type = 'highpass';
        hpf.frequency.value = 80;

        const source = audioContext.createMediaStreamSource(stream);
        source.connect(hpf);
        hpf.connect(micAnalyser);

        if (!workletModuleLoaded) {
            await audioContext.audioWorklet.addModule('/static/pcm-processor.js');
            workletModuleLoaded = true;
        }
        pcmWorklet = new AudioWorkletNode(audioContext, 'pcm-processor');
        pcmWorklet.port.onmessage = (e) => {
            if (isWsConnected && isRecording) {
                ws.send(e.data); // 16kHz Int16 PCM 二进制
            }
        };
        hpf.connect(pcmWorklet);
        const silentGain = audioContext.createGain();
        silentGain.gain.value = 0;
        pcmWorklet.connect(silentGain);
        silentGain.connect(audioContext.destination);
    } catch (e) {
        console.error('Mic error:', e);
        alert('无法访问麦克风，语音回答不可用（仍可打字回答）');
        recordBtn.classList.remove('recording');
    }
}

function stopRecording() {
    if (pcmWorklet) { pcmWorklet.disconnect(); pcmWorklet = null; }
    isRecording = false;
    recordBtn.classList.remove('recording');
    if (currentMicStream) {
        currentMicStream.getTracks().forEach(track => track.stop());
        currentMicStream = null;
    }
}

// 播放队列
let audioQueue = [];
let isPlaying = false;
let currentAudioSource = null;

function decodeBase64ToFloat32Array(base64) {
    const binary_string = window.atob(base64);
    const len = binary_string.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) bytes[i] = binary_string.charCodeAt(i);
    return new Float32Array(bytes.buffer);
}

function handleAudioChunk(data) {
    audioQueue.push({
        buffer: decodeBase64ToFloat32Array(data.audio_data),
        sampleRate: data.sample_rate || 24000
    });
    if (!isPlaying) playNextAudio();
}

async function playNextAudio() {
    if (audioQueue.length === 0) {
        isPlaying = false;
        if (!assessActive) setStatus('READY');
        else setStatus('等待回答…');
        return;
    }
    isPlaying = true;
    const audioData = audioQueue.shift();
    initAudioContext();
    if (audioContext && audioContext.state === 'suspended') await audioContext.resume();
    try {
        const audioBuffer = audioContext.createBuffer(1, audioData.buffer.length, audioData.sampleRate);
        audioBuffer.getChannelData(0).set(audioData.buffer);
        const source = audioContext.createBufferSource();
        source.buffer = audioBuffer;
        source.connect(analyser);
        currentAudioSource = source;
        source.onended = () => {
            if (currentAudioSource === source) {
                currentAudioSource = null;
                playNextAudio();
            }
        };
        setStatus('提问中…', 'busy');
        source.start(0);
    } catch (e) {
        console.error('Playback failed:', e);
        playNextAudio();
    }
}

// 打断: 瞬间静音并清空队列
function finalizeInterrupt() {
    if (currentAudioSource) {
        const source = currentAudioSource;
        currentAudioSource = null;
        try { source.onended = null; source.stop(); } catch (e) {}
        source.disconnect();
    }
    audioQueue = [];
    isPlaying = false;
}

// ============================================================
// WebSocket
// ============================================================
function initWebSocket() {
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) return;
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    ws = new WebSocket(`${protocol}//${window.location.host}/ws`);

    ws.onopen = () => { isWsConnected = true; setStatus('READY'); };
    ws.onclose = () => {
        isWsConnected = false;
        setStatus('连接断开，重试中…', 'busy');
        setTimeout(initWebSocket, 3000);
    };
    ws.onerror = () => { isWsConnected = false; };
    ws.onmessage = (event) => handleWsMessage(event.data);
}

function handleWsMessage(dataStr) {
    let data;
    try { data = JSON.parse(dataStr); } catch (e) { return; }
    const t = data.type;

    if (t === 'asr') {
        // 被评估者的实时识别文字
        userSpeechEl.textContent = data.text;
    } else if (t === 'interrupt') {
        // 用户插话: 静音旧音频, 重置倒计时(服务端已重新计时)
        finalizeInterrupt();
        resetCountdownVisual(true);
    } else if (t === 'text') {
        // 助手过渡语(流式)
        ackLine.textContent += data.content;
    } else if (t === 'audio') {
        handleAudioChunk(data);
    } else if (t === 'start') {
        ackLine.textContent = '';
    } else if (t === 'end') {
        // 本轮提问播报完毕 → 开始作答倒计时
        if (assessActive) startCountdownVisual();
    } else if (t === 'assess_begin') {
        handleAssessBegin(data);
    } else if (t === 'assess_question') {
        handleAssessQuestion(data);
    } else if (t === 'assess_answer') {
        handleAssessAnswer(data);
    } else if (t === 'assess_status') {
        if (data.status === 'generating') setStatus('正在生成评估报告…', 'busy');
    } else if (t === 'assess_summary') {
        handleAssessSummary(data);
    } else if (t === 'error') {
        setStatus('ERROR');
    }
}

// ============================================================
// 评估流程
// ============================================================
function setStatus(text, type = 'normal') {
    statusDisplay.textContent = text;
    const dot = document.querySelector('.status-dot');
    if (dot) dot.className = 'status-dot ' + (type === 'busy' ? 'busy' : 'healthy');
}

function handleAssessBegin(data) {
    assessActive = true;
    assessTimeout = data.timeout || 15;
    landing.style.display = 'none';
    questionCard.style.display = 'block';
    speechPanel.style.display = 'block';
    assessFooter.style.display = 'flex';
    assessPanel.classList.remove('open');
    progressText.textContent = `0/${data.total}`;
    userSpeechEl.textContent = '…';
    qText.textContent = '';
    ackLine.textContent = '';
    setStatus('评估开始', 'busy');
    // 评估期间自动开麦, 免手动操作, 支持随时插话
    if (!isRecording) {
        recordBtn.classList.add('recording');
        recordBtn.querySelector('.btn-label').textContent = '聆听中…';
        startRecording();
    }
}

function handleAssessQuestion(data) {
    qIndexText.textContent = `第 ${data.index + 1}/${data.total} 题`;
    qTopic.textContent = data.topic;
    qText.textContent = data.question;
    ackLine.textContent = '';
    userSpeechEl.textContent = '…';
    progressText.textContent = `${data.index}/${data.total}`;
    setStatus('提问中…', 'busy');
    resetCountdownVisual(false);
}

function handleAssessAnswer(data) {
    if (data.no_response) {
        userSpeechEl.textContent = '（超时未回答，判定不配合）';
        userSpeechEl.classList.add('timeout');
    } else {
        userSpeechEl.classList.remove('timeout');
    }
    resetCountdownVisual(false);
    setStatus('等待回答…');
}

// --- 倒计时可视化 (服务端为判定权威, 这里同步展示) ---
function startCountdownVisual() {
    stopCountdownVisual();
    cdHint.style.display = 'none';
    const startedAt = Date.now();
    const totalMs = assessTimeout * 1000;
    countdownEl.classList.add('running');
    cdTimer = setInterval(() => {
        const remain = totalMs - (Date.now() - startedAt);
        if (remain <= 0) {
            stopCountdownVisual();
            cdFill.style.width = '0%';
            cdNum.textContent = '0s';
            cdHint.style.display = 'block';
            return;
        }
        countdownEl.classList.toggle('warn', remain < 5000);
        cdFill.style.width = (remain / totalMs * 100) + '%';
        cdNum.textContent = Math.ceil(remain / 1000) + 's';
    }, 100);
}

function resetCountdownVisual(keepHint) {
    stopCountdownVisual();
    countdownEl.classList.remove('warn');
    cdFill.style.width = '100%';
    cdNum.textContent = assessTimeout + 's';
    cdHint.style.display = 'none';
}

function stopCountdownVisual() {
    if (cdTimer) { clearInterval(cdTimer); cdTimer = null; }
    countdownEl.classList.remove('running');
}

function handleAssessSummary(data) {
    assessActive = false;
    stopCountdownVisual();
    resetCountdownVisual(false);
    assessFooter.style.display = 'none';
    speechPanel.style.display = 'none';
    questionCard.style.display = 'none';
    landing.style.display = 'flex';
    if (isRecording) {
        recordBtn.classList.remove('recording');
        recordBtn.querySelector('.btn-label').textContent = 'TAP TO SPEAK';
        stopRecording();
    }
    setStatus('评估完成');
    reportBody.innerHTML = renderMarkdown(data.report || '');
    reportLink.href = data.report_url || '#';
    reportModal.style.display = 'flex';
    loadAssessHistory();
}

// --- 轻量 Markdown 渲染 ---
function renderMarkdown(md) {
    const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const html = [];
    let inList = false;
    for (const rawLine of md.split('\n')) {
        let line = esc(rawLine.trimEnd());
        line = line.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        if (/^#{1,6}\s/.test(line)) {
            if (inList) { html.push('</ul>'); inList = false; }
            const level = line.match(/^#+/)[0].length;
            html.push(`<h${Math.min(level + 2, 6)}>${line.replace(/^#+\s*/, '')}</h${Math.min(level + 2, 6)}>`);
        } else if (/^[-*]\s/.test(line)) {
            if (!inList) { html.push('<ul>'); inList = true; }
            html.push(`<li>${line.replace(/^[-*]\s*/, '')}</li>`);
        } else if (line.trim() === '') {
            if (inList) { html.push('</ul>'); inList = false; }
        } else {
            if (inList) { html.push('</ul>'); inList = false; }
            html.push(`<p>${line}</p>`);
        }
    }
    if (inList) html.push('</ul>');
    return html.join('');
}

// --- 抽屉 / 历史 / 报告 ---
function openDrawer() {
    assessPanel.classList.add('open');
    loadAssessHistory();
}
assessOpenBtns.forEach(b => b.addEventListener('click', openDrawer));
assessCloseBtn.addEventListener('click', () => assessPanel.classList.remove('open'));

assessStartBtn.addEventListener('click', () => {
    const name = document.getElementById('ap-name').value.trim();
    if (!name) { alert('请先填写姓名'); return; }
    if (!isWsConnected) { alert('连接未就绪，请稍候'); return; }
    assessStartBtn.disabled = true;
    ws.send(JSON.stringify({
        type: 'assessment_start',
        profile: {
            name: name,
            age: document.getElementById('ap-age').value,
            gender: document.getElementById('ap-gender').value,
            complaint: document.getElementById('ap-complaint').value.trim()
        }
    }));
});

assessStopBtn.addEventListener('click', () => {
    if (assessActive && isWsConnected) {
        setStatus('正在结束评估…', 'busy');
        ws.send(JSON.stringify({ type: 'assessment_stop' }));
    }
});

assessNewBtn.addEventListener('click', () => {
    reportModal.style.display = 'none';
    document.getElementById('ap-name').value = '';
    document.getElementById('ap-age').value = '';
    document.getElementById('ap-gender').value = '';
    document.getElementById('ap-complaint').value = '';
    assessStartBtn.disabled = false;
    openDrawer();
});

reportCloseBtn.addEventListener('click', () => {
    reportModal.style.display = 'none';
    landing.style.display = 'flex';
});

async function loadAssessHistory() {
    try {
        const resp = await fetch('/assessments');
        const data = await resp.json();
        assessHistoryList.innerHTML = '';
        (data.items || []).slice(0, 15).forEach(item => {
            const li = document.createElement('li');
            li.innerHTML = `<a href="${item.report_url}" target="_blank">
                <span class="h-name">${item.name || '未命名'}</span>
                <span class="h-meta">${item.created_at || ''} · ${item.answered}/${item.total} 题</span></a>`;
            assessHistoryList.appendChild(li);
        });
        if (!data.items || data.items.length === 0) {
            assessHistoryList.innerHTML = '<li class="empty">暂无历史报告</li>';
        }
    } catch (e) {
        assessHistoryList.innerHTML = '<li class="empty">历史加载失败</li>';
    }
}

// --- 文字回答 ---
function sendText() {
    const text = textInput.value.trim();
    if (!text || !isWsConnected || !assessActive) return;
    textInput.value = '';
    userSpeechEl.textContent = text;
    userSpeechEl.classList.remove('timeout');
    finalizeInterrupt();
    ws.send(JSON.stringify({ type: 'assessment_answer', text: text }));
}
sendBtn.addEventListener('click', sendText);
textInput.addEventListener('keypress', (e) => { if (e.key === 'Enter') sendText(); });

// --- 麦克风手动开关(备用) ---
recordBtn.addEventListener('click', () => {
    if (!isRecording) {
        recordBtn.classList.add('recording');
        recordBtn.querySelector('.btn-label').textContent = '聆听中…';
        startRecording();
    } else if (!assessActive) {
        // 评估中不允许随手关麦，避免漏听回答
        recordBtn.classList.remove('recording');
        recordBtn.querySelector('.btn-label').textContent = 'TAP TO SPEAK';
        stopRecording();
    }
});

// ============================================================
// 五色声浪块: 随当前活跃音频(提问播放 / 被评估者麦克风)起伏
// ============================================================
const BAND_RANGES = [[2, 8], [8, 20], [20, 40], [40, 70], [70, 110]];

function bandLevel(data, range) {
    let sum = 0;
    for (let i = range[0]; i < range[1]; i++) sum += data[i] || 0;
    return sum / (range[1] - range[0]) / 255;
}

let idlePhase = 0;

function animateViz() {
    requestAnimationFrame(animateViz);
    let source = null;
    if (isAudioInit && isPlaying) {
        analyser.getByteFrequencyData(dataArray);
        source = dataArray;
    } else if (isAudioInit && isRecording) {
        micAnalyser.getByteFrequencyData(micDataArray);
        source = micDataArray;
    }

    idlePhase += 0.03;
    vizBars.forEach((bar, i) => {
        let level;
        if (source) {
            level = bandLevel(source, BAND_RANGES[i]);
            level = Math.min(1, level * 1.6);
        } else {
            // 待机: 平缓波浪
            level = 0.12 + 0.08 * Math.sin(idlePhase + i * 0.9);
        }
        bar.style.transform = `scaleY(${(0.08 + level * 0.92).toFixed(3)})`;
        bar.style.opacity = (0.25 + level * 0.75).toFixed(2);
    });
}

// ============================================================
// 启动
// ============================================================
initWebSocket();
animateViz();
openDrawer(); // 进入页面先建档
console.log('AsVox assessment UI loaded');
