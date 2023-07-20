const pgp = require('pg-promise')();

require('dotenv').config();
const cn = process.env.DB_CONNECTION_STRING;

const db  = pgp(cn);

module.exports = db;
