#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const ROOT = path.resolve(__dirname, '..');
const SECRETS_DIR = path.join(ROOT, 'secrets');
const REDACT_KEYS = new Set([
  'apnstoken',
  'apnstokens',
  'fcmtoken',
  'fcmtokens',
  'fcmtokensios',
  'voiptoken',
  'voiptokens',
  'token',
  'tokens',
  'credential',
  'credentials',
  'privatekey',
  'private_key',
  'clientemail',
  'client_email',
]);

function findServiceAccountPath() {
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (envPath) {
    const resolved = path.resolve(ROOT, envPath);
    if (fs.existsSync(resolved)) return resolved;
  }

  if (!fs.existsSync(SECRETS_DIR)) {
    throw new Error(`Missing secrets directory: ${SECRETS_DIR}`);
  }

  const jsonFiles = fs
    .readdirSync(SECRETS_DIR)
    .filter((name) => name.endsWith('.json'))
    .sort();
  if (!jsonFiles.length) {
    throw new Error(`No Firebase service account JSON found in ${SECRETS_DIR}`);
  }
  return path.join(SECRETS_DIR, jsonFiles[0]);
}

function getFirestore() {
  if (admin.apps.length) {
    return admin.firestore();
  }

  const serviceAccountPath = findServiceAccountPath();
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.firestore();
}

function isTimestampLike(value) {
  return Boolean(value) && typeof value.toDate === 'function';
}

function normalizeValue(value) {
  if (isTimestampLike(value)) {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (Array.isArray(value)) {
    return value.map((item) => normalizeValue(item));
  }
  if (!value || typeof value !== 'object') {
    return value;
  }
  const output = {};
  for (const [key, nested] of Object.entries(value)) {
    output[key] = normalizeValue(nested);
  }
  return output;
}

function sanitizeValue(value) {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item));
  }
  if (!value || typeof value !== 'object') {
    return value;
  }
  const output = {};
  for (const [key, nested] of Object.entries(value)) {
    if (REDACT_KEYS.has(String(key).toLowerCase())) {
      continue;
    }
    output[key] = sanitizeValue(nested);
  }
  return output;
}

function normalizeSnapshotData(snapshot) {
  if (!snapshot?.exists) return null;
  const raw = snapshot.data() || {};
  return sanitizeValue(normalizeValue(raw));
}

function createdAtMillis(data, snapshot) {
  const createdAt = data?.createdAt;
  if (typeof createdAt === 'string') {
    const ms = Date.parse(createdAt);
    if (!Number.isNaN(ms)) return ms;
  }
  if (snapshot?.createTime && typeof snapshot.createTime.toMillis === 'function') {
    return snapshot.createTime.toMillis();
  }
  if (snapshot?.updateTime && typeof snapshot.updateTime.toMillis === 'function') {
    return snapshot.updateTime.toMillis();
  }
  return 0;
}

async function readUser(uid) {
  const db = getFirestore();
  const snapshot = await db.collection('users').doc(uid).get();
  return normalizeSnapshotData(snapshot);
}

async function readInvite(inviteId) {
  const db = getFirestore();
  const snapshot = await db.collection('callInvites').doc(inviteId).get();
  return normalizeSnapshotData(snapshot);
}

async function fetchLatestInvitesForUid(uid, limit = 5) {
  const db = getFirestore();
  const fetchLimit = Math.max(limit * 5, 25);
  const [fromSnap, toSnap] = await Promise.all([
    db.collection('callInvites').where('fromUid', '==', uid).limit(fetchLimit).get(),
    db.collection('callInvites').where('toUid', '==', uid).limit(fetchLimit).get(),
  ]);

  const merged = new Map();
  for (const snapshot of [...fromSnap.docs, ...toSnap.docs]) {
    const data = normalizeSnapshotData(snapshot);
    merged.set(snapshot.id, {
      id: snapshot.id,
      ...data,
      _createdAtMs: createdAtMillis(data, snapshot),
    });
  }

  return [...merged.values()]
    .sort((a, b) => (b._createdAtMs || 0) - (a._createdAtMs || 0))
    .slice(0, limit)
    .map(({ _createdAtMs, ...rest }) => rest);
}

async function fetchActiveInvitesForUid(uid, limit = 10) {
  const latest = await fetchLatestInvitesForUid(uid, limit * 3);
  const terminal = new Set(['declined', 'missed', 'cancelled', 'ended', 'failed']);
  return latest
    .filter((invite) => !terminal.has(String(invite.status || '').trim()))
    .slice(0, limit);
}

function printJson(value) {
  console.log(JSON.stringify(value, null, 2));
}

module.exports = {
  getFirestore,
  printJson,
  readInvite,
  readUser,
  fetchActiveInvitesForUid,
  fetchLatestInvitesForUid,
  sanitizeValue,
  normalizeValue,
};
