-- 零压试玩版激活码（server/playtest/worker.mjs）。一个码第一次激活时绑定那台电脑。
CREATE TABLE IF NOT EXISTS zp_codes (
  code TEXT PRIMARY KEY,
  note TEXT NOT NULL DEFAULT '',
  machine TEXT,
  activated_at INTEGER,
  last_seen INTEGER,
  checks INTEGER NOT NULL DEFAULT 0,
  revoked INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
-- 玩家在试玩结束时同意上传的记录（zip 存在 R2）
CREATE TABLE IF NOT EXISTS zp_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  machine TEXT NOT NULL,
  r2_key TEXT NOT NULL,
  bytes INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
