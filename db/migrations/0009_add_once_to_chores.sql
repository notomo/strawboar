-- A chore due once has this column set: it is soon from this many days before
-- `next_due`, and it is archived when it is done. `interval_days` is then 1.
ALTER TABLE chores ADD COLUMN once_lead_days INTEGER;
