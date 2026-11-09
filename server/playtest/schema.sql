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
-- 公测版 2026-11-08：不再用激活码，第一次启动按机器指纹登记，每次启动报到（/hello）
CREATE TABLE IF NOT EXISTS zp_machines (
  machine TEXT PRIMARY KEY,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  checks INTEGER NOT NULL DEFAULT 0,
  version TEXT NOT NULL DEFAULT '',
  revoked INTEGER NOT NULL DEFAULT 0
);
-- 总开关：closed = '1' 时所有人都进不去，显示 closed_text（默认“公测已结束，谢谢！”）
CREATE TABLE IF NOT EXISTS zp_flags (
  k TEXT PRIMARY KEY,
  v TEXT NOT NULL
);
-- 玩家反馈（截图 JPG 和日志尾部存在 R2：shot_key / log_key）
CREATE TABLE IF NOT EXISTS zp_feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  machine TEXT NOT NULL,
  kind TEXT NOT NULL,
  text TEXT NOT NULL,
  version TEXT NOT NULL DEFAULT '',
  played_s INTEGER NOT NULL DEFAULT 0,
  chapter TEXT NOT NULL DEFAULT '',
  ship TEXT NOT NULL DEFAULT '',
  shot_key TEXT NOT NULL DEFAULT '',
  shot_bytes INTEGER NOT NULL DEFAULT 0,
  log_key TEXT NOT NULL DEFAULT '',
  made_at TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS zp_feedback_machine ON zp_feedback (machine, created_at);
