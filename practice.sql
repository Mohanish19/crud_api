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

-- get method

CREATE OR REPLACE FUNCTION get_tasks(limit integer, skip integer, order_by text, order text, group_by text DEFAULT NULL)
RETURNS TABLE (id integer, title text, description text, created_time timestamp, status text, task_id integer, parent_subtask_id integer, task_count integer)
AS $$
BEGIN
  IF group_by = 'status' THEN
    -- Get tasks grouped by status
    RETURN QUERY
    SELECT status, COUNT(*) AS task_count
    FROM subtasks
    GROUP BY status
    ORDER BY CASE WHEN order_by = 'created_time' OR order_by = 'updated_time' THEN order_by END || ' ' || order
    LIMIT limit
    OFFSET skip;
  ELSE
    -- Get tasks without grouping
    RETURN QUERY
    SELECT *
    FROM subtasks
    ORDER BY CASE WHEN order_by = 'created_time' OR order_by = 'updated_time' THEN order_by END || ' ' || order
    LIMIT limit
    OFFSET skip;
  END IF;
END;
$$ LANGUAGE plpgsql;


--  get/id methofd

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


-- put method

CREATE OR REPLACE FUNCTION update_task(id integer, title text, description text, status text, parent_subtask_id integer DEFAULT NULL)
RETURNS TABLE (id integer, title text, description text, created_time timestamp, updated_time timestamp, status text, task_id integer, parent_subtask_id integer)
AS $$
BEGIN
  IF parent_subtask_id = 'PROMOTE' THEN
    -- Promote the subtask to an independent task (remove parent_subtask_id)
    RETURN QUERY
    UPDATE subtasks
    SET title = title, description = description, updated_time = NOW(), status = status, parent_subtask_id = NULL
    WHERE id = id
    RETURNING *;
  ELSE
    -- Check if the task or subtask exists in the subtasks table
    RETURN QUERY
    UPDATE subtasks
    SET title = title, description = description, updated_time = NOW(), status = status, parent_subtask_id = parent_subtask_id
    WHERE id = id AND (parent_subtask_id IS NULL OR parent_subtask_id = parent_subtask_id)
    RETURNING *;
  END IF;
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
