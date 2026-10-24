-- Free notes of a chore such as the steps. Empty if none.
ALTER TABLE chores ADD COLUMN description TEXT NOT NULL DEFAULT '';
