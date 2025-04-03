module.exports = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'node_user',
  password: process.env.DB_PASSWORD || 'secure_password',
  database: process.env.DB_NAME || 'node_app'
};
