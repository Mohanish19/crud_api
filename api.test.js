const request = require('supertest');
const fs = require('fs');
const app = require('./main'); 

const dataFilePath = './tasks.json';

beforeEach(() => {
  if (fs.existsSync(dataFilePath)) {
    fs.unlinkSync(dataFilePath);
  }
  fs.writeFileSync(dataFilePath, '[]');
});

test('GET', async () => {
  const response = await request(app).get('/tasks');
  expect(response.status).toBe(200);
  expect(response.body).toEqual([]);
});

test('GET with the given ID', async () => {
  const newItem = { id: 1, name: 'Item 1' };
  fs.writeFileSync(dataFilePath, JSON.stringify([newItem]));

  const response = await request(app).get('/tasks/1');
  expect(response.status).toBe(200);
  expect(response.body).toEqual(newItem);
});

test('PUT', async () => {
  const newTasks = { id: 1, name: 'Item 1' };
  fs.writeFileSync(dataFilePath, JSON.stringify([newTasks]));

  const updatedTasks = { name: 'Updated Tasks' };

  const response = await request(app)
    .put('/tasks/id')
    .send(updatedTasks);
  expect(response.status).toBe(200);
  const storedItems = JSON.parse(fs.readFileSync(dataFilePath));
  expect(storedItems).toHaveLength(1);
  expect(storedItems[0]).toEqual(expect.objectContaining(updatedTasks));
});


test('POST', async () => {
  const newItem = { name: 'New Item' };
  
  const response = await request(app).post('/api/items').send(newItem);
  expect(response.status).toBe(201);
  
  const storedItems = JSON.parse(fs.readFileSync(dataFilePath));
  expect(storedItems).toHaveLength(1);
  expect(storedItems[0]).toEqual(expect.objectContaining(newItem));
});


test('DELETE', async () => {
  const newItem = { id: 1, name: 'Item 1' };
  fs.writeFileSync(dataFilePath, JSON.stringify([newItem]));
  
  const response = await request(app).delete('/tasks/1');
  expect(response.status).toBe(200);
  
  const storedItems = JSON.parse(fs.readFileSync(dataFilePath));
  expect(storedItems).toHaveLength(0);
});