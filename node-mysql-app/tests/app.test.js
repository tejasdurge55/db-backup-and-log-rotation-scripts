const request = require('supertest');
const app = require('../app');
const mysql = require('mysql2/promise');

describe('Node.js MySQL App', () => {
  beforeAll(async () => {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'node_user',
      password: 'secure_password',
      database: 'node_app'
    });
    await connection.end();
  });

  it('should respond with welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.statusCode).toBe(200);
    expect(response.body.message).toContain('Welcome to Node.js MySQL App');
  });

  it('should have working database connection', async () => {
    const response = await request(app).get('/');
    expect(response.body.database).toBe('Connected');
  });

  it('should return healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('healthy');
  });
});
