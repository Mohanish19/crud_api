const express = require('express');
const bodyParser = require('body-parser');
const pgp = require('pg-promise')();


const db = require('./db/db');

const app = express();

require('dotenv').config();
const port = process.env.PORT;

app.use(bodyParser.json());

function insertDataWithTimestamp(eventData) {
  eventData.created_time = new Date(); 
  return db.one(
    'INSERT INTO tasks (id, title, description, created_time, status) VALUES ($1, $2, $3, $4, $5) RETURNING *',
    [eventData.id, eventData.title, eventData.description, eventData.created_time, eventData.status]
  );
}


function updateDataWithTimestamp(id, eventData) {
  eventData.updated_time = new Date(); 
  return db.one(
    'UPDATE tasks SET title = $1, description = $2, updated_time = $3, status = $4 WHERE id = $5 RETURNING *',
    [eventData.title, eventData.description, eventData.updated_time, eventData.status, id]
  );
}

app.get('/tasks', async (req, res) => {
  const limit = parseInt(req.query.limit, 10);
  const skip = parseInt(req.query.skip, 0);
  const order = req.query.order || 'desc';
  const orderBy = req.query.orderBy || 'created_time';
  const groupBy = req.query.groupBy || null; 
  try {
    let query = 'SELECT ';

    if (groupBy === 'status') {
      query += 'status, COUNT(*) AS task_count FROM (SELECT status, created_time FROM tasks';
    } else {
      query += '* FROM tasks';
    }

    if (groupBy === 'status') {
      query += ') AS task_subquery GROUP BY status, created_time';
    }

    if (!isNaN(limit)) {
      query += ' LIMIT $1';
    }

    if (!isNaN(skip)) {
      query += ' OFFSET $2';
    }

    if (orderBy === 'created_time' || orderBy === 'updated_time') {
      query += ` ORDER BY ${orderBy} ` +  order.toUpperCase();
    } else {
      query += ' ORDER BY created_time ' + order.toUpperCase(); 
    }

    const result = await db.any(query, [limit, skip]);
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).send('Internal Server Error');
  }
});



