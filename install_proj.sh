# Create project directory
mkdir -p node-mysql-app/{.github/workflows,config,scripts,tests}

# Create all the files
cat > node-mysql-app/app.js << 'EOF'
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
EOF

cat > node-mysql-app/config/db.js << 'EOF'
module.exports = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'node_user',
  password: process.env.DB_PASSWORD || 'secure_password',
  database: process.env.DB_NAME || 'node_app'
};
EOF

cat > node-mysql-app/config/logrotate.conf << 'EOF'
/var/log/node-mysql-app/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 ubuntu ubuntu
    sharedscripts
    postrotate
        systemctl restart node-mysql-app > /dev/null
    endscript
}
EOF

cat > node-mysql-app/scripts/monitor-website.sh << 'EOF'
#!/bin/bash

URL="http://localhost:3000/health"
EMAIL="your-email@example.com"
LOG_FILE="/var/log/node-mysql-app/monitor.log"

status_code=$(curl --write-out %{http_code} --silent --output /dev/null $URL)

if [[ "$status_code" -ne 200 ]] ; then
  echo "$(date) - Website is down. Status code: $status_code" >> $LOG_FILE
  echo "Subject: Website Alert - Site is down" | sendmail $EMAIL
else
  echo "$(date) - Website is up. Status code: $status_code" >> $LOG_FILE
fi
EOF

cat > node-mysql-app/scripts/backup-db.sh << 'EOF'
#!/bin/bash

DB_USER="node_user"
DB_PASSWORD="secure_password"
DB_NAME="node_app"
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
AWS_BUCKET="your-s3-bucket-name"

mkdir -p $BACKUP_DIR

mysqldump -u$DB_USER -p$DB_PASSWORD $DB_NAME | gzip > $BACKUP_DIR/$DB_NAME-$DATE.sql.gz

aws s3 cp $BACKUP_DIR/$DB_NAME-$DATE.sql.gz s3://$AWS_BUCKET/db-backups/

find $BACKUP_DIR -name "*.sql.gz" -type f -mtime +7 -delete
EOF

cat > node-mysql-app/tests/app.test.js << 'EOF'
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
EOF

cat > node-mysql-app/.github/workflows/ci-cd.yml << 'EOF'
name: Node.js CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Use Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '18'
    - run: npm install
    - run: npm test
      env:
        DB_HOST: localhost
        DB_USER: node_user
        DB_PASSWORD: secure_password
        DB_NAME: node_app

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v2
    - name: Install SSH key
      uses: shimataro/ssh-key-action@v2
      with:
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        known_hosts: ${{ secrets.KNOWN_HOSTS }}
    - name: Deploy to EC2
      run: |
        ssh -o StrictHostKeyChecking=no ubuntu@${{ secrets.EC2_IP }} \
          "cd node-mysql-app && git pull && npm install && pm2 restart app"
EOF

cat > node-mysql-app/Jenkinsfile << 'EOF'
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("node-mysql-app:${env.BUILD_ID}")
                }
            }
        }
        stage('Test') {
            steps {
                script {
                    docker.image("node-mysql-app:${env.BUILD_ID}").inside {
                        sh 'npm test'
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    sh "docker stop node-mysql-app || true"
                    sh "docker rm node-mysql-app || true"
                    sh "docker run -d --name node-mysql-app -p 3000:3000 node-mysql-app:${env.BUILD_ID}"
                }
            }
        }
    }
}
EOF

cat > node-mysql-app/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["node", "app.js"]
EOF

cat > node-mysql-app/package.json << 'EOF'
{
  "name": "node-mysql-app",
  "version": "1.0.0",
  "description": "Node.js MySQL application with CI/CD, monitoring, and backups",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "test": "jest"
  },
  "dependencies": {
    "aws-sdk": "^2.1239.0",
    "cron": "^2.1.0",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
    "mysql2": "^3.2.0",
    "nodemailer": "^6.9.1",
    "winston": "^3.8.2",
    "winston-daily-rotate-file": "^4.7.1"
  },
  "devDependencies": {
    "jest": "^29.3.1",
    "supertest": "^6.3.3"
  }
}
EOF

# Make scripts executable
chmod +x node-mysql-app/scripts/*.sh

# Initialize npm project
cd node-mysql-app
npm init -y
npm install