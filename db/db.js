const pgp = require('pg-promise')();

// const cn = "postrgresql://postgres:postgres123@localhost:5432/first_db"
require('dotenv').config();
const cn = process.env.DB_CONNECTION_STRING;
// const cn = process.env.CONNECT;

const db  = pgp(cn);

module.exports = db;
