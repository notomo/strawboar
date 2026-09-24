-- Dates are stored as local dates (YYYY-MM-DD, Asia/Tokyo).
CREATE TABLE chores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  interval_days INTEGER NOT NULL CHECK (interval_days > 0),
  next_due TEXT NOT NULL,
  last_done TEXT,
  archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE completions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chore_id INTEGER NOT NULL REFERENCES chores (id) ON DELETE CASCADE,
  done_on TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX completions_chore_id_done_on ON completions (chore_id, done_on);
