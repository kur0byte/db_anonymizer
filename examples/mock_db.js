const { Pool } = require('pg');
const { faker } = require('@faker-js/faker');

// Database configuration
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'postgres',
  password: 'postgres',
  port: 5432,
});

async function createUserTable() {
  const client = await pool.connect();
  try {
    // Drop table if exists
    await client.query('DROP TABLE IF EXISTS users');

    // Create users table
    await client.query(`
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        email VARCHAR(100) UNIQUE,
        password_hash VARCHAR(100),
        date_of_birth DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(20),
        last_login TIMESTAMP
      )
    `);

    // Generate and insert mock data
    for (let i = 0; i < 1000; i++) {
      const user = {
        firstName: faker.person.firstName(),
        lastName: faker.person.lastName(),
        email: faker.internet.email(),
        passwordHash: faker.internet.password(),
        dateOfBirth: faker.date.birthdate(),
        status: faker.helpers.arrayElement(['active', 'inactive', 'suspended']),
        lastLogin: faker.date.past()
      };

      await client.query(`
        INSERT INTO users (
          first_name, last_name, email, password_hash, 
          date_of_birth, status, last_login
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, [
        user.firstName,
        user.lastName,
        user.email,
        user.passwordHash,
        user.dateOfBirth,
        user.status,
        user.lastLogin
      ]);
    }

    console.log('Successfully created users table and inserted 1000 records');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

createUserTable();