from app import create_app
from app.extensions import bcrypt, db
from app.models import User

app = create_app()

with app.app_context():
    test_users = [
        {"name": "Test User", "email": "test@example.com", "password": "password123"},
        {"name": "Admin", "email": "admin@example.com", "password": "admin123"},
        {"name": "Kirill", "email": "kirill@example.com", "password": "kirill123"},
    ]

    for user_data in test_users:
        existing_user = User.query.filter_by(email=user_data["email"]).first()
        if existing_user:
            print(f"Пользователь {user_data['email']} уже существует")
            continue

        hashed_password = bcrypt.generate_password_hash(user_data["password"]).decode(
            "utf-8"
        )

        new_user = User(
            name=user_data["name"], email=user_data["email"], password=hashed_password
        )

        db.session.add(new_user)
        print(f"Добавлен пользователь: {user_data['name']} ({user_data['email']})")

    db.session.commit()
    print("\nВсе пользователи добавлены в базу данных.")

    all_users = User.query.all()
    print(f"\nВсего пользователей в БД: {len(all_users)}")
    for user in all_users:
        print(f"  - {user.name} ({user.email})")
