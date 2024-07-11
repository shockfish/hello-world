import sys
sys.path.append("./")
import json
from flask import jsonify, request
from util import EndpointNamingError
from datetime import datetime
from hello_world import app, db
from sqlalchemy import exc, text
import models
import re

@app.route('/hello/<lettersOnly:username>', methods=['PUT'])
def hello_put(username):
    """ Router for PUT method for /hello/username endpoint """
    if request.content_type != "application/json":
        return "Required content-type/json", 500

    try:
        data = json.loads(request.data)
        birth_date_raw = data["dateOfBirth"]
        birth_date = datetime.strptime(birth_date_raw, "%Y-%m-%d")

        if birth_date.date() >= datetime.today().date():
            return "Invalid date provided", 500

        user = models.User(
            username=username,
            birth_date=data["dateOfBirth"]
        )
        db.session.add(user)
        db.session.commit()

    except (json.decoder.JSONDecodeError, KeyError):
        return "Invalid JSON provided", 500
    except ValueError:
        return "Invalid date provided", 500
    except exc.SQLAlchemyError:
        return "SQLAlchemy error occurred", 500

    return "No Content", 204

@app.route('/hello/<lettersOnly:username>', methods=['GET'])
def hello_get(username):
    """ Router for GET method for /hello/username endpoint """

    # Query users by username. Return 404 if user not found
    result = models.User.query.filter_by(username=username).first_or_404()
    # Make dict from query result using regex
    # We may omit using serialization if only birth_date value returned (see __repr__ User class method)
    # Keep it if we need to fetch more keys from database, e.g. ID or username
    user = dict(re.findall('(\w+): ([\d\w,-]+)', str(result)))

    birth_date = datetime.strptime(user["birth_date"], "%Y-%m-%d").replace(year=datetime.today().year).date()
    today = datetime.today().date()

    if birth_date < today:
        days_left = (birth_date.replace(year=datetime.today().year + 1) - today).days
    elif birth_date > today:
        days_left = (birth_date - today).days
    else:
        return jsonify({'message': f'Hello, {username}! Happy birthday!'})

    return jsonify({'message': f'Hello, {username}! Your birthday is in {days_left} day(s)'})


@app.route('/health', methods=['GET'], strict_slashes=False)
def health():
    """ Method to perform health check with AWS ALB """
    try:
        db.session.execute(text('SELECT 1'))
        return jsonify({'ready': True, 'status': 'OK'}), 200
    except Exception as e:
        return jsonify({'ready': False, 'status': str(e)}), 500


@app.errorhandler(EndpointNamingError)
def handle_naming_errors(e):
    """ Custom error handler for lettersOnly convertor exceptions """
    return e.description, e.code

if __name__ == "__main__":
    app.run(host='0.0.0.0')