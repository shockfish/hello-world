from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from hello_world import util
import os

app = Flask(__name__)

# Map custom url converter to the list of available converters
app.url_map.converters['lettersOnly'] = util.LettersOnlyConverter

""" Define DATABASE URI using postgres provider
Following environment variables should be exported:
- PGUSER=username
- PGPASSWORD=password
- PGHOST=127.0.0.1
- PGPORT=5432 (optional)
- PGDATABASE=db_name
"""
app.config["SQLALCHEMY_DATABASE_URI"] = f"postgresql://{os.environ.get('PGUSER')}:{os.environ.get('PGPASSWORD')}@{os.environ.get('PGHOST')}:{os.environ.get('PGPORT','5432')}/{os.environ.get('PGDATABASE')}"

db = SQLAlchemy(app)
migrate = Migrate(app, db)
