require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const winston = require('winston');
const { combine, timestamp, printf } = winston.format;

const logFormat = printf(({ level, message, timestamp }) => {
  return `${timestamp} [${level}]: ${message}`;
});

const logger = winston.createLogger({
  level: 'info',
  format: combine(
    timestamp(),
    logFormat
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/application.log' })
  ],
});

const app = express();
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'node_user',
  password: process.env.DB_PASSWORD || 'secure_password',
  database: process.env.DB_NAME || 'node_app',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

app.get('/', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT 1 + 1 AS solution');
    logger.info('Database query successful');
    res.json({ 
      message: 'Welcome to Node.js MySQL App',
      database: rows[0].solution === 2 ? 'Connected' : 'Error'
    });
  } catch (err) {
    logger.error('Database connection error: ' + err.message);
    res.status(500).json({ error: 'Database connection failed' });
  }
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});


module.exports = app; // Add this line
