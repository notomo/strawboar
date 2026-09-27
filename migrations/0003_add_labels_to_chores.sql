-- JSON array of label names, e.g. '["kitchen","weekly"]'.
ALTER TABLE chores ADD COLUMN labels TEXT NOT NULL DEFAULT '[]';
