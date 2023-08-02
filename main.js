const express = require("express");
const bodyParser = require("body-parser");
const pgp = require("pg-promise")();
const db = require("./db/db");

const app = express();

require("dotenv").config();
const port = process.env.PORT;

app.use(bodyParser.json());

function insertDataWithTimestamp(eventData) {
  eventData.created_time = new Date();
  return db.one(
    "INSERT INTO subtasks (title, description, created_time, status, parent_subtask_id) VALUES ($1, $2, $3, $4, $5) RETURNING *",
    [
      eventData.title,
      eventData.description,
      eventData.created_time,
      eventData.status,
      eventData.parent_subtask_id,
    ]
  );
}

function updateDataWithTimestamp(id, eventData) {
  eventData.updated_time = new Date();
  return db.one(
    "UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4, parent_subtask_id = $5 WHERE id = $6 RETURNING *",
    [
      eventData.title,
      eventData.description,
      eventData.updated_time,
      eventData.status,
      eventData.parent_subtask_id,
      id,
    ]
  );
}

app.get("/tasks", async (req, res) => {
  const limit = parseInt(req.query.limit, 10);
  const skip = parseInt(req.query.skip, 0);
  const order = req.query.order || "desc";
  const orderBy = req.query.orderBy || "created_time";
  const groupBy = req.query.groupBy || null;
  try {
    let query = "SELECT ";

    if (groupBy === "status") {
      query +=
        "status, COUNT(*) AS task_count FROM (SELECT status, created_time FROM subtasks";
    } else {
      query += "* FROM subtasks";
    }

    if (groupBy === "status") {
      query += ") AS task_subquery GROUP BY status, created_time";
    }

    if (!isNaN(limit)) {
      query += " LIMIT $1";
    }

    if (!isNaN(skip)) {
      query += " OFFSET $2";
    }

    if (orderBy === "created_time" || orderBy === "updated_time") {
      query += ` ORDER BY ${orderBy} ` + order.toUpperCase();
    } else {
      query += " ORDER BY created_time " + order.toUpperCase();
    }

    const result = await db.any(query, [limit, skip]);
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).send("Internal Server Error");
  }
});

