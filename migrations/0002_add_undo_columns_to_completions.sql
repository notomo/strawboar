-- State of the chore before the completion, used to undo it.
ALTER TABLE completions ADD COLUMN previous_next_due TEXT;
ALTER TABLE completions ADD COLUMN previous_last_done TEXT;
