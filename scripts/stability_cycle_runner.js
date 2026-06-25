#!/usr/bin/env node

const readline = require('readline');
const {
  getFirestore,
  readUser,
  fetchLatestInvitesForUid,
} = require('./_firebase_admin');

const TERMINAL_STATUSES = new Set([
  'declined',
  'missed',
  'cancelled',
  'ended',
  'failed',
]);

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

function usage() {
  console.log(`
Usage:
  node scripts/stability_cycle_runner.js --caller UID --callee UID [options]

Options:
  --cycles 20
  --chat CHAT_ID                 Defaults to sorted caller/callee ids joined with "_"
  --invite-window 20            Seconds to wait for a new invite after arming a cycle
  --terminal-window 90          Seconds to wait for invite to reach terminal status
  --chat-window 45              Seconds to wait for a new chat message after invite creation
  --settle-ms 2000              Delay after terminal state before sampling counters
  --poll-ms 1000                Firestore polling interval in milliseconds
  --no-chat                     Skip chat-message expectation for each cycle
  --no-prompt                   Start cycles immediately without waiting for Enter
  --direction caller            Only accept caller->callee invites. Default: either

Example:
  node scripts/stability_cycle_runner.js --caller UID_A --callee UID_B --cycles 20
`.trim());
}

function sortedChatId(a, b) {
  return [a.trim(), b.trim()].sort().join('_');
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function promptEnter(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(message, () => {
      rl.close();
      resolve();
    });
  });
}

function parseMapLike(meta) {
  const output = {};
  if (!meta || typeof meta !== 'string') return output;
  const body = meta.trim().replace(/^\{/, '').replace(/\}$/, '');
  const regex = /([A-Za-z0-9_.]+):\s*([^,}]+)/g;
  let match;
  while ((match = regex.exec(body)) !== null) {
    output[match[1]] = match[2].trim();
  }
  return output;
}

function extractCounterSet(user) {
  const callMeta = parseMapLike(user?.diag?.lastCallMeta || '');
  const pushMeta = parseMapLike(user?.diag?.lastPushMeta || '');
  const keys = [
    'activeListeners',
    'activeTimers',
    'activeCallSubscriptions',
    'activeChatSubscriptions',
  ];
  const merged = {};
  for (const key of keys) {
    const callValue = Number.parseInt(callMeta[key] || '', 10);
    const pushValue = Number.parseInt(pushMeta[key] || '', 10);
    const values = [callValue, pushValue].filter((value) => Number.isFinite(value));
    merged[key] = values.length ? Math.max(...values) : null;
  }
  return {
    merged,
    callMeta,
    pushMeta,
    lastCallStage: user?.diag?.lastCallStage || null,
    lastPushStage: user?.diag?.lastPushStage || null,
  };
}

async function fetchUserState(uid) {
  const user = await readUser(uid);
  return {
    uid,
    diag: {
      lastCallStage: user?.diag?.lastCallStage || null,
      lastCallMeta: user?.diag?.lastCallMeta || null,
      lastPushStage: user?.diag?.lastPushStage || null,
      lastPushMeta: user?.diag?.lastPushMeta || null,
      lastCallAt: user?.diag?.lastCallAt || null,
      lastPushAt: user?.diag?.lastPushAt || null,
    },
    counters: extractCounterSet(user),
  };
}

async function fetchLatestPairInvite(callerUid, calleeUid, cycleStartMs, direction) {
  const latest = await Promise.all([
    fetchLatestInvitesForUid(callerUid, 10),
    fetchLatestInvitesForUid(calleeUid, 10),
  ]);
  const merged = new Map();
  for (const list of latest) {
    for (const invite of list) {
      merged.set(invite.id, invite);
    }
  }

  const filtered = [...merged.values()]
    .filter((invite) => {
      const fromUid = String(invite.fromUid || '').trim();
      const toUid = String(invite.toUid || '').trim();
      const createdAtMs = Date.parse(String(invite.createdAt || '')) || 0;
      if (createdAtMs < cycleStartMs) return false;
      if (direction === 'caller') {
        return fromUid === callerUid && toUid === calleeUid;
      }
      if (direction === 'callee') {
        return fromUid === calleeUid && toUid === callerUid;
      }
      const pair = new Set([fromUid, toUid]);
      return pair.has(callerUid) && pair.has(calleeUid);
    })
    .sort((a, b) => (Date.parse(String(b.createdAt || '')) || 0) - (Date.parse(String(a.createdAt || '')) || 0));

  return filtered[0] || null;
}

