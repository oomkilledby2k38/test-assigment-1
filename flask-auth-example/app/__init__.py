# Flask modules
from flask import Flask
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def create_app(debug: bool = False) -> Flask:
    # Initialize app
    app = Flask(
        __name__,
        template_folder="../templates",
        static_folder="../static",
        static_url_path="/",
    )

    # Setup app configs
    app.config["DEBUG"] = debug
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "YOUR-SECRET-KEY-HERE")
    
    # Build database URI from environment variables
    db_user = os.getenv("DB_USER", "devops")
    db_password = os.getenv("DB_PASSWORD", "devops")
    db_host = os.getenv("DB_HOST", "192.168.1.101")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "flask")
    
    app.config["SQLALCHEMY_DATABASE_URI"] = (
        f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
    )

    # Initialize extensions
    from app.extensions import bcrypt, csrf, db, login_manager

    db.init_app(app)
    csrf.init_app(app)
    bcrypt.init_app(app)
    login_manager.init_app(app)

    # Create database tables
    from app import models

    with app.app_context():
        db.create_all()

    # Register blueprints
    from app.routes import routes_bp

    app.register_blueprint(routes_bp)

    return app
