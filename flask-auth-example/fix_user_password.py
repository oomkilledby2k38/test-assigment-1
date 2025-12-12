from app import create_app
from app.extensions import bcrypt, db
from app.models import User

app = create_app()

with app.app_context():
    user = User.query.filter_by(email="babareka@gmail.com").first()

    if user:
        new_password = "1111"
        hashed_password = bcrypt.generate_password_hash(new_password).decode("utf-8")

        user.password = hashed_password
        db.session.commit()

        print(f"Пароль для пользователя {user.email} успешно обновлен!")
        print(f"   Email: {user.email}")
        print(f"   Password: {new_password}")
    else:
        print("Пользователь babareka@gmail.com не найден")
