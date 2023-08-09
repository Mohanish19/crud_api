-- Post

CREATE OR REPLACE FUNCTION insert_subtask(event_data JSONB) RETURNS JSONB AS $$
DECLARE
    parent_subtask RECORD;
    inserted_row RECORD;
BEGIN
    IF NOT (event_data ->> 'title' IS NOT NULL AND event_data ->> 'description' IS NOT NULL AND event_data ->> 'status' IS NOT NULL) THEN
        RAISE EXCEPTION 'Title, description, and status are required fields.';
    END IF;

    SELECT * INTO parent_subtask
    FROM subtasks
    WHERE id = COALESCE(event_data ->> 'parent_task_id', event_data ->> 'parent_subtask_id')::INTEGER;

    IF event_data ->> 'parent_task_id' IS NOT NULL THEN
        event_data = event_data || JSONB_BUILD_OBJECT('task_id', parent_subtask.task_id::TEXT);
    END IF;

    INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
    VALUES (event_data ->> 'title', event_data ->> 'description', NOW(), event_data ->> 'status', parent_subtask.task_id, COALESCE(event_data ->> 'parent_task_id', event_data ->> 'parent_subtask_id')::INTEGER)
    RETURNING * INTO inserted_row;

    RETURN TO_JSONB(inserted_row);
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error inserting data: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Put 

CREATE OR REPLACE FUNCTION public.update_task(
	p_task_id integer,
	p_event_data jsonb)
    RETURNS jsonb
    
AS $BODY$
DECLARE
    v_result jsonb;
BEGIN

    IF NOT (p_event_data ? 'title' AND p_event_data ? 'description' AND p_event_data ? 'status') THEN
        RAISE EXCEPTION 'Title, description, and status are required fields.';
    END IF;

    p_event_data = p_event_data || jsonb_build_object('updated_time', now());

    UPDATE subtasks AS s
    SET
        title = p_event_data->>'title',
        description = p_event_data->>'description',
        status = p_event_data->>'status',
        parent_subtask_id = (p_event_data->>'parent_subtask_id')::integer
    WHERE
        s.id = p_task_id
    RETURNING to_jsonb(s.*) INTO v_result;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task or subtask not found';
    END IF;

    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating data: %', SQLERRM;
        RETURN '{"error": "Internal Server Error"}'::jsonb;
END;
$$ LANGUAGE plpgsql;

-- Get/Id

CREATE OR REPLACE FUNCTION get_task_with_subtasks(task_data jsonb)
RETURNS jsonb
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH RECURSIVE subtasks_recursive AS (
    SELECT id, title, description, created_time, status, task_id, parent_subtask_id
    FROM subtasks
    WHERE id = (task_data->>'task_id')::integer AND parent_subtask_id IS NULL

    UNION ALL

    SELECT s.id, s.title, s.description, s.created_time, s.status, s.task_id, s.parent_subtask_id
    FROM subtasks_recursive sr JOIN subtasks s ON sr.id = s.parent_subtask_id
  )
  SELECT jsonb_agg(subtasks_recursive.*) INTO result FROM subtasks_recursive;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- get

CREATE OR REPLACE FUNCTION get_tasks(p_params JSONB)
RETURNS JSONB AS $$
DECLARE
    limit_val INT;
    skip_val INT;
    order_val TEXT;
    order_by_val TEXT;
    group_by_val TEXT;
    query TEXT;
    result JSONB;
BEGIN
    limit_val := COALESCE((p_params ->> 'limit')::INT, NULL);
    skip_val := COALESCE((p_params ->> 'skip')::INT, NULL);
    order_val := COALESCE(p_params ->> 'order', 'desc');
    order_by_val := COALESCE(p_params ->> 'orderBy', 'created_time');
    group_by_val := COALESCE(p_params ->> 'groupBy', NULL);

    query := 'SELECT ';

    IF group_by_val = 'status' THEN
        query := query || 'jsonb_build_object(''status'', subquery.status, ''task_count'', subquery.task_count)';
        query := query || ' FROM (SELECT status, COUNT(*) AS task_count FROM subtasks';
    ELSE
        query := query || 'subtasks.* FROM subtasks';
    END IF;

    IF group_by_val = 'status' THEN
        query := query || ') AS subquery(status TEXT, task_count INT) GROUP BY status, created_time';
    END IF;

    IF order_by_val = 'created_time' OR order_by_val = 'updated_time' THEN
        query := query || ' ORDER BY ' || order_by_val || ' ' || order_val;
    ELSE
        query := query || ' ORDER BY created_time ' || order_val;
    END IF;

    IF limit_val IS NOT NULL THEN
        query := query || ' LIMIT ' || limit_val;
    END IF;

    IF skip_val IS NOT NULL THEN
        query := query || ' OFFSET ' || skip_val;
    END IF;

    EXECUTE 'SELECT jsonb_agg(result) FROM (' || query || ') result' INTO result;
    RETURN result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in dynamic query: %', SQLERRM USING HINT = 'Check your dynamic SQL construction and parameters.';
END;
$$ LANGUAGE plpgsql;

-- delete

CREATE OR REPLACE FUNCTION delete_task_with_subtasks(task_data jsonb)
RETURNS jsonb
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Check if the parent task exists
  IF NOT EXISTS (SELECT 1 FROM subtasks WHERE id = (task_data->>'task_id')::integer AND parent_subtask_id IS NULL) THEN
    result := jsonb_build_object('error', 'Parent task not found');
    RETURN result;
  END IF;

  BEGIN
    DELETE FROM subtasks WHERE task_id = (SELECT (task_data->>'task_id')::integer FROM subtasks WHERE id = (task_data->>'task_id')::integer);

    DELETE FROM subtasks WHERE id = (task_data->>'task_id')::integer AND parent_subtask_id IS NULL;

    result := jsonb_build_object('message', 'Parent task and associated subtasks deleted successfully');
    RETURN result;
  EXCEPTION
    WHEN OTHERS THEN
      result := jsonb_build_object('error', 'Failed to delete parent task and associated subtasks');
      RETURN result;
  END;
END;
$$ LANGUAGE plpgsql;
