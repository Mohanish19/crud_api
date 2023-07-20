const chai = require('chai');
const expect = chai.expect;
const app = require('./main'); 
const supertest = require('supertest');

describe('App', () => {
  let taskId;

  it('creates a new task', async () => {
    const newTask = {
      id: 1,
      title: 'Test Task',
      description: 'This is a test task.',
    };

    const response = await supertest(app)
      .post('/tasks')
      .send(newTask)
      .expect(200);

    const insertedTask = response.body;
    taskId = insertedTask.id;

    expect(insertedTask.title).to.equal(newTask.title);
    expect(insertedTask.description).to.equal(newTask.description);
  });

  it('updates an existing task', async () => {
    const updatedTask = {
      title: 'Updated Task',
      description: 'This is an updated task description.',
    };

    const response = await supertest(app)
      .put(`/tasks/${taskId}`)
      .send(updatedTask)
      .expect(200);

    const updatedTaskData = response.body;

    expect(updatedTaskData.title).to.equal(updatedTask.title);
    expect(updatedTaskData.description).to.equal(updatedTask.description);
  });


  it('gets a single task by ID', async () => {
    const response = await supertest(app)
      .get(`/tasks/${taskId}`)
      .expect(200);

    const task = response.body;

    expect(task.id).to.equal(taskId);
  });

  it('gets all tasks', async () => {
    const response = await supertest(app)
      .get('/tasks')
      .expect(200);

    const tasks = response.body;

    expect(tasks).to.be.an('array');
    expect(tasks.length).to.be.greaterThan(0);
  });

  it('deletes a task', async () => {
    await supertest(app)
      .delete(`/tasks/${taskId}`)
      .expect(200);

    const deletedTaskResponse = await supertest(app)
      .get(`/tasks/${taskId}`)
      .expect(404);

    expect(deletedTaskResponse.body.error).to.equal('task not found');
  });
});
