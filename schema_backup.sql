PGDMP     '                    {            first_db     15.4 (Ubuntu 15.4-1.pgdg22.04+1)     15.4 (Ubuntu 15.4-1.pgdg22.04+1) T    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    16387    first_db    DATABASE     n   CREATE DATABASE first_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_IN';
    DROP DATABASE first_db;
                postgres    false            	            2615    16992    mohanish    SCHEMA        CREATE SCHEMA mohanish;
    DROP SCHEMA mohanish;
                postgres    false            
            2615    17050    pranay    SCHEMA        CREATE SCHEMA pranay;
    DROP SCHEMA pranay;
                postgres    false                        2615    16572    task    SCHEMA        CREATE SCHEMA task;
    DROP SCHEMA task;
                postgres    false                        2615    16986    test_schema    SCHEMA        CREATE SCHEMA test_schema;
    DROP SCHEMA test_schema;
                postgres    false                        2615    16563    user_schema    SCHEMA        CREATE SCHEMA user_schema;
    DROP SCHEMA user_schema;
                postgres    false            �            1255    16527    create_task(jsonb)    FUNCTION     \  CREATE FUNCTION public.create_task(task_data jsonb) RETURNS jsonb
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
 3   DROP FUNCTION public.create_task(task_data jsonb);
       public          postgres    false            �            1255    16512 C   create_task(character varying, text, character varying, uuid, uuid)    FUNCTION     "  CREATE FUNCTION public.create_task(p_title character varying, p_description text, p_status character varying, p_parent_task_id uuid DEFAULT NULL::uuid, p_parent_subtask_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, title character varying, description text, created_time timestamp without time zone, status character varying, task_id uuid, parent_subtask_id uuid)
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
 �   DROP FUNCTION public.create_task(p_title character varying, p_description text, p_status character varying, p_parent_task_id uuid, p_parent_subtask_id uuid);
       public          postgres    false            �            1255    16580    create_user(jsonb)    FUNCTION     �   CREATE FUNCTION public.create_user(p_user_data jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO users (user_data)
    VALUES (p_user_data);
END;
$$;
 5   DROP FUNCTION public.create_user(p_user_data jsonb);
       public          postgres    false            �            1255    16528     delete_task_with_subtasks(jsonb)    FUNCTION     C  CREATE FUNCTION public.delete_task_with_subtasks(task_data jsonb) RETURNS jsonb
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
 A   DROP FUNCTION public.delete_task_with_subtasks(task_data jsonb);
       public          postgres    false            �            1255    16640    delete_user(integer)    FUNCTION     i  CREATE FUNCTION public.delete_user(p_id integer) RETURNS jsonb
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
 0   DROP FUNCTION public.delete_user(p_id integer);
       public          postgres    false                       1255    17061    get_all_tasks(jsonb)    FUNCTION     �  CREATE FUNCTION public.get_all_tasks(input_jsonb jsonb) RETURNS jsonb
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
 7   DROP FUNCTION public.get_all_tasks(input_jsonb jsonb);
       public          postgres    false            �            1255    16526    get_task_with_subtasks(jsonb)    FUNCTION     �  CREATE FUNCTION public.get_task_with_subtasks(task_data jsonb) RETURNS jsonb
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
 >   DROP FUNCTION public.get_task_with_subtasks(task_data jsonb);
       public          postgres    false            �            1255    16531    get_tasks(jsonb)    FUNCTION     �  CREATE FUNCTION public.get_tasks(p_params jsonb) RETURNS jsonb
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
 0   DROP FUNCTION public.get_tasks(p_params jsonb);
       public          postgres    false            �            1255    16638    get_user_by_id(integer)    FUNCTION       CREATE FUNCTION public.get_user_by_id(p_id integer) RETURNS jsonb
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
 3   DROP FUNCTION public.get_user_by_id(p_id integer);
       public          postgres    false            �            1255    16535    insert_task(jsonb)    FUNCTION     �  CREATE FUNCTION public.insert_task(event_data jsonb) RETURNS jsonb
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
 4   DROP FUNCTION public.insert_task(event_data jsonb);
       public          postgres    false                       1255    16540    update_task(integer, jsonb)    FUNCTION     �  CREATE FUNCTION public.update_task(p_task_id integer, p_event_data jsonb) RETURNS jsonb
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
 I   DROP FUNCTION public.update_task(p_task_id integer, p_event_data jsonb);
       public          postgres    false            
           1255    17069    update_task1(jsonb)    FUNCTION     �  CREATE FUNCTION public.update_task1(input_params jsonb) RETURNS jsonb
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
 7   DROP FUNCTION public.update_task1(input_params jsonb);
       public          postgres    false            	           1255    16663    create_task(jsonb)    FUNCTION     f  CREATE FUNCTION task.create_task(p_data jsonb) RETURNS jsonb
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
 .   DROP FUNCTION task.create_task(p_data jsonb);
       task          postgres    false    7            �            1255    16691    delete_task(jsonb)    FUNCTION     C  CREATE FUNCTION task.delete_task(p_data jsonb) RETURNS jsonb
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
 .   DROP FUNCTION task.delete_task(p_data jsonb);
       task          postgres    false    7                       1255    17074    delete_task_by_id(jsonb)    FUNCTION     �  CREATE FUNCTION task.delete_task_by_id(p_data jsonb) RETURNS jsonb
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
 4   DROP FUNCTION task.delete_task_by_id(p_data jsonb);
       task          postgres    false    7            �            1255    16689    get_task(jsonb)    FUNCTION       CREATE FUNCTION task.get_task(p_data jsonb) RETURNS jsonb
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
 +   DROP FUNCTION task.get_task(p_data jsonb);
       task          postgres    false    7                       1255    17073    get_task_by_id(jsonb)    FUNCTION       CREATE FUNCTION task.get_task_by_id(p_data jsonb) RETURNS jsonb
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
 1   DROP FUNCTION task.get_task_by_id(p_data jsonb);
       task          postgres    false    7                       1255    16690    update_task(jsonb)    FUNCTION     �  CREATE FUNCTION task.update_task(p_data jsonb) RETURNS jsonb
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
 .   DROP FUNCTION task.update_task(p_data jsonb);
       task          postgres    false    7                       1255    17046 +   test_create_task(text, text, text, integer)    FUNCTION     �  CREATE FUNCTION test_schema.test_create_task(p_client_id text, p_title text, p_description text, p_assigned_to integer) RETURNS integer
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
 w   DROP FUNCTION test_schema.test_create_task(p_client_id text, p_title text, p_description text, p_assigned_to integer);
       test_schema          postgres    false    8                       1255    17049    test_delete_task(integer)    FUNCTION     �   CREATE FUNCTION test_schema.test_delete_task(p_task_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM test_tasks
    WHERE id = p_task_id;
END;
$$;
 ?   DROP FUNCTION test_schema.test_delete_task(p_task_id integer);
       test_schema          postgres    false    8                       1255    17047    test_retrieve_task(integer)    FUNCTION     �   CREATE FUNCTION test_schema.test_retrieve_task(p_task_id integer) RETURNS jsonb
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
 A   DROP FUNCTION test_schema.test_retrieve_task(p_task_id integer);
       test_schema          postgres    false    8                       1255    17048 .   test_update_task(integer, text, text, integer)    FUNCTION     i  CREATE FUNCTION test_schema.test_update_task(p_task_id integer, p_title text, p_description text, p_assigned_to integer) RETURNS void
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
 x   DROP FUNCTION test_schema.test_update_task(p_task_id integer, p_title text, p_description text, p_assigned_to integer);
       test_schema          postgres    false    8            �            1255    16637    create_user(jsonb)    FUNCTION     "  CREATE FUNCTION user_schema.create_user(p_data jsonb) RETURNS jsonb
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
 5   DROP FUNCTION user_schema.create_user(p_data jsonb);
       user_schema          postgres    false    6                       1255    16657    delete_user(integer)    FUNCTION     �  CREATE FUNCTION user_schema.delete_user(p_id integer) RETURNS jsonb
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
 5   DROP FUNCTION user_schema.delete_user(p_id integer);
       user_schema          postgres    false    6                        1255    16654    get_user(integer)    FUNCTION       CREATE FUNCTION user_schema.get_user(p_id integer) RETURNS jsonb
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
 2   DROP FUNCTION user_schema.get_user(p_id integer);
       user_schema          postgres    false    6                       1255    16653    update_user(integer, jsonb)    FUNCTION     �  CREATE FUNCTION user_schema.update_user(p_id integer, p_data jsonb) RETURNS jsonb
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
 C   DROP FUNCTION user_schema.update_user(p_id integer, p_data jsonb);
       user_schema          postgres    false    6            �            1259    16994    tasks    TABLE     �   CREATE TABLE mohanish.tasks (
    id integer NOT NULL,
    client_id text,
    title text,
    description text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone,
    assigned_to integer
);
    DROP TABLE mohanish.tasks;
       mohanish         heap    postgres    false    9            �            1259    16993    tasks_id_seq    SEQUENCE     �   CREATE SEQUENCE mohanish.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE mohanish.tasks_id_seq;
       mohanish          postgres    false    9    227            �           0    0    tasks_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE mohanish.tasks_id_seq OWNED BY mohanish.tasks.id;
          mohanish          postgres    false    226            �            1259    17051    tasks    TABLE     �   CREATE TABLE pranay.tasks (
    id integer NOT NULL,
    client_id text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    createdat timestamp without time zone,
    updatedat timestamp without time zone,
    assigned_to integer
);
    DROP TABLE pranay.tasks;
       pranay         heap    postgres    false    10            �            1259    16545    client1    TABLE     �   CREATE TABLE public.client1 (
    taskid integer,
    clientid integer,
    title character varying(100),
    createdat timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_to character varying(20)
);
    DROP TABLE public.client1;
       public         heap    postgres    false            �            1259    16457    subtasks    TABLE     H  CREATE TABLE public.subtasks (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text NOT NULL,
    created_time timestamp without time zone NOT NULL,
    status character varying(20) NOT NULL,
    parent_subtask_id integer,
    updated_time timestamp without time zone,
    task_id integer
);
    DROP TABLE public.subtasks;
       public         heap    postgres    false            �            1259    16456    subtasks_id_seq    SEQUENCE     �   CREATE SEQUENCE public.subtasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.subtasks_id_seq;
       public          postgres    false    220            �           0    0    subtasks_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.subtasks_id_seq OWNED BY public.subtasks.id;
          public          postgres    false    219            �            1259    16947    tasks    TABLE     �   CREATE TABLE public.tasks (
    id integer NOT NULL,
    user_id text,
    title text,
    description text,
    assignedto text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone
);
    DROP TABLE public.tasks;
       public         heap    postgres    false            �            1259    16946    tasks_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.tasks_id_seq;
       public          postgres    false    225            �           0    0    tasks_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;
          public          postgres    false    224            �            1259    17003    tasks    TABLE     �   CREATE TABLE test_schema.tasks (
    id integer NOT NULL,
    client_id text,
    title text,
    description text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone,
    assigned_to integer
);
    DROP TABLE test_schema.tasks;
       test_schema         heap    postgres    false    8            �            1259    17002    tasks_id_seq    SEQUENCE     �   CREATE SEQUENCE test_schema.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE test_schema.tasks_id_seq;
       test_schema          postgres    false    8    229            �           0    0    tasks_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE test_schema.tasks_id_seq OWNED BY test_schema.tasks.id;
          test_schema          postgres    false    228            �            1259    17038 
   test_tasks    TABLE     �   CREATE TABLE test_schema.test_tasks (
    id integer NOT NULL,
    client_id text,
    title text,
    description text,
    createdat timestamp with time zone,
    updatedat timestamp with time zone,
    assigned_to integer
);
 #   DROP TABLE test_schema.test_tasks;
       test_schema         heap    postgres    false    8            �            1259    17037    test_tasks_id_seq    SEQUENCE     �   CREATE SEQUENCE test_schema.test_tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE test_schema.test_tasks_id_seq;
       test_schema          postgres    false    231    8            �           0    0    test_tasks_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE test_schema.test_tasks_id_seq OWNED BY test_schema.test_tasks.id;
          test_schema          postgres    false    230            �            1259    16643    user    TABLE     �   CREATE TABLE user_schema."user" (
    id integer NOT NULL,
    user_id text,
    client_id text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);
    DROP TABLE user_schema."user";
       user_schema         heap    postgres    false    6            �            1259    16642    user_table_id_seq    SEQUENCE     �   CREATE SEQUENCE user_schema.user_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE user_schema.user_table_id_seq;
       user_schema          postgres    false    6    223            �           0    0    user_table_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE user_schema.user_table_id_seq OWNED BY user_schema."user".id;
          user_schema          postgres    false    222            �           2604    16997    tasks id    DEFAULT     h   ALTER TABLE ONLY mohanish.tasks ALTER COLUMN id SET DEFAULT nextval('mohanish.tasks_id_seq'::regclass);
 9   ALTER TABLE mohanish.tasks ALTER COLUMN id DROP DEFAULT;
       mohanish          postgres    false    226    227    227            �           2604    16460    subtasks id    DEFAULT     j   ALTER TABLE ONLY public.subtasks ALTER COLUMN id SET DEFAULT nextval('public.subtasks_id_seq'::regclass);
 :   ALTER TABLE public.subtasks ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    220    219    220            �           2604    16950    tasks id    DEFAULT     d   ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);
 7   ALTER TABLE public.tasks ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    224    225    225            �           2604    17006    tasks id    DEFAULT     n   ALTER TABLE ONLY test_schema.tasks ALTER COLUMN id SET DEFAULT nextval('test_schema.tasks_id_seq'::regclass);
 <   ALTER TABLE test_schema.tasks ALTER COLUMN id DROP DEFAULT;
       test_schema          postgres    false    229    228    229            �           2604    17041    test_tasks id    DEFAULT     x   ALTER TABLE ONLY test_schema.test_tasks ALTER COLUMN id SET DEFAULT nextval('test_schema.test_tasks_id_seq'::regclass);
 A   ALTER TABLE test_schema.test_tasks ALTER COLUMN id DROP DEFAULT;
       test_schema          postgres    false    231    230    231            �           2604    16646    user id    DEFAULT     t   ALTER TABLE ONLY user_schema."user" ALTER COLUMN id SET DEFAULT nextval('user_schema.user_table_id_seq'::regclass);
 =   ALTER TABLE user_schema."user" ALTER COLUMN id DROP DEFAULT;
       user_schema          postgres    false    222    223    223            {          0    16994    tasks 
   TABLE DATA           g   COPY mohanish.tasks (id, client_id, title, description, createdat, updatedat, assigned_to) FROM stdin;
    mohanish          postgres    false    227   ȡ       �          0    17051    tasks 
   TABLE DATA           e   COPY pranay.tasks (id, client_id, title, description, createdat, updatedat, assigned_to) FROM stdin;
    pranay          postgres    false    232   �       u          0    16545    client1 
   TABLE DATA           R   COPY public.client1 (taskid, clientid, title, createdat, assigned_to) FROM stdin;
    public          postgres    false    221   ��       t          0    16457    subtasks 
   TABLE DATA           z   COPY public.subtasks (id, title, description, created_time, status, parent_subtask_id, updated_time, task_id) FROM stdin;
    public          postgres    false    220   ��       y          0    16947    tasks 
   TABLE DATA           b   COPY public.tasks (id, user_id, title, description, assignedto, createdat, updatedat) FROM stdin;
    public          postgres    false    225   >�       }          0    17003    tasks 
   TABLE DATA           j   COPY test_schema.tasks (id, client_id, title, description, createdat, updatedat, assigned_to) FROM stdin;
    test_schema          postgres    false    229   ˣ                 0    17038 
   test_tasks 
   TABLE DATA           o   COPY test_schema.test_tasks (id, client_id, title, description, createdat, updatedat, assigned_to) FROM stdin;
    test_schema          postgres    false    231    �       w          0    16643    user 
   TABLE DATA           U   COPY user_schema."user" (id, user_id, client_id, created_at, updated_at) FROM stdin;
    user_schema          postgres    false    223   ��       �           0    0    tasks_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('mohanish.tasks_id_seq', 4, true);
          mohanish          postgres    false    226            �           0    0    subtasks_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.subtasks_id_seq', 41, true);
          public          postgres    false    219            �           0    0    tasks_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.tasks_id_seq', 2, true);
          public          postgres    false    224            �           0    0    tasks_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('test_schema.tasks_id_seq', 2, true);
          test_schema          postgres    false    228            �           0    0    test_tasks_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('test_schema.test_tasks_id_seq', 3, true);
          test_schema          postgres    false    230            �           0    0    user_table_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('user_schema.user_table_id_seq', 18, true);
          user_schema          postgres    false    222            �           2606    17001    tasks tasks_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY mohanish.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY mohanish.tasks DROP CONSTRAINT tasks_pkey;
       mohanish            postgres    false    227            �           2606    17057    tasks tasks_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY pranay.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY pranay.tasks DROP CONSTRAINT tasks_pkey;
       pranay            postgres    false    232            �           2606    16464    subtasks subtasks_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.subtasks
    ADD CONSTRAINT subtasks_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.subtasks DROP CONSTRAINT subtasks_pkey;
       public            postgres    false    220            �           2606    16954    tasks tasks_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.tasks DROP CONSTRAINT tasks_pkey;
       public            postgres    false    225            �           2606    17010    tasks tasks_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY test_schema.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
 ?   ALTER TABLE ONLY test_schema.tasks DROP CONSTRAINT tasks_pkey;
       test_schema            postgres    false    229            �           2606    17045    test_tasks test_tasks_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY test_schema.test_tasks
    ADD CONSTRAINT test_tasks_pkey PRIMARY KEY (id);
 I   ALTER TABLE ONLY test_schema.test_tasks DROP CONSTRAINT test_tasks_pkey;
       test_schema            postgres    false    231            �           2606    16651    user user_table_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY user_schema."user"
    ADD CONSTRAINT user_table_pkey PRIMARY KEY (id);
 E   ALTER TABLE ONLY user_schema."user" DROP CONSTRAINT user_table_pkey;
       user_schema            postgres    false    223            �           2606    17011    tasks tasks_assigned_to_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY mohanish.tasks
    ADD CONSTRAINT tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES user_schema."user"(id) NOT VALID;
 H   ALTER TABLE ONLY mohanish.tasks DROP CONSTRAINT tasks_assigned_to_fkey;
       mohanish          postgres    false    3288    227    223            �           2606    17016    tasks tasks_assigned_to_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY test_schema.tasks
    ADD CONSTRAINT tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES user_schema."user"(id) NOT VALID;
 K   ALTER TABLE ONLY test_schema.tasks DROP CONSTRAINT tasks_assigned_to_fkey;
       test_schema          postgres    false    3288    229    223            {   4   x�3����H��,��LI��W(I,�.�,��,V �D$�?24����� -DV      �   ~   x�e�1
1E��)r���ĉ����n���6i��ʢ �k��Ꚗ�ڵA���_$�9Yr��F������0��O�s�y�c���Cn��^��ϗ�7h�����[#�� ��(����+r      u      x������ � �      t   w   x�3��-HI,IMQI,�V�,�IErI-N.�,(����4202�5� "CS+S3+SS=���s~nAN*Pg�q�i��������������%�ɨ�LL�-�L�@���qqq ��:9      y   }   x��ͽ
�0@�9y�쥗������P7������trr<��!������r�u	s��zԩ��=��1��8���)�
d�)ɀ��(��)C��Z>���71$����[6-5'�����7�      }   E   x�3�,I-.�/N�H�M�J���9K22��(Q!%57*�B�f\F8�)b��j5����� Y�%Q         u   x��̭�0 `}}�z��~zkw��\��Q�@�}������G��j��Z+�\Z��==����[?����Y����H,N!i�I.�&���-���y�������0�B|̖���6�=c      w   i   x�34�,(J�K�����H��,����".CS�����	3Β������"C�89#57&oN@�f#�2202�5��52R04�26�2�Գ47�42)����� S0�     