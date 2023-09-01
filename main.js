const express = require("express");
const bodyParser = require("body-parser");
const pgp = require("pg-promise")();
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const db = require("./db/db");
const swaggerDocument = YAML.load('./openapi.yaml');

const app = express();

require("dotenv").config();
const port = process.env.PORT;

app.use(bodyParser.json());
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

function insertDataWithTimestamp(eventData) {
  eventData.created_time = new Date();
  return db.one(
    "INSERT INTO subtasks (title, description, created_time, status, parent_subtask_id) VALUES ($1, $2, $3, $4, $5) RETURNING *",
    [eventData.title, eventData.description, eventData.created_time, eventData.status, eventData.parent_subtask_id]
  );
}

function updateDataWithTimestamp(id, eventData) {
  eventData.updated_time = new Date();
  return db.one(
    "UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4, parent_subtask_id = $5 WHERE id = $6 RETURNING *",
    [eventData.title, eventData.description, eventData.updated_time, eventData.status, eventData.parent_subtask_id, id]
  );
}

app.get('/tasks', async (req, res) => {
  const { limit, skip, order, orderBy, groupBy } = req.query;

  const queryParams = {
    limit: limit || null,
    skip: skip || null,
    order: order || 'desc',
    orderBy: orderBy || 'created_time',
    groupBy: groupBy || null,
  };
  
  try {
    const result = await db.oneOrNone('SELECT get_tasks($1)', JSON.stringify(queryParams));

    res.json(result.get_tasks);
  } catch (err) {
    console.error(err);
    res.status(500).send('Internal Server Error');
  }
});

app.get('/tasks/:task_id', async (req, res) => {
  try {
    const task_id = parseInt(req.params.task_id, 10);
    
    const result = await db.oneOrNone(
      'SELECT get_task_with_subtasks($1::jsonb) AS result',
      [{ task_id }]
    );
    
    res.json(result.result || []);
  } catch (error) {
    console.error(error);
    res.status(500).send('Internal Server Error');
  }
});


app.post('/insert_subtask', async (req, res) => {
  const eventData = {
    title: req.body.title,
    description: req.body.description,
    status: req.body.status,
    parent_task_id: req.body.parent_task_id,
    parent_subtask_id: req.body.parent_subtask_id,
  };

  try {
    const insertedData = await db.one('SELECT create_task($1) AS result', [eventData]);
    res.json(insertedData.result);
  } catch (err) {
    console.error('Error inserting data:', err);
    res.status(500).send('Internal Server Error');
  }
});


app.put('/tasks/:id', async (req, res) => {
  const taskId = parseInt(req.params.id, 10);
  const eventData = req.body;

  try {
    const updatedTask = await db.task(async t => {
      const result = await t.oneOrNone(`
        SELECT * FROM update_task(
          p_task_id := $1,
          p_event_data := $2
        );
      `, [taskId, eventData]);

      return result;
    });

    if (!updatedTask) {
      return res.status(404).json({ error: 'Task or subtask not found' });
    }

    res.json(updatedTask);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.delete('/deleteTaskWithSubtasks', async (req, res) => {
  const taskData = req.body;

  try {
    const result = await db.one(
      `SELECT * FROM delete_task_with_subtasks($1)`,
      [JSON.stringify(taskData)]
    );

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'An error occurred while processing the request.' });
  }
});


app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

module.exports = app;