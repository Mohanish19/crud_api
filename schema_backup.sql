--
-- PostgreSQL database dump
--

-- Dumped from database version 15.4 (Ubuntu 15.4-1.pgdg22.04+1)
-- Dumped by pg_dump version 15.4 (Ubuntu 15.4-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: mohanish; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA mohanish;


--
-- Name: pranay; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pranay;


--
-- Name: task; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA task;


--
-- Name: test_schema; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA test_schema;


--
-- Name: user_schema; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA user_schema;


--
-- Name: create_task(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_task(task_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  parent_task_id_found integer;
  parent_subtask_id_found integer;
  result jsonb;
BEGIN
  IF task_data->>'parent_task_id' IS NOT NULL THEN
    SELECT id INTO parent_task_id_found FROM subtasks WHERE id = (task_data->>'parent_task_id')::integer;
    IF parent_task_id_found IS NULL THEN
      RAISE EXCEPTION 'Parent task not found';
    END IF;
  END IF;

  IF task_data->>'parent_subtask_id' IS NOT NULL THEN
    SELECT id INTO parent_subtask_id_found FROM subtasks WHERE id = (task_data->>'parent_subtask_id')::integer;
    IF parent_subtask_id_found IS NULL THEN
      RAISE EXCEPTION 'Parent subtask not found';
    END IF;
  END IF;

  IF task_data->>'parent_task_id' IS NOT NULL OR task_data->>'parent_subtask_id' IS NOT NULL THEN
    -- Creating a subtask
    INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
    VALUES (task_data->>'title', task_data->>'description', NOW(), task_data->>'status', COALESCE((task_data->>'parent_task_id')::integer, NULL), (task_data->>'parent_subtask_id')::integer)
    RETURNING id, title, description, created_time, status, task_id, parent_subtask_id INTO result;

  ELSE
    -- Creating a parent task
    INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
    VALUES (task_data->>'title', task_data->>'description', NOW(), task_data->>'status', NULL, NULL)
    RETURNING id, title, description, created_time, status, task_id, parent_subtask_id INTO result;

  END IF;

  RETURN result;
END;
$$;


--
-- Name: create_task(character varying, text, character varying, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_task(p_title character varying, p_description text, p_status character varying, p_parent_task_id uuid DEFAULT NULL::uuid, p_parent_subtask_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, title character varying, description text, created_time timestamp without time zone, status character varying, task_id uuid, parent_subtask_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_title IS NULL OR p_description IS NULL OR p_status IS NULL THEN
        RAISE EXCEPTION 'Title, description, and status are required fields.';
    END IF;

    INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
    VALUES (p_title, p_description, NOW(), p_status, NULL, NULL)
    RETURNING * INTO id, title, description, created_time, status, task_id, parent_subtask_id;

    IF p_parent_task_id IS NOT NULL THEN
        SELECT * INTO id, title, description, created_time, status, task_id, p_parent_task_id
        FROM subtasks WHERE id = p_parent_task_id;

        INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
        VALUES (p_title, p_description, NOW(), p_status, id, p_parent_task_id)
        RETURNING * INTO id, title, description, created_time, status, task_id, parent_subtask_id;
    END IF;

    IF p_parent_subtask_id IS NOT NULL THEN
        SELECT * INTO id, title, description, created_time, status, task_id, p_parent_subtask_id
        FROM subtasks WHERE id = p_parent_subtask_id;

        INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id)
        VALUES (p_title, p_description, NOW(), p_status, task_id, p_parent_subtask_id)
        RETURNING * INTO id, title, description, created_time, status, task_id, parent_subtask_id;
    END IF;
    
    RETURN;
END;
$$;


--
-- Name: create_user(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_user(p_user_data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO users (user_data)
    VALUES (p_user_data);
END;
$$;


--
-- Name: delete_task_with_subtasks(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_task_with_subtasks(task_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  result jsonb;
BEGIN
  -- Check if the parent task exists
  IF NOT EXISTS (SELECT 1 FROM subtasks WHERE id = (task_data->>'task_id')::integer AND parent_subtask_id IS NULL) THEN
    result := jsonb_build_object('error', 'Parent task not found');
    RETURN result;
  END IF;

  -- Begin a transaction to perform deletion
  BEGIN
    -- Delete all associated subtasks
    DELETE FROM subtasks WHERE task_id = (SELECT (task_data->>'task_id')::integer FROM subtasks WHERE id = (task_data->>'task_id')::integer);

    -- Delete the parent task
    DELETE FROM subtasks WHERE id = (task_data->>'task_id')::integer AND parent_subtask_id IS NULL;

    -- Construct a success message
    result := jsonb_build_object('message', 'Parent task and associated subtasks deleted successfully');
    RETURN result;
  EXCEPTION
    WHEN OTHERS THEN
      result := jsonb_build_object('error', 'Failed to delete parent task and associated subtasks');
      RETURN result;
  END;
END;
$$;


--
-- Name: delete_user(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_user(p_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    deleted_row user_table;
BEGIN
    DELETE FROM user_table
    WHERE id = p_id
    RETURNING * INTO deleted_row;

    RETURN row_to_json(deleted_row)::jsonb;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error deleting data: %', SQLERRM;
END;
$$;


--
-- Name: get_all_tasks(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_tasks(input_jsonb jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    result jsonb;
    schema_name text;
    table_name text;
BEGIN
    -- Extract schema_name and table_name from the input JSONB
    schema_name := input_jsonb->>'schema_name';
    table_name := input_jsonb->>'table_name';

    -- Use a subquery to select all rows from the specified schema and table
    SELECT jsonb_object_agg(t.task_id::text, row_to_json(t.*))
    INTO result
    FROM mohanish.tasks AS t
    WHERE EXISTS (
        SELECT 1
        FROM pg_catalog.pg_tables AS p
        WHERE p.schemaname = schema_name AND p.tablename = table_name
    );

    RETURN result;
END;
$$;


--
-- Name: get_task_with_subtasks(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_task_with_subtasks(task_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
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
$$;


--
-- Name: get_tasks(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_tasks(p_params jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: get_user_by_id(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_by_id(p_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT row_to_json(u) FROM (
        SELECT id, name, email, createdAt, updatedAt, userId
        FROM user_table
        WHERE id = p_id
    ) u);
END;
$$;


--
-- Name: insert_task(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_task(event_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: update_task(integer, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_task(p_task_id integer, p_event_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_result jsonb;
BEGIN
/*
SELECT * FROM update_task(
    p_task_id := 30, 
    p_event_data := '{"title": "Task no. 30 updated", "description": "Updated Description", "status": "In Progress", "parent_subtask_id": null}'::jsonb
);

*/
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
$$;


--
-- Name: update_task1(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_task1(input_params jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    task_id integer;
    client_id text;
    title text;
    description text;
    createdat timestamp without time zone;
    updatedat timestamp without time zone;
    assigned_to integer;
    updated_task jsonb;
BEGIN
    -- Extract values from the JSONB input
    task_id := (input_params ->> 'id')::integer;
    client_id := input_params ->> 'client_id';
    title := input_params ->> 'title';
    description := input_params ->> 'description';
    createdat := input_params ->> 'createdat'::timestamp;
    updatedat := input_params ->> 'updatedat'::timestamp;
    assigned_to := (input_params ->> 'assigned_to')::integer;

    -- Update the task
    UPDATE your_schema.your_table
    SET 
        client_id = input_params ->> 'client_id',
        title = input_params ->> 'title',
        description = input_params ->> 'description',
        createdat = input_params ->> 'createdat'::timestamp,
        updatedat = input_params ->> 'updatedat'::timestamp,
        assigned_to = (input_params ->> 'assigned_to')::integer
    WHERE id = task_id
    RETURNING to_jsonb(NEW) INTO updated_task;
    
    -- Check if any rows were updated
    IF FOUND THEN
        -- Include the updated task in the result JSONB
        RETURN updated_task;
    ELSE
        RAISE EXCEPTION 'Task with ID % not found.', task_id;
    END IF;
END;
$$;


--
-- Name: create_task(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.create_task(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_schema TEXT;
    inserted_row RECORD;
BEGIN
    p_schema := TRIM (p_data ->> 'clientId');

    SET search_path TO p_schema, public;
    
    INSERT INTO tasks (user_id, title, description, assignedTo, createdAt, updatedAt) 
	VALUES (p_data->>'userId', p_data->>'title',  p_data->>'description', p_data->>'assignedTo', NOW(), NULL) 
	RETURNING *     
    INTO inserted_row;

    RETURN to_jsonb(inserted_row);
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error creating task: %', SQLERRM;
END;
$$;


--
-- Name: delete_task(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.delete_task(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_schema TEXT;
    p_table TEXT;
    deleted_row RECORD;
BEGIN
    p_schema := format('client_%s', p_data->>'userId');
    p_table := format('tasks_%s', p_data->>'userId');
    
    EXECUTE format('DELETE FROM %I.%I WHERE id = $1 RETURNING *',
                   p_schema, p_table)
    INTO deleted_row
    USING (p_data->>'taskId')::INT;

    RETURN to_jsonb(deleted_row);
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error deleting task: %', SQLERRM;
END;
$_$;


--
-- Name: delete_task_by_id(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.delete_task_by_id(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_schema TEXT;
    deleted_row jsonb;
BEGIN
    -- Extract schema and ID from the JSONB argument
    p_schema := TRIM(p_data ->> 'schema');
    p_data := p_data - 'schema';  -- Remove the 'schema' key

    -- Set the search path to the specified schema and the public schema
    EXECUTE 'SET search_path TO ' || p_schema || ', public';

    -- Perform the task deletion query
    DELETE FROM tasks
    WHERE id = (p_data ->> 'id')::integer
    RETURNING * INTO deleted_row;  -- Return the deleted row

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No task found for id: %', (p_data ->> 'id');
    END IF;

    RETURN deleted_row;
END;
$$;


--
-- Name: get_task(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.get_task(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_schema TEXT;
    p_table TEXT;
    v_json JSONB;
BEGIN
    p_schema := format('client_%s', p_data->>'userId');
    p_table := format('tasks_%s', p_data->>'userId');
    
    EXECUTE format('SELECT row_to_json(u) FROM (SELECT id, user_id, title, description, assignedTo, createdAt, updatedAt FROM %I.%I WHERE id = $1) u', p_schema, p_table)
    INTO v_json
    USING (p_data->>'taskId')::INT;

    RETURN v_json;
END;
$_$;


--
-- Name: get_task_by_id(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.get_task_by_id(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_schema TEXT;
    result_row jsonb;
BEGIN
    -- Extract schema and ID from the JSONB argument
    p_schema := TRIM(p_data ->> 'schema');
    p_data := p_data - 'schema';  -- Remove the 'schema' key

    -- Set the search path to the specified schema and the public schema
    EXECUTE 'SET search_path TO ' || p_schema || ', public';

    -- Perform the task retrieval query
    SELECT to_jsonb(t)
    INTO result_row
    FROM tasks t
    WHERE t.id = (p_data ->> 'id')::integer; -- Extract and cast the 'id' from JSONB

    IF result_row IS NULL THEN
        RAISE EXCEPTION 'No task found for id: %', (p_data ->> 'id');
    END IF;

    RETURN result_row;
END;
$$;


--
-- Name: update_task(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.update_task(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_schema TEXT;
    updated_row jsonb;
BEGIN
    p_schema := TRIM(p_data ->> 'clientId');

    -- Set the search path to the specified schema and the public schema
    EXECUTE 'SET search_path TO ' || p_schema || ', public';

    -- Update the task in the "tasks" table, excluding "assignedTo"
    UPDATE tasks
    SET
        title = p_data->>'title',
        description = p_data->>'description',
        updatedat = NOW()
    WHERE
        id = (p_data->>'id')::integer; -- Assuming "id" is an integer

    -- Check if any rows were updated
    
        SELECT to_jsonb(t)
        INTO updated_row
        FROM tasks t
        WHERE id = (p_data->>'id')::integer;
        RETURN updated_row;
  

EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error updating task: %', SQLERRM;
END;
$$;


--
-- Name: test_create_task(text, text, text, integer); Type: FUNCTION; Schema: test_schema; Owner: -
--

CREATE FUNCTION test_schema.test_create_task(p_client_id text, p_title text, p_description text, p_assigned_to integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    task_id INTEGER;
BEGIN
    INSERT INTO test_tasks (client_id, title, description, createdat, updatedat, assigned_to)
    VALUES (p_client_id, p_title, p_description, NOW(), NULL, p_assigned_to)
    RETURNING id INTO task_id;

    RETURN task_id;
END;
$$;


--
-- Name: test_delete_task(integer); Type: FUNCTION; Schema: test_schema; Owner: -
--

CREATE FUNCTION test_schema.test_delete_task(p_task_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM test_tasks
    WHERE id = p_task_id;
END;
$$;


--
-- Name: test_retrieve_task(integer); Type: FUNCTION; Schema: test_schema; Owner: -
--

CREATE FUNCTION test_schema.test_retrieve_task(p_task_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT row_to_json(t)
        FROM test_tasks t
        WHERE t.id = p_task_id
    );
END;
$$;


--
-- Name: test_update_task(integer, text, text, integer); Type: FUNCTION; Schema: test_schema; Owner: -
--

CREATE FUNCTION test_schema.test_update_task(p_task_id integer, p_title text, p_description text, p_assigned_to integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE test_tasks
    SET
        title = p_title,
        description = p_description,
        assigned_to = p_assigned_to,
        updatedat = NOW()
    WHERE id = p_task_id;
END;
$$;


--
-- Name: create_user(jsonb); Type: FUNCTION; Schema: user_schema; Owner: -
--

CREATE FUNCTION user_schema.create_user(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    inserted_row user_schema.user_table;
BEGIN
    INSERT INTO user_schema.user_table(name, email, createdAt, updatedAt, userId)
    VALUES (
        p_data->>'name', 
        p_data->>'email', 
        NOW(), 
        NULL, 
        p_data->>'userId'
    )
    RETURNING * INTO inserted_row;

    RETURN row_to_json(inserted_row)::jsonb;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error inserting data: %', SQLERRM;
END;
$$;


--
-- Name: delete_user(integer); Type: FUNCTION; Schema: user_schema; Owner: -
--

CREATE FUNCTION user_schema.delete_user(p_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    deleted_row user_schema.user_table; 
BEGIN
    DELETE From user_schema.user_table -- Specify the schema explicitly
    WHERE id = p_id
    RETURNING * INTO deleted_row;

    RETURN row_to_json(deleted_row)::jsonb;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error deleting data: %', SQLERRM;
END;
$$;


--
-- Name: get_user(integer); Type: FUNCTION; Schema: user_schema; Owner: -
--

CREATE FUNCTION user_schema.get_user(p_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT row_to_json(u) FROM (
        SELECT id, name, email, createdAt, updatedAt, userId
        FROM user_schema.user_table
        WHERE id = p_id
    ) u);
END;
$$;


--
-- Name: update_user(integer, jsonb); Type: FUNCTION; Schema: user_schema; Owner: -
--

CREATE FUNCTION user_schema.update_user(p_id integer, p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    updated_row user_schema.user_table;
BEGIN
    UPDATE user_schema.user_table
    SET 
        name = p_data->>'name',
        email = p_data->>'email',
        updatedAt = NOW()
    WHERE id = p_id
    RETURNING * INTO updated_row;

    RETURN row_to_json(updated_row)::jsonb;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error updating data: %', SQLERRM;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tasks; Type: TABLE; Schema: mohanish; Owner: -
--

CREATE TABLE mohanish.tasks (
    id integer NOT NULL,
    client_id text,
    title text,
    description text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone,
    assigned_to integer
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: mohanish; Owner: -
--

CREATE SEQUENCE mohanish.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: mohanish; Owner: -
--

ALTER SEQUENCE mohanish.tasks_id_seq OWNED BY mohanish.tasks.id;


--
-- Name: tasks; Type: TABLE; Schema: pranay; Owner: -
--

CREATE TABLE pranay.tasks (
    id integer NOT NULL,
    client_id text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    createdat timestamp without time zone,
    updatedat timestamp without time zone,
    assigned_to integer
);


--
-- Name: client1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client1 (
    taskid integer,
    clientid integer,
    title character varying(100),
    createdat timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_to character varying(20)
);


--
-- Name: subtasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subtasks (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text NOT NULL,
    created_time timestamp without time zone NOT NULL,
    status character varying(20) NOT NULL,
    parent_subtask_id integer,
    updated_time timestamp without time zone,
    task_id integer
);


--
-- Name: subtasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subtasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subtasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subtasks_id_seq OWNED BY public.subtasks.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id integer NOT NULL,
    user_id text,
    title text,
    description text,
    assignedto text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: tasks; Type: TABLE; Schema: test_schema; Owner: -
--

CREATE TABLE test_schema.tasks (
    id integer NOT NULL,
    client_id text,
    title text,
    description text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone,
    assigned_to integer
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: test_schema; Owner: -
--

CREATE SEQUENCE test_schema.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: test_schema; Owner: -
--

ALTER SEQUENCE test_schema.tasks_id_seq OWNED BY test_schema.tasks.id;


--
-- Name: test_tasks; Type: TABLE; Schema: test_schema; Owner: -
--

CREATE TABLE test_schema.test_tasks (
    id integer NOT NULL,
    client_id text,
    title text,
    description text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone,
    assigned_to integer
);


--
-- Name: test_tasks_id_seq; Type: SEQUENCE; Schema: test_schema; Owner: -
--

CREATE SEQUENCE test_schema.test_tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: test_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: test_schema; Owner: -
--

ALTER SEQUENCE test_schema.test_tasks_id_seq OWNED BY test_schema.test_tasks.id;


--
-- Name: user; Type: TABLE; Schema: user_schema; Owner: -
--

CREATE TABLE user_schema."user" (
    id integer NOT NULL,
    user_id text,
    client_id text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_table_id_seq; Type: SEQUENCE; Schema: user_schema; Owner: -
--

CREATE SEQUENCE user_schema.user_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_table_id_seq; Type: SEQUENCE OWNED BY; Schema: user_schema; Owner: -
--

ALTER SEQUENCE user_schema.user_table_id_seq OWNED BY user_schema."user".id;


--
-- Name: tasks id; Type: DEFAULT; Schema: mohanish; Owner: -
--

ALTER TABLE ONLY mohanish.tasks ALTER COLUMN id SET DEFAULT nextval('mohanish.tasks_id_seq'::regclass);


--
-- Name: subtasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subtasks ALTER COLUMN id SET DEFAULT nextval('public.subtasks_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: test_schema; Owner: -
--

ALTER TABLE ONLY test_schema.tasks ALTER COLUMN id SET DEFAULT nextval('test_schema.tasks_id_seq'::regclass);


--
-- Name: test_tasks id; Type: DEFAULT; Schema: test_schema; Owner: -
--

ALTER TABLE ONLY test_schema.test_tasks ALTER COLUMN id SET DEFAULT nextval('test_schema.test_tasks_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: user_schema; Owner: -
--

ALTER TABLE ONLY user_schema."user" ALTER COLUMN id SET DEFAULT nextval('user_schema.user_table_id_seq'::regclass);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: mohanish; Owner: -
--

ALTER TABLE ONLY mohanish.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: pranay; Owner: -
--

ALTER TABLE ONLY pranay.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: subtasks subtasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subtasks
    ADD CONSTRAINT subtasks_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: test_schema; Owner: -
--

ALTER TABLE ONLY test_schema.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: test_tasks test_tasks_pkey; Type: CONSTRAINT; Schema: test_schema; Owner: -
--

ALTER TABLE ONLY test_schema.test_tasks
    ADD CONSTRAINT test_tasks_pkey PRIMARY KEY (id);


--
-- Name: user user_table_pkey; Type: CONSTRAINT; Schema: user_schema; Owner: -
--

ALTER TABLE ONLY user_schema."user"
    ADD CONSTRAINT user_table_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_assigned_to_fkey; Type: FK CONSTRAINT; Schema: mohanish; Owner: -
--

ALTER TABLE ONLY mohanish.tasks
    ADD CONSTRAINT tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES user_schema."user"(id) NOT VALID;


--
-- Name: tasks tasks_assigned_to_fkey; Type: FK CONSTRAINT; Schema: test_schema; Owner: -
--

ALTER TABLE ONLY test_schema.tasks
    ADD CONSTRAINT tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES user_schema."user"(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