app.get('/tasks/:id', async (req, res) => {
  const taskId = req.params.id;
  try {
    const task = await db.oneOrNone('SELECT * FROM tasks WHERE id = $1', taskId);
    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const subtasks = await db.any(
      'WITH RECURSIVE subtasks_recursive AS (' +
      '  SELECT id, title, description, created_time, status, parent_subtask_id, task_id' +
      '  FROM subtasks WHERE task_id = $1 AND parent_subtask_id IS NULL' +
      '  UNION ALL' +
      '  SELECT s.id, s.title, s.description, s.created_time, s.status, s.parent_subtask_id, s.task_id' +
      '  FROM subtasks_recursive sr JOIN subtasks s ON sr.id = s.parent_subtask_id' +
      ')' +
      'SELECT * FROM subtasks_recursive;',
      taskId
    );

    // Link subtasks to the task object using forEach
    task.subtasks = [];
    subtasks.forEach((subtask) => {
      if (subtask.task_id === taskId) {
        // Exclude the parent task itself from the subtasks list
        return;
      }
      task.subtasks.push(subtask);
    });

    res.json(task);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/tasks', async (req, res) => {
  const eventData = {
    title: req.body.title,
    description: req.body.description,
    status: req.body.status,
    parent_task_id: req.body.parent_task_id,
  };

  if (!eventData.title || !eventData.description || !eventData.status) {
    return res.status(400).json({ error: 'Title, description, and status are required fields.' });
  }

  try {
    eventData.created_time = new Date();

    if (eventData.parent_task_id) {
      // Subtask creation
      const parentTask = await db.oneOrNone('SELECT * FROM tasks WHERE id = $1', eventData.parent_task_id);
      if (!parentTask) {
        return res.status(404).json({ error: 'Parent task not found' });
      }

      // Insert the subtask into the 'subtasks' table and link it to the parent task
      eventData.task_id = eventData.parent_task_id;
      const insertedData = await db.one(
        'INSERT INTO subtasks (title, description, created_time, status, task_id) VALUES ($1, $2, $3, $4, $5) RETURNING *',
        [eventData.title, eventData.description, eventData.created_time, eventData.status, eventData.task_id]
      );
      res.json(insertedData);
    } else {
      // Parent task creation
      // Insert the parent task data into the 'tasks' table
      const insertedData = await db.one(
        'INSERT INTO tasks (title, description, created_time, status) VALUES ($1, $2, $3, $4) RETURNING *',
        [eventData.title, eventData.description, eventData.created_time, eventData.status]
      );
      res.json(insertedData);
    }
  } catch (err) {
    console.error('Error inserting data:', err);
    res.status(500).send('Internal Server Error');
  }
});



app.put('/tasks/:id', async (req, res) => {
  const id = req.params.id;
  const eventData = {
    title: req.body.title,
    description: req.body.description,
    status: req.body.status,
    parent_subtask_id: req.body.parent_subtask_id,
  };

  if (!eventData.title || !eventData.description || !eventData.status) {
    return res.status(400).json({ error: 'Title, description, and status are required fields.' });
  }

  try {
    eventData.updated_time = new Date();

    if (eventData.parent_subtask_id) {
      // Subtask update or promotion to independent task
      // Check if the subtask exists
      const subtask = await db.oneOrNone('SELECT * FROM subtasks WHERE id = $1', id);
      if (!subtask) {
        return res.status(404).json({ error: 'Subtask not found' });
      }

      if (eventData.parent_subtask_id === 'PROMOTE') {
        // Promote the subtask to an independent task (remove parent_subtask_id)
        const updatedData = await db.one(
          'UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4, parent_subtask_id = NULL WHERE id = $5 RETURNING *',
          [eventData.title, eventData.description, eventData.updated_time, eventData.status, id]
        );
        res.json(updatedData);
      } else {
        // Update the subtask and link it to a new parent subtask
        // Check if the new parent subtask exists
        const newParentSubtask = await db.oneOrNone('SELECT * FROM subtasks WHERE id = $1', eventData.parent_subtask_id);
        if (!newParentSubtask) {
          return res.status(404).json({ error: 'New parent subtask not found' });
        }

        const updatedData = await db.one(
          'UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4, parent_subtask_id = $5 WHERE id = $6 RETURNING *',
          [eventData.title, eventData.description, eventData.updated_time, eventData.status, eventData.parent_subtask_id, id]
        );
        res.json(updatedData);
      }
    } else {
      // Parent task update
      // Check if the parent task exists
      const task = await db.oneOrNone('SELECT * FROM tasks WHERE id = $1', id);
      if (!task) {
        return res.status(404).json({ error: 'Parent task not found' });
      }

      // Update the parent task data
      const updatedData = await db.one(
        'UPDATE tasks SET title = $1, description = $2, updated_time = $3, status = $4 WHERE id = $5 RETURNING *',
        [eventData.title, eventData.description, eventData.updated_time, eventData.status, id]
      );
      res.json(updatedData);
    }
  } catch (err) {
    console.error('Error updating data:', err);
    res.status(500).send('Internal Server Error');
  }
});



app.delete('/tasks/:id', async (req, res) => {
  const taskId = req.params.id;
  try {
    // Check if the parent task exists
    const task = await db.oneOrNone('SELECT * FROM tasks WHERE id = $1', taskId);
    if (!task) {
      return res.status(404).json({ error: 'Parent task not found' });
    }

    // Delete the parent task along with all its associated subtasks
    const deleteResult = await db.result('DELETE FROM tasks WHERE id = $1', taskId);

    // Check if any rows were affected (i.e., parent task and its subtasks were deleted)
    if (deleteResult.rowCount > 0) {
      res.json({ message: 'Parent task and associated subtasks deleted successfully' });
    } else {
      res.status(500).json({ error: 'Failed to delete parent task and its subtasks' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});


app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

module.exports = app;