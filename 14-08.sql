-- Create task
CREATE OR REPLACE FUNCTION create_task(
    client_id bigint,
    task_data jsonb
) RETURNS jsonb AS $$
DECLARE
    new_task_id bigint;
BEGIN
    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;

    INSERT INTO tasks(client_id, data)
    VALUES (client_id, task_data)
    RETURNING id INTO new_task_id;

    RETURN jsonb_build_object('status', 'success', 'task_id', new_task_id);
EXCEPTION
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;


-- Read task
CREATE OR REPLACE FUNCTION read_task(
    client_id bigint,
    task_id bigint
) RETURNS jsonb AS $$
BEGIN

    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;

    
    RETURN (SELECT data FROM tasks WHERE client_id = client_id AND id = task_id);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Task not found');
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;


-- Update task
CREATE OR REPLACE FUNCTION update_task(
    client_id bigint,
    task_id bigint,
    task_data jsonb
) RETURNS jsonb AS $$
BEGIN
    
    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;

    UPDATE tasks
    SET data = task_data
    WHERE client_id = client_id AND id = task_id;

    RETURN jsonb_build_object('status', 'success');
EXCEPTION
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;


-- Delete task
CREATE OR REPLACE FUNCTION delete_task(
    client_id bigint,
    task_id bigint
) RETURNS jsonb AS $$
BEGIN
    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;

    DELETE FROM tasks WHERE client_id = client_id AND id = task_id;

    RETURN jsonb_build_object('status', 'success');
EXCEPTION
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;


-- Create user
CREATE OR REPLACE FUNCTION create_user(
    client_id bigint,
    username text,
    email text
) RETURNS jsonb AS $$
DECLARE
    new_user_id bigint;
BEGIN
   
    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;

    
    INSERT INTO users(client_id, username, email)
    VALUES (client_id, username, email)
    RETURNING id INTO new_user_id;

    RETURN jsonb_build_object('status', 'success', 'user_id', new_user_id);
EXCEPTION
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;


-- Update user
CREATE OR REPLACE FUNCTION update_user(
    client_id bigint,
    user_id bigint,
    username text,
    email text
) RETURNS jsonb AS $$
BEGIN
    
    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;

    
    UPDATE users
    SET username = username, email = email
    WHERE client_id = client_id AND id = user_id;

    RETURN jsonb_build_object('status', 'success');
EXCEPTION
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;


-- Delete user
CREATE OR REPLACE FUNCTION delete_user(
    client_id bigint,
    user_id bigint
) RETURNS jsonb AS $$
BEGIN
    
    IF client_id = 1 THEN
        SET search_path TO client1, task, user;
    ELSEIF client_id = 2 THEN
        SET search_path TO client2, task, user;
    ELSE
        RAISE EXCEPTION 'Unknown client ID: %', client_id;
    END IF;
    
    DELETE FROM users WHERE client_id = client_id AND id = user_id;

    RETURN jsonb_build_object('status', 'success');
EXCEPTION
    WHEN others THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql;
