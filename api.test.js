const request = require('supertest');
const fs = require('fs');
const app = require('./main'); 

const dataFilePath = './tasks.json';
const testFilePath = './tasks-test.json'

beforeEach(() => {
  if (fs.existsSync(dataFilePath)) {
    fs.unlinkSync(dataFilePath);
  }
  fs.writeFileSync(dataFilePath, '[]');
});

// Working 
test('GET', async () => {
  const response = await request(app).get('/tasks');
  expect(response.status).toBe(200);
  expect(response.body).toEqual([]);
});

test('GET', async () => {
  const newItem = { id: 1, name: 'Item 1', description : 'Item 1' };
  fs.writeFileSync(testFilePath, JSON.stringify([newItem]));

  const response = await request(app).get('/tasks/1');
  expect(response.status).toBe(200);
  expect(response.body).toEqual(newItem);
});

test('POST', async () => {
  const newItem = { name: 'New Item' };
  
  const response = await request(app).post('/tasks').send(newItem);
  expect(response.status).toBe(201);
  
  const storedItems = JSON.parse(fs.readFileSync(testFilePath));
  expect(storedItems).toHaveLength(1);
});


test('PUT /tasks/:taskId should update a specific task', async () => {
  
  const taskId = 1;
  const originalTask = { id: taskId, title: 'Task 1', description: 'Description 1' };
  fs.writeFileSync(testFilePath, JSON.stringify([originalTask]), 'utf8');

  const updatedTask = { title: 'Updated Task', description: 'Updated Description' };

  const response = await request(app)
    .put(`/tasks/${taskId}`)
    .send(updatedTask);

  expect(response.status).toBe(200);
  expect(response.body.title).toBe(updatedTask.title);
  expect(response.body.description).toBe(updatedTask.description);

  
  const tasksData = fs.readFileSync(dataFilePath, 'utf8');
  const tasks = JSON.parse(tasksData);
  expect(tasks.length).toBe(1);
  expect(tasks[0].title).toBe(updatedTask.title);
  expect(tasks[0].description).toBe(updatedTask.description);
});

test('DELETE', async () => {
  const newItem = { id: 1, name: 'Item 1', description: 'Item' };
  fs.writeFileSync(testFilePath, JSON.stringify([newItem]));
  
  const response = await request(app).delete('/tasks/1');
  expect(response.status).toBe(200);
  
  const storedItems = JSON.parse(fs.readFileSync(dataFilePath));
  expect(storedItems).toHaveLength(0);
});


