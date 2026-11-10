// Read-only access to a Firebase project with the signed-in gcloud account.
// Only GET and query calls; nothing here writes. The access token stays in
// memory and is never printed.
import { execFileSync } from "node:child_process";

export const PROJECT = process.argv.find((a) => a.startsWith("--project="))?.slice(10)
  || "connectapp-278b4";

let token = "";
function auth() {
  if (!token) {
    token = execFileSync("gcloud", ["auth", "print-access-token"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  }
  return { authorization: `Bearer ${token}`, "content-type": "application/json" };
}

const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function post(url, body) {
  const r = await fetch(url, { method: "POST", headers: auth(), body: JSON.stringify(body) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${r.status} ${j.error?.message || ""}`.trim());
  return j;
}

/** Plain JS value of a Firestore REST value. */
export function plain(v) {
  if (!v) return null;
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("nullValue" in v) return null;
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(plain);
  if ("mapValue" in v) return fields(v.mapValue.fields || {});
  return null;
}
const fields = (f) => Object.fromEntries(Object.entries(f).map(([k, v]) => [k, plain(v)]));

/** Documents of [collection] matching `field == value` (all, or [where] omitted). */
export async function query(collection, where, limit = 500) {
  const structuredQuery = { from: [{ collectionId: collection }], limit };
  if (where) {
    structuredQuery.where = {
      fieldFilter: { field: { fieldPath: where[0] }, op: "EQUAL", value: toValue(where[1]) },
    };
  }
  const rows = await post(`${FS}:runQuery`, { structuredQuery });
  return rows
    .filter((r) => r.document)
    .map((r) => ({ id: r.document.name.split("/").pop(), ...fields(r.document.fields || {}) }));
}

const toValue = (v) =>
  typeof v === "boolean" ? { booleanValue: v } : { stringValue: `${v}` };

/** Number of documents in a collection (or every collection of that name). */
export async function count(collection, allDescendants = false) {
  const rows = await post(`${FS}:runAggregationQuery`, {
    structuredAggregationQuery: {
      structuredQuery: { from: [{ collectionId: collection, allDescendants }] },
      aggregations: [{ alias: "n", count: {} }],
    },
  });
  return Number(rows[0]?.result?.aggregateFields?.n?.integerValue || 0);
}

/** Sum of a Cloud Monitoring metric over the last [days]. */
export async function metricSum(type, days = 7, extra = "") {
  const end = new Date();
  const start = new Date(end - days * 864e5);
  const p = new URLSearchParams({
    filter: `metric.type="${type}"${extra}`,
    "interval.startTime": start.toISOString(),
    "interval.endTime": end.toISOString(),
    "aggregation.alignmentPeriod": `${days * 86400}s`,
    "aggregation.perSeriesAligner": "ALIGN_SUM",
    "aggregation.crossSeriesReducer": "REDUCE_SUM",
  });
  const r = await fetch(
    `https://monitoring.googleapis.com/v3/projects/${PROJECT}/timeSeries?${p}`,
    { headers: auth() },
  );
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${r.status} ${j.error?.message || ""}`.trim());
  return (j.timeSeries || []).reduce((total, s) =>
    total + (s.points || []).reduce((t, pt) =>
      t + Number(pt.value.int64Value ?? pt.value.doubleValue ?? 0), 0), 0);
}

/** "abcd…" so reports can be discussed without full user ids. */
export const mask = (uid) => (uid ? `${`${uid}`.slice(0, 4)}…` : "-");
