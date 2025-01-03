# Database Anonymizer

A robust and secure solution for creating anonymized copies of PostgreSQL databases while maintaining data integrity and referential consistency. This tool is designed to help organizations comply with data protection regulations while providing realistic test data.

## Features

- Flexible rule-based anonymization configuration using YAML
- Support for multiple masking functions and strategies
- Preserves database structure and relationships
- Docker-based implementation for portability
- Automated cleanup and resource management
- Configurable output formats and locations
- Built-in validation and error handling

## Prerequisites

- Docker and Docker Compose
- PostgreSQL client tools (`psql`, `pg_dump`)
- Bash shell environment
- Node.js and npm (for testing/development)
- `lsof` command-line utility

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/db-anonymizer.git
cd db-anonymizer
```

2. Install Node.js dependencies (for development/testing):
```bash
npm install
```

3. Make the scripts executable:
```bash
chmod +x *.sh
chmod +x lib/*.sh
```

## Project Structure

```
.
├── anonymizer.sh          # Main script
├── lib/
│   ├── rules_processor.sh # Rules processing logic
│   ├── sql_generator.sh   # SQL generation utilities
│   └── utils.sh          # Common utility functions
├── config/
│   ├── database/         # Database connection configs
│   └── rules/           # Anonymization rules
├── dumps/               # Output directory for anonymized dumps
├── docker-compose.yml   # Development environment setup
└── examples/           # Example implementations and test data
```

## Configuration

### Database Configuration

Create a YAML file in `config/database/` with your database connection details:

```yaml
host: your-database-host
port: 5432
database: your-database-name
user: your-username
password: your-password
schemas:
  - public
rules:
  - rule-set-name
```

### Anonymization Rules

Create YAML files in `config/rules/` to define anonymization rules:

```yaml
table: users
columns:
  - email
  - first_name
  - last_name
  - password_hash
mask_functions:
  email: anon.random_email()
  first_name: anon.fake_first_name()
  last_name: anon.fake_last_name()
  password_hash: anon.hash(password_hash)
```

## Usage

1. Run the anonymizer with a specific database configuration:
```bash
./anonymizer.sh -d config/database/your-config.yml
```

2. The anonymized dump will be created in the `dumps/` directory with a timestamp:
```
dumps/20250102_123456_your-database_dump.sql
```

## Available Masking Functions

- `anon.random_email()`: Generates random email addresses
- `anon.fake_first_name()`: Generates random first names
- `anon.fake_last_name()`: Generates random last names
- `anon.hash()`: Creates consistent hashes
- `anon.random_string()`: Generates random strings
- `anon.random_date()`: Generates random dates
- `anon.random_int()`: Generates random integers
- `anon.mask_credit_card()`: Masks credit card numbers
- `anon.mask_phone()`: Masks phone numbers
- `anon.mask_address()`: Masks addresses

## Development Environment

A development environment with PostgreSQL and pgAdmin is provided:

1. Start the environment:
```bash
docker-compose up -d
```

2. Access pgAdmin:
- URL: http://localhost:8080
- Email: admin@example.com
- Password: admin

3. Generate test data using the example implementation:
```bash
cd examples
npm install
node mock_db.js
```

## Security Considerations

- All passwords and sensitive data are handled securely
- Temporary files are cleaned up automatically
- Docker containers are isolated and removed after use
- Original database connection details are never exposed
- Masked data maintains referential integrity

## Error Handling

The tool includes comprehensive error handling:
- Validates all configuration files
- Checks for required dependencies
- Verifies database connections
- Ensures proper cleanup on failure
- Provides detailed error messages

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- PostgreSQL Anonymizer project
- Faker.js for test data generation
- Contributors and maintainers

## Support

For support, please open an issue on the GitHub repository or contact the maintainers.

Made with 🖤 by kur0