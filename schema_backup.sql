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
-- Name: create_task(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.create_task(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_schema TEXT;
    p_table TEXT;
    inserted_row RECORD;
BEGIN
    p_schema := format('client_%s', p_data->>'userId');
    p_table := 'tasks';
    
    -- Set the schema search path
    SET search_path TO p_schema, public;
    
    -- Create schema if not exists
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', p_schema);
    
    -- Create table if not exists in the specific schema
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I (
                    id SERIAL PRIMARY KEY,
                    user_id TEXT,
                    title TEXT,
                    description TEXT,
                    assignedTo TEXT,
                    createdAt TIMESTAMPTZ,
                    updatedAt TIMESTAMPTZ
                )', p_schema, p_table);
    
    -- Insert into tasks table
    EXECUTE format('INSERT INTO %I.%I (user_id, title, description, assignedTo, createdAt, updatedAt) VALUES ($1, $2, $3, $4, NOW(), NULL) RETURNING *',
                   p_schema, p_table)
    INTO inserted_row
    USING p_data->>'userId', p_data->>'title', p_data->>'description', p_data->>'assignedTo';

    -- Update user details in user_table if user exists
    UPDATE user_schema.user_table
    SET schema_name = p_schema, updated_at = NOW()
    WHERE user_id = p_data->>'userId';

    -- If user does not exist, insert into user_table
    INSERT INTO user_schema.user_table (user_id, schema_name, created_at, updated_at)
    SELECT p_data->>'userId', p_schema, NOW(), NULL
    WHERE NOT EXISTS (SELECT 1 FROM user_schema.user_table WHERE user_id = p_data->>'userId');

    RETURN to_jsonb(inserted_row);
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error creating task: %', SQLERRM;
END;
$_$;


--
-- Name: create_task1(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.create_task1(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_schema TEXT;
    p_table TEXT;
    inserted_row RECORD;
BEGIN
    p_schema := format('client_%s', p_data->>'userId');
    p_table := 'tasks';
    
    -- Set the schema search path
    SET search_path TO p_schema, public;
    
    -- Create schema if not exists
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', p_schema);
    
    -- Create table if not exists in the specific schema
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I (
                    id SERIAL PRIMARY KEY,
                    user_id TEXT,
                    title TEXT,
                    description TEXT,
                    assignedTo TEXT,
                    createdAt TIMESTAMPTZ,
                    updatedAt TIMESTAMPTZ
                )', p_schema, p_table);
    
    -- Insert into tasks table
    EXECUTE format('INSERT INTO %I.%I (user_id, title, description, assignedTo, createdAt, updatedAt) VALUES ($1, $2, $3, $4, NOW(), NULL) RETURNING *',
                   p_schema, p_table)
    INTO inserted_row
    USING p_data->>'userId', p_data->>'title', p_data->>'description', p_data->>'assignedTo';

    -- Update user details in user_table if user exists
    UPDATE user_schema.user_table
    SET schema_name = p_schema, updated_at = NOW()
    WHERE user_id = p_data->>'userId';

    -- If user does not exist, insert into user_table
    INSERT INTO user_schema.user_table (user_id, schema_name, created_at, updated_at)
    SELECT p_data->>'userId', p_schema, NOW(), NULL
    WHERE NOT EXISTS (SELECT 1 FROM user_schema.user_table WHERE user_id = p_data->>'userId');

    RETURN to_jsonb(inserted_row);
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error creating task: %', SQLERRM;
END;
$_$;


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
-- Name: update_task(jsonb); Type: FUNCTION; Schema: task; Owner: -
--

CREATE FUNCTION task.update_task(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_schema TEXT;
    p_table TEXT;
    updated_row RECORD;
BEGIN
    p_schema := format('client_%s', p_data->>'userId');
    p_table := format('tasks_%s', p_data->>'userId');
    
    EXECUTE format('UPDATE %I.%I SET title = $2, description = $3, assignedTo = $4, updatedAt = NOW() WHERE id = $1 RETURNING *',
                   p_schema, p_table)
    INTO updated_row
    USING (p_data->>'taskId')::INT, (p_data->>'title'), (p_data->>'description'), (p_data->>'assignedTo');

    RETURN to_jsonb(updated_row);
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error updating task: %', SQLERRM;
END;
$_$;


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
-- Name: user_table; Type: TABLE; Schema: user_schema; Owner: -
--

CREATE TABLE user_schema.user_table (
    id integer NOT NULL,
    user_id text,
    schema_name text,
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

ALTER SEQUENCE user_schema.user_table_id_seq OWNED BY user_schema.user_table.id;


--
-- Name: subtasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subtasks ALTER COLUMN id SET DEFAULT nextval('public.subtasks_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: user_table id; Type: DEFAULT; Schema: user_schema; Owner: -
--

ALTER TABLE ONLY user_schema.user_table ALTER COLUMN id SET DEFAULT nextval('user_schema.user_table_id_seq'::regclass);


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
-- Name: user_table user_table_pkey; Type: CONSTRAINT; Schema: user_schema; Owner: -
--

ALTER TABLE ONLY user_schema.user_table
    ADD CONSTRAINT user_table_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

