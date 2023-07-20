const express = require('express');
const bodyParser = require('body-parser');
const pgp = require('pg-promise')();
// const fs = require('fs');

const db = require('./db/db');

const app = express();

require('dotenv').config();
const port = process.env.PORT;

app.use(bodyParser.json());

app.get('/tasks', async (req,res) => {
  const limit = parseInt(req.query.limit, 10);
  const skip = parseInt(req.query.skip, 0);

  try {
    let query = 'SELECT * FROM tasks';

    if (!isNaN(limit)) {
      query += ' LIMIT $1';
    }

    if (!isNaN(skip)) {
      query += ' OFFSET $2';
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

app.post('/tasks', async (req,res) => {
  // const { id } = req.params;
  const { id , title , description } = req.body;
  try {
    const task = await db.one(
      'INSERT INTO tasks (id , title , description) VALUES ($1, $2, $3) RETURNING *',
      [id, title , description]
    );
      res.status(201).json(task);
  } catch ( err ) {
      console.error(err);
      res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.put('/tasks/:id' , async (req,res) => {
  const { id } = req.params;
  const{ title , description } = req.body;
  try {
    const task = await db.oneOrNone(
      'UPDATE tasks SET title = $1, description = $2 WHERE id = $3 RETURNING *',
      [title, description, id]
    );
    if(!task) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(task);
  }catch (err) {
    console.error (err);
    res.status(500).json({ error : 'Internal Server Error' });
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