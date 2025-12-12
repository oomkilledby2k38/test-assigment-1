# Flask Authentication Example

This repository provides an example implementation of user authentication using Flask-Login, demonstrating
how to build a simple web application with user registration, login.

## Features

- User registration and login functionality.
- Password hashing for enhanced security.
- Flash messages for user feedback.

## Preview

- Logged in:

![Logged in page](https://github.com/riad-azz/readme-storage/blob/main/flask-auth-example/logged.png?raw=true)

- Registration page:

![Registration page](https://github.com/riad-azz/readme-storage/blob/main/flask-auth-example/register.png?raw=true)

- Login page:

![Login page](https://github.com/riad-azz/readme-storage/blob/main/flask-auth-example/login.png?raw=true)

## Getting Started

1.Clone the repository to your local machine:

```bash
git clone https://github.com/riad-azz/flask-auth-example && cd flask-auth-example
```

2.Install the required dependencies:

```bash
pip install -r requirements.txt
```

3.The application can be run with the following command:

```bash
python main.py
```

Open your web browser and navigate to http://localhost:5000 to access the application.

3.Configure environment variables:

Copy `.env.example` to `.env` and update the database credentials:

```bash
cp .env.example .env
```

Edit `.env` file with your database credentials:

```
SECRET_KEY=your-secret-key-here
DB_USER=your-db-username
DB_PASSWORD=your-db-password
DB_HOST=192.168.1.101
DB_PORT=5432
DB_NAME=flask
```

4.The application can be run with the following command:
