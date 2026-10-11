-- Monthly chores are due on a fixed day of the month and have all three
-- columns set; `interval_days` then holds the approximate interval.
ALTER TABLE chores ADD COLUMN monthly_months INTEGER;
ALTER TABLE chores ADD COLUMN monthly_day INTEGER;
ALTER TABLE chores ADD COLUMN monthly_lead_days INTEGER;
