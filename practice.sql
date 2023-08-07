-- To create a task (/post) method
CREATE OR REPLACE FUNCTION create_task(title text, description text, status text, parent_task_id integer DEFAULT NULL, parent_subtask_id integer DEFAULT NULL)
RETURNS TABLE (id integer, title text, description text, created_time timestamp, status text, task_id integer, parent_subtask_id integer)
AS $$
DECLARE
  parent_task_id_found integer;
  parent_subtask_id_found integer;
BEGIN
  IF parent_task_id IS NOT NULL THEN
    SELECT id INTO parent_task_id_found FROM subtasks WHERE id = parent_task_id;
    IF parent_task_id_found IS NULL THEN
      RAISE EXCEPTION 'Parent task not found';
    END IF;
  END IF;

  IF parent_subtask_id IS NOT NULL THEN
    SELECT id INTO parent_subtask_id_found FROM subtasks WHERE id = parent_subtask_id;
    IF parent_subtask_id_found IS NULL THEN
      RAISE EXCEPTION 'Parent subtask not found';
    END IF;
  END IF;

  IF parent_task_id IS NOT NULL OR parent_subtask_id IS NOT NULL THEN
    -- Creating a subtask
    INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
    VALUES (title, description, NOW(), status, COALESCE(parent_task_id, NULL), parent_subtask_id)
    RETURNING id, title, description, created_time, status, task_id, parent_subtask_id INTO id, title, description, created_time, status, task_id, parent_subtask_id;

  ELSE
    -- Creating a parent task
    INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
    VALUES (title, description, NOW(), status, NULL, NULL)
    RETURNING id, title, description, created_time, status, task_id, parent_subtask_id INTO id, title, description, created_time, status, task_id, parent_subtask_id;

  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql;

--  get/id method

CREATE OR REPLACE FUNCTION get_task_with_subtasks(task_id integer)
RETURNS TABLE (id integer, title text, description text, created_time timestamp, status text, task_id integer, parent_subtask_id integer)
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE subtasks_recursive AS (
    SELECT id, title, description, created_time, status, task_id, parent_subtask_id
    FROM subtasks
    WHERE id = task_id AND parent_subtask_id IS NULL

    UNION ALL

    SELECT s.id, s.title, s.description, s.created_time, s.status, s.task_id, s.parent_subtask_id
    FROM subtasks_recursive sr JOIN subtasks s ON sr.id = s.parent_subtask_id
  )
  SELECT * FROM subtasks_recursive;
END;
$$ LANGUAGE plpgsql;

-- delete method

CREATE OR REPLACE FUNCTION delete_task_with_subtasks(task_id integer)
RETURNS void
AS $$
BEGIN
  -- Check if the parent task exists
  IF NOT EXISTS (SELECT 1 FROM subtasks WHERE id = task_id AND parent_subtask_id IS NULL) THEN
    RAISE EXCEPTION 'Parent task not found';
  END IF;

  -- Begin a transaction to perform deletion
  BEGIN
    -- Delete all associated subtasks
    DELETE FROM subtasks WHERE task_id = (SELECT task_id FROM subtasks WHERE id = task_id);

    -- Delete the parent task
    DELETE FROM subtasks WHERE id = task_id AND parent_subtask_id IS NULL;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Failed to delete parent task and associated subtasks';
  END;
END;
$$ LANGUAGE plpgsql;
