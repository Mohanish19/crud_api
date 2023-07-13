const request = require('supertest');
const fs = require('fs');
const app = require('./main.js');

describe('Tasks', () => {
  const dataFilePath = './tasks.json';

  beforeEach(() => {
    fs.writeFileSync(dataFilePath, '[]', 'utf8');
  });

  afterAll(() => {
    fs.unlinkSync(dataFilePath);
  });

  test('GET /tasks should return all tasks', async () => {
    fs.writeFileSync(dataFilePath, JSON.stringify(tasks), 'utf8');


    const response = await request(app).get('/tasks');

    
    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual(tasks);
  });

  test('GET', async () => {
  
    fs.writeFileSync(dataFilePath, JSON.stringify([task]), 'utf8');

    const response = await request(app).get(`/tasks/${taskId}`);


    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual(task);
  });

  test('POST', async () => {

    
    const response = await request(app)
      .post('/tasks')
      .send(newTask);

    expect(response.statusCode).toBe(201);
    expect(response.body.title).toBe(newTask.title);
    expect(response.body.description).toBe(newTask.description);

    const tasksData = fs.readFileSync(dataFilePath, 'utf8');
    const tasks = JSON.parse(tasksData);
    expect(tasks.length).toBe(1);
    expect(tasks[0].title).toBe(newTask.title);
    expect(tasks[0].description).toBe(newTask.description);
  });

  test('PUT', async () => {
    
    fs.writeFileSync(dataFilePath, JSON.stringify([originalTask]), 'utf8');

    const response = await request(app)
      .put(`/tasks/${taskId}`)
      .send(updatedTask);

    expect(response.statusCode).toBe(200);
    expect(response.body.title).toBe(updatedTask.title);
    expect(response.body.description).toBe(updatedTask.description);

    const tasksData = fs.readFileSync(dataFilePath, 'utf8');
    const tasks = JSON.parse(tasksData);
    expect(tasks.length).toBe(1);
    expect(tasks[0].title).toBe(updatedTask.title);
    expect(tasks[0].description).toBe(updatedTask.description);
  });

  test('DELETE', async () => {
   
    fs.writeFileSync(dataFilePath, JSON.stringify(tasks), 'utf8');

    const response = await request(app).delete(`/tasks/${taskId}`);

    expect(response.statusCode).toBe(200);
    expect(response.body.message).toBe('Task deleted');
    expect(response.body.task).toEqual(tasks[0]);

    const tasksData = fs.readFileSync(dataFilePath, 'utf8');
    const remainingTasks = JSON.parse(tasksData);
    expect(remainingTasks.length).toBe(1);
    expect(remainingTasks[0].id).toBe(2);
  });
});
