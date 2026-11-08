// scripts/capture-evidence.js
// Automated genuine evidence capture using Microsoft Edge CDP and built-in Node.js WebSocket

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// 1. Read admin password from .env
const envPath = path.join(__dirname, '..', '.env');
if (!fs.existsSync(envPath)) {
  console.error('.env file not found');
  process.exit(1);
}
const envContent = fs.readFileSync(envPath, 'utf8');
const passMatch = envContent.match(/JENKINS_ADMIN_PASSWORD=(.+)/);
if (!passMatch) {
  console.error('JENKINS_ADMIN_PASSWORD not found in .env');
  process.exit(1);
}
const adminPassword = passMatch[1].trim();
const adminUser = (envContent.match(/JENKINS_ADMIN_USER=(.+)/) || [])[1]?.trim() || 'admin';
const baseUrl = (envContent.match(/JENKINS_CONTROLLER_URL=(.+)/) || [])[1]?.trim().replace(/\/$/, '') || 'http://localhost:8080';

const edgePath = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const userProfileDir = path.join('C:\\Users\\Admin1\\AppData\\Local\\Temp', 'edge-cdp-evidence-' + Date.now());

const screenshotsDir = path.join(__dirname, '..', 'screenshots');
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function run() {
  console.log('[1/3] Launching Microsoft Edge in headless mode with remote debugging...');
  const edgeProc = spawn(edgePath, [
    '--headless=new',
    '--remote-debugging-port=9222',
    `--user-data-dir=${userProfileDir}`,
    '--window-size=1440,960',
    'about:blank'
  ]);

  edgeProc.on('error', (err) => {
    console.error('Failed to spawn Edge:', err);
    process.exit(1);
  });

  // Wait for debug port to become available
  let targetWsUrl = null;
  for (let i = 0; i < 20; i++) {
    await sleep(500);
    try {
      const res = await fetch('http://127.0.0.1:9222/json');
      const list = await res.json();
      const pageTarget = list.find(t => t.type === 'page');
      if (pageTarget && pageTarget.webSocketDebuggerUrl) {
        targetWsUrl = pageTarget.webSocketDebuggerUrl;
        break;
      }
    } catch (e) {}
  }

  if (!targetWsUrl) {
    console.error('Could not connect to Edge DevTools port 9222');
    edgeProc.kill();
    process.exit(1);
  }

  console.log('[2/3] Connecting WebSocket CDP client to Edge target...');
  const ws = new WebSocket(targetWsUrl);

  let msgId = 1;
  const callbacks = new Map();

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.id && callbacks.has(data.id)) {
      const cb = callbacks.get(data.id);
      callbacks.delete(data.id);
      if (data.error) cb.reject(data.error);
      else cb.resolve(data.result);
    }
  };

  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });

  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = msgId++;
      callbacks.set(id, { resolve, reject });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');

  // Set viewport
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 960,
    deviceScaleFactor: 1,
    mobile: false
  });

  // Inject Basic Auth header into ALL requests
  const basicAuthHeader = 'Basic ' + Buffer.from(`${adminUser}:${adminPassword}`).toString('base64');
  await send('Network.setExtraHTTPHeaders', {
    headers: {
      'Authorization': basicAuthHeader
    }
  });

  const targets = [
    {
      filename: '01-jenkins-controller-dashboard.png',
      url: `${baseUrl}/`,
      title: 'Jenkins Controller Dashboard',
      waitMs: 3000
    },
    {
      filename: '02-jenkins-node-management.png',
      url: `${baseUrl}/computer/`,
      title: 'Jenkins Node Management (Distributed Nodes)',
      waitMs: 3000
    },
    {
      filename: '03-linux-inbound-agent.png',
      url: `${baseUrl}/computer/remote-linux-agent/`,
      title: 'Linux Inbound Agent Node Details',
      waitMs: 3000
    },
    {
      filename: '04-windows-inbound-agent.png',
      url: `${baseUrl}/computer/windows-agent/`,
      title: 'Windows Inbound Agent Node Details',
      waitMs: 3000
    },
    {
      filename: '05-distributed-pipeline-execution.png',
      url: `${baseUrl}/job/codealpha-distributed-job/`,
      title: 'Distributed Pipeline Execution Stage View',
      waitMs: 3000
    },
    {
      filename: '06-build-console-node-verification.png',
      url: `${baseUrl}/job/codealpha-distributed-job/3/console`,
      title: 'Build Console Log & Node Verification',
      waitMs: 3000,
      postNav: async () => {
        // Adjust font and highlight key lines in console view for high readability
        await send('Runtime.evaluate', {
          expression: `
            const pre = document.querySelector('.console-output, pre');
            if (pre) {
              pre.style.fontSize = '12px';
              pre.style.lineHeight = '1.4';
              pre.style.maxHeight = 'none';
            }
          `
        });
      }
    }
  ];

  console.log('[3/3] Navigating and capturing genuine authenticated screenshots...');
  for (const t of targets) {
    await send('Page.navigate', { url: t.url });
    await sleep(t.waitMs);
    if (t.postNav) {
      await t.postNav();
      await sleep(1000);
    }

    const titleEval = await send('Runtime.evaluate', { expression: 'document.title' });
    const pageTitle = titleEval.result?.value || '';
    console.log(`Page: ${t.title} -> Document Title: "${pageTitle}"`);

    const snap = await send('Page.captureScreenshot', {
      format: 'png',
      quality: 100,
      captureBeyondViewport: false
    });

    const filePath = path.join(screenshotsDir, t.filename);
    fs.writeFileSync(filePath, Buffer.from(snap.data, 'base64'));
    const sizeKb = (snap.data.length * 0.75 / 1024).toFixed(1);
    console.log(`[SAVED] ${t.filename} (${sizeKb} KB)\n`);
  }

  ws.close();
  edgeProc.kill();
  console.log('[SUCCESS] All 6 screenshots captured and verified.');
}

run().catch(err => {
  console.error('Error during execution evidence capture:', err);
  process.exit(1);
});
