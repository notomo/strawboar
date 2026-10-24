-- Labels are created beforehand and shared by chores.
-- `color` is a palette name, e.g. 'blue'.
CREATE TABLE labels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL
);

INSERT INTO labels (name, color)
SELECT DISTINCT label.value, 'gray'
FROM chores, json_each(chores.labels) AS label
ORDER BY label.value;

-- `chores.labels` now holds a JSON array of label ids, e.g. '[1,3]'.
UPDATE chores SET labels = (
  SELECT json_group_array(labels.id)
  FROM json_each(chores.labels) AS label
  JOIN labels ON labels.name = label.value
);
