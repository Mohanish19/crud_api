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
    'INSERT INTO tasks (id, title, description, created_time) VALUES ($1, $2, $3, $4) RETURNING *',
    [eventData.id, eventData.title, eventData.description, eventData.created_time]
  );
}

function updateDataWithTimestamp(id, eventData) {
  eventData.updated_time = new Date(); 
  return db.one(
    'UPDATE tasks SET title = $1, description = $2, updated_time = $3 WHERE id = $4 RETURNING *',
    [eventData.title, eventData.description, eventData.updated_time, id]
  );
}

app.get('/tasks', async (req,res) => {
  const limit = parseInt(req.query.limit, 10);
  const skip = parseInt(req.query.skip, 0);
  const order = req.query.order || 'desc';
  const orderBy = req.query.orderBy || 'created_time';

  try {
    let query = 'SELECT * FROM tasks';

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

app.get('/tasks/:id', async (req,res) => {
  const { id } = req.params;
  try {
    const task = await db.oneOrNone('SELECT * FROM tasks WHERE id = $1' , id);
    if(!task) {
      return res.status(404).json({ error : 'task not found' });
    }
    res.json(task);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error : 'Internal Server Error' });
  }
});

app.post('/tasks', async (req, res) => {
  const eventData = {
    id: req.body.id,
    title: req.body.title,
    description: req.body.description,
  };

  try {
    const insertedData = await insertDataWithTimestamp(eventData);
    res.json(insertedData);
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
  };

  try {
    const updatedData = await updateDataWithTimestamp(id, eventData);
    res.json(updatedData);
  } catch (err) {
    console.error('Error updating data:', err);
    res.status(500).send('Internal Server Error');
  }
});


app.delete('/tasks/:id' , async(req,res) => {
  const { id } = req.params;
  try {
    const task = await db.oneOrNone('DELETE FROM tasks WHERE id = $1 RETURNING *', id)
    if(!task) {
      return res.status(404).json({ error: 'task not fount' });
    }
    res.json({ message: 'User deleted succesfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

module.exports = app;