// const pgp = require('pg-promise')();

// require('dotenv').config();
// const cn = process.env.DB_CONNECTION_STRING;

// const db  = pgp(cn);

// module.exports = db;


const pgp = require('pg-promise')();
const dotenv = require('dotenv')

dotenv.config()

const productionConnectionURI = process.env.PRODUCTION_DB_URI;
const testingConnectionURI = process.env.TESTING_DB_URI;


let db;

function initDB() {
  if (process.env.NODE_ENV === 'production') {
    db = pgp(productionConnectionURI);
  } else if (process.env.NODE_ENV === 'test') {
    db = pgp(testingConnectionURI);
  } else {
    throw new Error('Invalid NODE_ENV. Set NODE_ENV to "production" or "test".');
  }
}

function getDB() {
  if (!db) {
    initDB();
  }
  return db;
}

module.exports = getDB();
