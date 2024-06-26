from flask import Flask
from util import LettersOnlyConverter
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
import os

app = Flask(__name__)
app.url_map.converters['lettersOnly'] = LettersOnlyConverter
app.config["SQLALCHEMY_DATABASE_URI"] = f"postgresql://{os.environ.get('PGUSER')}:{os.environ.get('PGPASSWORD')}@{os.environ.get('PGHOST')}/{os.environ.get('PGDATABASE')}"

db = SQLAlchemy(app)
migrate = Migrate(app, db)
