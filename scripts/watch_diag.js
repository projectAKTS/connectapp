#!/usr/bin/env node

const {
  getFirestore,
  sanitizeValue,
} = require('./_firebase_admin');

function usage() {
  console.log(`
Usage:
  node scripts/watch_diag.js --uid UID1 [--uid UID2 ...]

Examples:
  node scripts/watch_diag.js --uid IKKNv17nzQTFWFzYBGZnQQvvcmb2
  node scripts/watch_diag.js --uid IKKNv17nzQTFWFzYBGZnQQvvcmb2 --uid vP8vPHAaT7UvCfhnj0HJPq8l0Tt1
`.trim());
}

function parseArgs(argv) {
  const uids = [];
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--help') return { help: true, uids };
    if (token === '--uid') {
      const next = argv[i + 1];
      if (!next || next.startsWith('--')) {
        throw new Error('Missing value for --uid');
      }
      uids.push(String(next).trim());
      i += 1;
    }
  }
  return { help: false, uids: uids.filter(Boolean) };
}

function subset(data) {
  const sanitized = sanitizeValue(data || {});
  const diag = sanitizeValue(data?.diag || {});
  const get = (key) => {
    if (Object.prototype.hasOwnProperty.call(diag, key)) return diag[key];
    const dottedKey = `diag.${key}`;
    if (Object.prototype.hasOwnProperty.call(sanitized, dottedKey)) {
      return sanitized[dottedKey];
    }
    return null;
  };
  return {
    lastCallStage: get('lastCallStage'),
    lastCallMeta: get('lastCallMeta'),
    lastCallAt: get('lastCallAt'),
    lastPushStage: get('lastPushStage'),
    lastPushMeta: get('lastPushMeta'),
    lastPushAt: get('lastPushAt'),
    lastChatStage: get('lastChatStage'),
    lastChatMeta: get('lastChatMeta'),
    lastChatAt: get('lastChatAt'),
    lastLifecycleState: get('lastLifecycleState'),
    lifecycleAt: get('lifecycleAt'),
    lastSystemStage: get('lastSystemStage'),
    lastSystemMeta: get('lastSystemMeta'),
    lastSystemAt: get('lastSystemAt'),
    activeListeners: get('activeListeners'),
    activeTimers: get('activeTimers'),
    activeCallSubscriptions: get('activeCallSubscriptions'),
    activeChatSubscriptions: get('activeChatSubscriptions'),
  };
}

function printUpdate(uid, current) {
  const timestamp = new Date().toISOString();
  console.log(`\n[${timestamp}] uid=${uid}`);
  console.log(JSON.stringify(current, null, 2));
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.uids.length) {
    usage();
    process.exit(args.help ? 0 : 1);
  }

  const db = getFirestore();
  const previous = new Map();
  const unsubscribers = [];

  for (const uid of args.uids) {
    const unsubscribe = db.collection('users').doc(uid).onSnapshot(
      (snapshot) => {
        const current = subset(snapshot.data() || {});
        const serialized = JSON.stringify(current);
        if (previous.get(uid) === serialized) return;
        previous.set(uid, serialized);
        printUpdate(uid, current);
      },
      (error) => {
        console.error(`[watch_diag] uid=${uid} error: ${error?.message || error}`);
      },
    );
    unsubscribers.push(unsubscribe);
  }

  process.on('SIGINT', () => {
    for (const unsubscribe of unsubscribers) {
      try {
        unsubscribe();
      } catch (_) {}
    }
    process.exit(0);
  });

  console.log(`Watching diag for ${args.uids.length} uid(s). Press Ctrl+C to stop.`);
}

run().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});