async function waitForInvite({ callerUid, calleeUid, cycleStartMs, inviteWindowMs, pollMs, direction }) {
  const deadline = Date.now() + inviteWindowMs;
  while (Date.now() < deadline) {
    const invite = await fetchLatestPairInvite(callerUid, calleeUid, cycleStartMs, direction);
    if (invite) return invite;
    await sleep(pollMs);
  }
  return null;
}

async function waitForInviteTerminal(inviteId, terminalWindowMs, pollMs) {
  const db = getFirestore();
  const inviteRef = db.collection('callInvites').doc(inviteId);
  const deadline = Date.now() + terminalWindowMs;
  let latest = null;
  while (Date.now() < deadline) {
    const snap = await inviteRef.get();
    latest = snap.exists ? snap.data() : null;
    const status = String(latest?.status || '').trim();
    if (TERMINAL_STATUSES.has(status)) {
      return { terminal: true, invite: latest };
    }
    await sleep(pollMs);
  }
  return { terminal: false, invite: latest };
}

async function waitForChatMessage(chatId, cycleStartMs, chatWindowMs, pollMs) {
  const db = getFirestore();
  const deadline = Date.now() + chatWindowMs;
  while (Date.now() < deadline) {
    const snap = await db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();
    const doc = snap.docs[0];
    if (doc) {
      const data = doc.data() || {};
      const createdAt = data.createdAt;
      const createdAtMs =
        createdAt && typeof createdAt.toDate === 'function'
          ? createdAt.toDate().getTime()
          : Date.parse(String(createdAt || '')) || 0;
      if (createdAtMs >= cycleStartMs) {
        return {
          id: doc.id,
          authorId: data.authorId || null,
          type: data.type || 'text',
          createdAt: createdAt && typeof createdAt.toDate === 'function'
            ? createdAt.toDate().toISOString()
            : data.createdAt || null,
        };
      }
    }
    await sleep(pollMs);
  }
  return null;
}

function compareCounters(label, baseline, current) {
  const drifts = [];
  for (const key of Object.keys(baseline)) {
    const baseValue = baseline[key];
    const currentValue = current[key];
    if (baseValue == null || currentValue == null) continue;
    if (currentValue > baseValue) {
      drifts.push(`${label}.${key}: baseline=${baseValue} current=${currentValue}`);
    }
  }
  return drifts;
}

