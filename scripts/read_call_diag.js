#!/usr/bin/env node

const {
  printJson,
  readInvite,
  readUser,
  fetchActiveInvitesForUid,
  fetchLatestInvitesForUid,
} = require('./_firebase_admin');

function usage() {
  console.log(`
Usage:
  node scripts/read_call_diag.js --uid USER_UID [--latest 5] [--active]
  node scripts/read_call_diag.js --invite INVITE_ID

Examples:
  node scripts/read_call_diag.js --uid 7cTNFDhfZcePyHl2WI8BkwLkGAJ3
  node scripts/read_call_diag.js --invite oC7briZeE5fKGkXDd4NJ
`.trim());
}

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

function diagField(user, key) {
  if (user?.diag && Object.prototype.hasOwnProperty.call(user.diag, key)) {
    return user.diag[key];
  }
  const dottedKey = `diag.${key}`;
  if (Object.prototype.hasOwnProperty.call(user || {}, dottedKey)) {
    return user[dottedKey];
  }
  return null;
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || (!args.uid && !args.invite)) {
    usage();
    process.exit(args.help ? 0 : 1);
  }

  if (args.invite) {
    const invite = await readInvite(String(args.invite).trim());
    if (!invite) {
      console.error(`Invite not found: ${args.invite}`);
      process.exit(2);
    }
    printJson({
      inviteId: String(args.invite).trim(),
      invite,
    });
    return;
  }

  const uid = String(args.uid).trim();
  const latestLimit = Math.max(1, Number.parseInt(String(args.latest || '5'), 10) || 5);
  const user = await readUser(uid);
  if (!user) {
    console.error(`User not found: ${uid}`);
    process.exit(2);
  }

  const latestInvites = await fetchLatestInvitesForUid(uid, latestLimit);
  const activeInvites = args.active ? await fetchActiveInvitesForUid(uid, latestLimit) : undefined;

  printJson({
    uid,
    diag: {
      lastCallStage: diagField(user, 'lastCallStage'),
      lastCallMeta: diagField(user, 'lastCallMeta'),
      lastCallAt: diagField(user, 'lastCallAt'),
      lastPushStage: diagField(user, 'lastPushStage'),
      lastPushMeta: diagField(user, 'lastPushMeta'),
      lastPushAt: diagField(user, 'lastPushAt'),
      lastChatStage: diagField(user, 'lastChatStage'),
      lastChatMeta: diagField(user, 'lastChatMeta'),
      lastChatAt: diagField(user, 'lastChatAt'),
      lastLifecycleState: diagField(user, 'lastLifecycleState'),
      lifecycleAt: diagField(user, 'lifecycleAt'),
      lastSystemStage: diagField(user, 'lastSystemStage'),
      lastSystemMeta: diagField(user, 'lastSystemMeta'),
      lastSystemAt: diagField(user, 'lastSystemAt'),
      activeListeners: diagField(user, 'activeListeners'),
      activeTimers: diagField(user, 'activeTimers'),
      activeCallSubscriptions: diagField(user, 'activeCallSubscriptions'),
      activeChatSubscriptions: diagField(user, 'activeChatSubscriptions'),
    },
    latestInvites,
    ...(args.active ? { activeInvites } : {}),
  });
}

run().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});
