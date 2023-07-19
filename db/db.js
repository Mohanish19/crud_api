const pgp = require('pg-promise')();

const cn = "postrgresql://postgres:postgres123@localhost:5432/first_db"

const db  = pgp(cn);

module.exports = db;
