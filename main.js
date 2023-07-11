const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');

const app = express();

require('dotenv').config();
const port = process.env.PORT;

app.use(bodyParser.json());

const tasksFile = './tasks.json';


function readTasksFromFile() {
  try {
    const tasksData = fs.readFileSync(tasksFile, 'utf8');
    return JSON.parse(tasksData);
  } catch (error) {
    console.error('Error reading tasks file:', error);
    return [];
  }
}


function writeTasksToFile(tasks) {
  try {
    fs.writeFileSync(tasksFile, JSON.stringify(tasks, null, 2));
  } catch (error) {
    console.error('Error writing tasks to file:', error);
  }
}

let tasks = readTasksFromFile();

app.post('/tasks', (req, res) => {
  const { title, description } = req.body;
  const task = {
    id: tasks.length + 1,
    title,
    description,
  };
  tasks.push(task);
  writeTasksToFile(tasks);
  res.status(201).json(task);
});


app.get('/tasks/:taskId', (req, res) => {
  const taskId = parseInt(req.params.taskId);
  const task = tasks.find((task) => task.id === taskId);
  if (task) {
    res.json(task);
  } else {
    res.status(404).json({ error: 'Task not found' });
  }
});


app.get('/tasks', (req, res) => {
  res.json(tasks);
});


app.put('/tasks/:taskId', (req, res) => {
  const taskId = parseInt(req.params.taskId);
  const task = tasks.find((task) => task.id === taskId);
  if (task) {
    task.title = req.body.title;
    task.description = req.body.description;
    writeTasksToFile(tasks);
    res.json(task);
  } else {
    res.status(404).json({ error: 'Task not found' });
  }
});


app.delete('/tasks/:taskId', (req, res) => {
  const taskId = parseInt(req.params.taskId);
  const taskIndex = tasks.findIndex((task) => task.id === taskId);
  if (taskIndex !== -1) {
    tasks.splice(taskIndex, 1);
    writeTasksToFile(tasks);
    res.json({ message: 'Task deleted' });
  } else {
    res.status(404).json({ error: 'Task not found' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