async function captureState(callerUid, calleeUid) {
  const [caller, callee] = await Promise.all([
    fetchUserState(callerUid),
    fetchUserState(calleeUid),
  ]);
  return { caller, callee };
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.caller || !args.callee) {
    usage();
    process.exit(args.help ? 0 : 1);
  }

  const callerUid = String(args.caller).trim();
  const calleeUid = String(args.callee).trim();
  const cycles = Math.max(1, Number.parseInt(String(args.cycles || '20'), 10) || 20);
  const inviteWindowMs = (Number.parseInt(String(args['invite-window'] || '20'), 10) || 20) * 1000;
  const terminalWindowMs = (Number.parseInt(String(args['terminal-window'] || '90'), 10) || 90) * 1000;
  const chatWindowMs = (Number.parseInt(String(args['chat-window'] || '45'), 10) || 45) * 1000;
  const settleMs = Math.max(0, Number.parseInt(String(args['settle-ms'] || '2000'), 10) || 2000);
  const pollMs = Math.max(250, Number.parseInt(String(args['poll-ms'] || '1000'), 10) || 1000);
  const expectChat = !args['no-chat'];
  const promptEachCycle = !args['no-prompt'];
  const direction = ['caller', 'callee', 'either'].includes(String(args.direction || 'either'))
    ? String(args.direction || 'either')
    : 'either';
  const chatId = String(args.chat || sortedChatId(callerUid, calleeUid)).trim();

  console.log(`Pair: ${callerUid} <-> ${calleeUid}`);
  console.log(`Chat: ${chatId}`);
  console.log(`Cycles: ${cycles}`);
  console.log(`Direction: ${direction}`);
  console.log(expectChat ? 'Chat expectation: enabled' : 'Chat expectation: disabled');

  let baseline = null;
  const results = [];

  for (let cycle = 1; cycle <= cycles; cycle += 1) {
    if (promptEachCycle) {
      await promptEnter(`\nCycle ${cycle}/${cycles}: press Enter to arm, then perform call accept/end${expectChat ? ' and send one chat message' : ''}. `);
    }

    const cycleStartMs = Date.now();
    const invite = await waitForInvite({
      callerUid,
      calleeUid,
      cycleStartMs,
      inviteWindowMs,
      pollMs,
      direction,
    });

    if (!invite) {
      console.error(`Cycle ${cycle} failed: no invite created within ${inviteWindowMs / 1000}s.`);
      process.exit(10);
    }

    console.log(`Cycle ${cycle}: invite ${invite.id} created with status=${invite.status} channel=${invite.channel}`);

    const terminal = await waitForInviteTerminal(invite.id, terminalWindowMs, pollMs);
    if (!terminal.terminal) {
      console.error(`Cycle ${cycle} failed: invite ${invite.id} did not reach a terminal state within ${terminalWindowMs / 1000}s.`);
      process.exit(11);
    }

    console.log(`Cycle ${cycle}: terminal status=${terminal.invite?.status || 'unknown'} endReason=${terminal.invite?.endReason || ''}`);

    let chatMessage = null;
    if (expectChat) {
      chatMessage = await waitForChatMessage(chatId, cycleStartMs, chatWindowMs, pollMs);
      if (!chatMessage) {
        console.error(`Cycle ${cycle} failed: no chat message detected within ${chatWindowMs / 1000}s.`);
        process.exit(12);
      }
      console.log(`Cycle ${cycle}: chat message ${chatMessage.id} by ${chatMessage.authorId || 'unknown'} type=${chatMessage.type}`);
    }

    await sleep(settleMs);
    const state = await captureState(callerUid, calleeUid);

    if (state.caller.diag.lastCallStage === 'start_blocked' || state.callee.diag.lastCallStage === 'start_blocked') {
      console.error(`Cycle ${cycle} failed: CallSessionManager reported start_blocked.`);
      console.error(JSON.stringify(state, null, 2));
      process.exit(13);
    }

    if (!baseline) {
      baseline = {
        caller: state.caller.counters.merged,
        callee: state.callee.counters.merged,
      };
      console.log(`Cycle ${cycle}: baseline counters established.`);
    } else {
      const drifts = [
        ...compareCounters('caller', baseline.caller, state.caller.counters.merged),
        ...compareCounters('callee', baseline.callee, state.callee.counters.merged),
      ];
      if (drifts.length) {
        console.error(`Cycle ${cycle} failed: counter drift detected.`);
        for (const drift of drifts) {
          console.error(`  ${drift}`);
        }
        console.error(JSON.stringify(state, null, 2));
        process.exit(14);
      }
    }

    results.push({
      cycle,
      inviteId: invite.id,
      status: terminal.invite?.status || null,
      endReason: terminal.invite?.endReason || null,
      chatMessageId: chatMessage?.id || null,
      callerCounters: state.caller.counters.merged,
      calleeCounters: state.callee.counters.merged,
      callerLastCallStage: state.caller.diag.lastCallStage,
      calleeLastCallStage: state.callee.diag.lastCallStage,
    });

    console.log(`Cycle ${cycle}: passed.`);
  }

  console.log('\nAll cycles passed.');
  console.log(JSON.stringify(results, null, 2));
}

run().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});
