# Flask modules
from flask import Blueprint, flash, redirect, render_template, url_for
from flask_login import current_user, login_required, login_user, logout_user

from app.extensions import bcrypt, db, login_manager
from app.forms import LoginForm, RegistrationForm

# Local modules
from app.models import User

routes_bp = Blueprint("routes", __name__, url_prefix="/")


@login_manager.user_loader
def load_user(user_id):
    return User.query.filter_by(id=user_id).one_or_none()


@routes_bp.route("/")
@login_required
def home():
    return render_template("index.html")


import logging

@routes_bp.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("routes.home"))

    form = LoginForm()

    if form.validate_on_submit():
        email = form.email.data
        password = form.password.data
        remember_me = form.remember_me.data

        user = User.query.filter_by(email=email).one_or_none()
        if user:
            try:
                # Support both bytes and string password hashes
                password_hash = user.password
                if isinstance(password_hash, bytes):
                    password_hash = password_hash.decode('utf-8')
                
                if bcrypt.check_password_hash(password_hash, password):
                    login_user(user, remember=remember_me)
                    flash(f"Logged in successfully as {user.name}", "success")
                    return redirect(url_for("routes.home"))
            except (ValueError, AttributeError) as e:
                logging.exception("Invalid password hash for user %s", user.id)
                flash("Internal password format error (contact admin).", "danger")
                return render_template("auth/login.html", form=form)

        flash("Invalid email or password", "danger")

    return render_template("auth/login.html", form=form)


@routes_bp.route("/register", methods=["GET", "POST"])
def register():
    if current_user.is_authenticated:
        return redirect(url_for("routes.home"))

    form = RegistrationForm()

    if form.validate_on_submit():
        name = form.name.data
        email = form.email.data
        password = form.password.data

        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')

        # Add user to database
        new_user = User(name=name, email=email, password=hashed_password)
        db.session.add(new_user)
        db.session.commit()

        # Login user
        login_user(new_user)

        flash(
            f"Account created successfully! You are now logged in as {new_user.name}.",
            "success",
        )
        return redirect(url_for("routes.home"))

    return render_template("auth/register.html", form=form)


@routes_bp.route("/logout", methods=["GET", "POST"])
@login_required
def logout():
    logout_user()
    return redirect(url_for("routes.login"))
