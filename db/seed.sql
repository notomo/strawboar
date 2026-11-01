-- Test data for the local D1 (`node --run db:seed:local`). It deletes everything first.
-- Dates are relative to today in Asia/Tokyo so that every section has some chores.
DELETE FROM completions;
DELETE FROM chores;
DELETE FROM labels;
DELETE FROM sqlite_sequence WHERE name IN ('completions', 'chores', 'labels');

INSERT INTO labels (id, name, color) VALUES
  (1, 'Kitchen', 'orange'),
  (2, 'Bathroom', 'teal'),
  (3, 'Money', 'green'),
  (4, 'Outdoor', 'blue');

-- Soon: due today, overdue, in the last 20% of the interval and a monthly one.
-- Later: done recently, far from due, never done and a monthly one.
INSERT INTO chores (id, title, description, interval_days, monthly_months, monthly_day, monthly_lead_days, next_due, last_done, labels) VALUES
  (1, 'Water the plants', '', 3, NULL, NULL, NULL,
    date('now', '+9 hours'), date('now', '+9 hours', '-3 days'), '[4]'),
  (2, 'Clean the bathroom', 'Scrub the tub
Clean the mirror
Wipe the floor', 7, NULL, NULL, NULL,
    date('now', '+9 hours', '-2 days'), date('now', '+9 hours', '-9 days'), '[2]'),
  (3, 'Clean the fridge', '', 30, NULL, NULL, NULL,
    date('now', '+9 hours', '+4 days'), date('now', '+9 hours', '-26 days'), '[1]'),
  (4, 'Pay the rent', '', 30, 1, CAST(strftime('%d', 'now', '+9 hours', '+5 days') AS INTEGER), 7,
    date('now', '+9 hours', '+5 days'), date('now', '+9 hours', '-25 days'), '[3]'),
  (5, 'Take out recyclables', '', 14, NULL, NULL, NULL,
    date('now', '+9 hours', '+13 days'), date('now', '+9 hours', '-1 days'), '[1]'),
  (6, 'Replace the water filter', '', 90, NULL, NULL, NULL,
    date('now', '+9 hours', '+60 days'), date('now', '+9 hours', '-30 days'), '[1]'),
  (7, 'Wash the car', '', 30, NULL, NULL, NULL,
    date('now', '+9 hours', '+10 days'), NULL, '[4]'),
  (8, 'Pay the credit card', '', 30, 1, CAST(strftime('%d', 'now', '+9 hours', '+20 days') AS INTEGER), 3,
    date('now', '+9 hours', '+20 days'), NULL, '[3]');

-- More chores so that each tab has to scroll.
INSERT INTO chores (id, title, interval_days, next_due, last_done, labels) VALUES
  (10, 'Wipe the stove', 7, date('now', '+9 hours', '-1 days'), date('now', '+9 hours', '-8 days'), '[1]'),
  (11, 'Descale the kettle', 30, date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-35 days'), '[1]'),
  (12, 'Clean the toilet', 7, date('now', '+9 hours'), date('now', '+9 hours', '-7 days'), '[2]'),
  (13, 'Wash the bath mats', 14, date('now', '+9 hours', '-3 days'), date('now', '+9 hours', '-17 days'), '[2]'),
  (14, 'Vacuum the living room', 7, date('now', '+9 hours', '+1 days'), date('now', '+9 hours', '-6 days'), '[]'),
  (15, 'Change the bed sheets', 14, date('now', '+9 hours'), date('now', '+9 hours', '-14 days'), '[]'),
  (16, 'Check the bank balance', 7, date('now', '+9 hours', '-1 days'), date('now', '+9 hours', '-8 days'), '[3]'),
  (17, 'Sweep the balcony', 14, date('now', '+9 hours', '+2 days'), date('now', '+9 hours', '-12 days'), '[4]'),
  (18, 'Clean the microwave', 14, date('now', '+9 hours', '-7 days'), date('now', '+9 hours', '-21 days'), '[1]'),
  (19, 'Wash the towels', 5, date('now', '+9 hours'), date('now', '+9 hours', '-5 days'), '[2]'),
  (20, 'Mop the floor', 10, date('now', '+9 hours', '+1 days'), date('now', '+9 hours', '-9 days'), '[]'),
  (21, 'Empty the vacuum', 14, date('now', '+9 hours', '-2 days'), date('now', '+9 hours', '-16 days'), '[]'),
  (22, 'Clean the oven', 60, date('now', '+9 hours', '+40 days'), date('now', '+9 hours', '-20 days'), '[1]'),
  (23, 'Defrost the freezer', 180, date('now', '+9 hours', '+120 days'), date('now', '+9 hours', '-60 days'), '[1]'),
  (24, 'Clean the shower drain', 30, date('now', '+9 hours', '+20 days'), date('now', '+9 hours', '-10 days'), '[2]'),
  (25, 'Replace the toothbrush', 90, date('now', '+9 hours', '+70 days'), date('now', '+9 hours', '-20 days'), '[2]'),
  (26, 'Review subscriptions', 90, date('now', '+9 hours', '+50 days'), date('now', '+9 hours', '-40 days'), '[3]'),
  (27, 'File the receipts', 30, date('now', '+9 hours', '+25 days'), date('now', '+9 hours', '-5 days'), '[3]'),
  (28, 'Weed the garden', 14, date('now', '+9 hours', '+12 days'), date('now', '+9 hours', '-2 days'), '[4]'),
  (29, 'Clean the gutters', 180, date('now', '+9 hours', '+150 days'), date('now', '+9 hours', '-30 days'), '[4]'),
  (30, 'Wash the curtains', 180, date('now', '+9 hours', '+90 days'), date('now', '+9 hours', '-90 days'), '[]'),
  (31, 'Dust the shelves', 14, date('now', '+9 hours', '+13 days'), date('now', '+9 hours', '-1 days'), '[]'),
  (32, 'Clean the windows', 60, date('now', '+9 hours', '+58 days'), date('now', '+9 hours', '-2 days'), '[4]'),
  (33, 'Flip the mattress', 180, date('now', '+9 hours', '+175 days'), date('now', '+9 hours', '-5 days'), '[]');

INSERT INTO chores (id, title, interval_days, next_due, archived) VALUES
  (9, 'Archived chore', 7, date('now', '+9 hours'), 1);

-- Done: completions of the last 7 days. The latest of each chore can be undone.
INSERT INTO completions (chore_id, done_on, previous_next_due, previous_last_done) VALUES
  (1, date('now', '+9 hours', '-6 days'), date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-8 days')),
  (1, date('now', '+9 hours', '-3 days'), date('now', '+9 hours', '-3 days'), date('now', '+9 hours', '-6 days')),
  (5, date('now', '+9 hours', '-1 days'), date('now', '+9 hours', '-1 days'), date('now', '+9 hours', '-15 days')),
  (14, date('now', '+9 hours', '-6 days'), date('now', '+9 hours', '-6 days'), date('now', '+9 hours', '-13 days')),
  (19, date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-10 days')),
  (27, date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-35 days')),
  (28, date('now', '+9 hours', '-2 days'), date('now', '+9 hours', '-2 days'), date('now', '+9 hours', '-16 days')),
  (31, date('now', '+9 hours', '-1 days'), date('now', '+9 hours', '-1 days'), date('now', '+9 hours', '-15 days')),
  (32, date('now', '+9 hours', '-2 days'), date('now', '+9 hours', '-2 days'), date('now', '+9 hours', '-62 days')),
  (33, date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-5 days'), date('now', '+9 hours', '-185 days'));