app.get("/tasks/:id", async (req, res) => {
  const taskId = req.params.id;
  try {
    // Check if the task or subtask exists in the subtasks table
    const taskOrSubtask = await db.oneOrNone(
      "SELECT * FROM subtasks WHERE id = $1",
      taskId
    );
    if (!taskOrSubtask) {
      return res.status(404).json({ error: "Task or subtask not found" });
    }

    const subtasks = await db.any(
      "WITH RECURSIVE subtasks_recursive AS (" +
        "  SELECT id, title, description, created_time, status, parent_subtask_id, task_id" +
        "  FROM subtasks WHERE id = $1 AND parent_subtask_id IS NULL" +
        "  UNION ALL" +
        "  SELECT s.id, s.title, s.description, s.created_time, s.status, s.parent_subtask_id, s.task_id" +
        "  FROM subtasks_recursive sr JOIN subtasks s ON sr.id = s.parent_subtask_id" +
        ")" +
        "SELECT * FROM subtasks_recursive;",
      taskId
    );

    // If the queried ID corresponds to a parent task, the task itself will be present in subtasks array
    // So, remove it from the subtasks array to avoid duplication in the response
    const taskIndex = subtasks.findIndex((subtask) => subtask.id === taskId);
    if (taskIndex !== -1) {
      subtasks.splice(taskIndex, 1);
    }

    // The retrieved task or subtask will be the first element in the subtasks array
    const task = subtasks[0];

    // If there are subtasks linked to the task or subtask, update the 'subtasks' property
    if (subtasks.length > 1) {
      task.subtasks = subtasks.slice(1);
    } else {
      // If no subtasks found, set an empty array for 'subtasks' property
      task.subtasks = [];
    }

    res.json(task);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/tasks", async (req, res) => {
  const eventData = {
    title: req.body.title,
    description: req.body.description,
    status: req.body.status,
    parent_task_id: req.body.parent_task_id,
    parent_subtask_id: req.body.parent_subtask_id,
  };

  if (!eventData.title || !eventData.description || !eventData.status) {
    return res
      .status(400)
      .json({ error: "Title, description, and status are required fields." });
  }

  try {
    eventData.created_time = new Date();

    if (eventData.parent_task_id) {
      // Subtask creation
      const parentSubtask = await db.oneOrNone(
        "SELECT * FROM subtasks WHERE id = $1",
        eventData.parent_task_id
      );
      if (!parentSubtask) {
        return res.status(404).json({ error: "Parent subtask not found" });
      }

      // Insert the subtask into the 'subtasks' table and link it to the parent subtask
      eventData.task_id = parentSubtask.task_id;
      const insertedData = await db.one(
        "INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *",
        [
          eventData.title,
          eventData.description,
          eventData.created_time,
          eventData.status,
          eventData.task_id,
          eventData.parent_task_id,
        ]
      );
      res.json(insertedData);
    } else if (eventData.parent_subtask_id) {
      // Subtask creation with a parent subtask
      const parentSubtask = await db.oneOrNone(
        "SELECT * FROM subtasks WHERE id = $1",
        eventData.parent_subtask_id
      );
      if (!parentSubtask) {
        return res.status(404).json({ error: "Parent subtask not found" });
      }

      // Insert the subtask into the 'subtasks' table and link it to the parent subtask
      eventData.task_id = parentSubtask.task_id;
      const insertedData = await db.one(
        "INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *",
        [
          eventData.title,
          eventData.description,
          eventData.created_time,
          eventData.status,
          eventData.task_id,
          eventData.parent_subtask_id,
        ]
      );
      res.json(insertedData);
    } else {
      // Parent task creation
      // Insert the parent task data into the 'subtasks' table with parent_subtask_id as NULL
      const insertedData = await db.one(
        "INSERT INTO subtasks (title, description, created_time, status, task_id, parent_subtask_id) VALUES ($1, $2, $3, $4, $5, NULL) RETURNING *",
        [
          eventData.title,
          eventData.description,
          eventData.created_time,
          eventData.status,
          null,
        ]
      );
      res.json(insertedData);
    }
  } catch (err) {
    console.error("Error inserting data:", err);
    res.status(500).send("Internal Server Error");
  }
});

app.put("/tasks/:id", async (req, res) => {
  const id = req.params.id;
  const eventData = {
    title: req.body.title,
    description: req.body.description,
    status: req.body.status,
    parent_subtask_id: req.body.parent_subtask_id,
  };

  if (!eventData.title || !eventData.description || !eventData.status) {
    return res
      .status(400)
      .json({ error: "Title, description, and status are required fields." });
  }

  try {
    eventData.updated_time = new Date();

    const subtask = await db.oneOrNone(
      "SELECT * FROM subtasks WHERE id = $1",
      id
    );
    if (!subtask) {
      return res.status(404).json({ error: "Subtask not found" });
    }

    if (eventData.parent_subtask_id === "PROMOTE") {
      // Promote the subtask to an independent task (remove parent_subtask_id)
      const updatedData = await db.one(
        "UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4, parent_subtask_id = NULL WHERE id = $5 RETURNING *",
        [
          eventData.title,
          eventData.description,
          eventData.updated_time,
          eventData.status,
          id,
        ]
      );
      res.json(updatedData);
    } else if (eventData.parent_subtask_id) {
      // Update the subtask and link it to a new parent subtask
      const newParentSubtask = await db.oneOrNone(
        "SELECT * FROM subtasks WHERE id = $1",
        eventData.parent_subtask_id
      );
      if (!newParentSubtask) {
        return res.status(404).json({ error: "New parent subtask not found" });
      }

      const updatedData = await db.one(
        "UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4, parent_subtask_id = $5 WHERE id = $6 RETURNING *",
        [
          eventData.title,
          eventData.description,
          eventData.updated_time,
          eventData.status,
          eventData.parent_subtask_id,
          id,
        ]
      );
      res.json(updatedData);
    } else {
      // Parent task update
      // Check if the parent task exists
      const task = await db.oneOrNone(
        "SELECT * FROM subtasks WHERE id = $1 AND parent_subtask_id IS NULL",
        id
      );
      if (!task) {
        return res.status(404).json({ error: "Parent task not found" });
      }

      // Update the parent task data
      const updatedData = await db.one(
        "UPDATE subtasks SET title = $1, description = $2, updated_time = $3, status = $4 WHERE id = $5 AND parent_subtask_id IS NULL RETURNING *",
        [
          eventData.title,
          eventData.description,
          eventData.updated_time,
          eventData.status,
          id,
        ]
      );
      res.json(updatedData);
    }
  } catch (err) {
    console.error("Error updating data:", err);
    res.status(500).send("Internal Server Error");
  }
});

app.delete("/tasks/:id", async (req, res) => {
  const taskId = req.params.id;
  try {
    // Check if the parent task exists
    const task = await db.oneOrNone(
      "SELECT * FROM subtasks WHERE id = $1 AND parent_subtask_id IS NULL",
      taskId
    );
    if (!task) {
      return res.status(404).json({ error: "Parent task not found" });
    }

    // Fetch all the subtasks associated with the parent task (excluding the parent task itself)
    const subtasks = await db.any(
      "SELECT * FROM subtasks WHERE task_id = $1 AND id <> $2",
      [task.task_id, taskId]
    );

    // Begin a transaction to perform deletion
    await db.tx(async (t) => {
      // Delete all associated subtasks
      const deleteSubtasksResult = await t.result(
        "DELETE FROM subtasks WHERE task_id = $1",
        task.task_id
      );
      if (deleteSubtasksResult.rowCount === 0) {
        throw new Error("Failed to delete associated subtasks");
      }

      // Delete the parent task
      const deleteParentTaskResult = await t.result(
        "DELETE FROM subtasks WHERE id = $1 AND parent_subtask_id IS NULL",
        taskId
      );
      if (deleteParentTaskResult.rowCount === 0) {
        throw new Error("Failed to delete parent task");
      }
    });

    res.json({
      message: "Parent task and associated subtasks deleted successfully",
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

module.exports = app;