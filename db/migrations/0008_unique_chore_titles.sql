-- The import matches chores by title, so active chores have unique titles.
-- Archived chores keep theirs, so a title can be reused after archiving.
CREATE UNIQUE INDEX chores_active_title ON chores (title) WHERE archived = 0;
