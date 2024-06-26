import sys
sys.path.append("./")
import json
from flask import jsonify, request
from util import EndpointNamingError
from datetime import datetime
from hello_world import app

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

    except (json.decoder.JSONDecodeError, KeyError):
        return "Invalid JSON provided", 500
    except ValueError:
        return "Invalid date provided", 500

    return "No Content", 204

@app.route('/hello/<lettersOnly:username>', methods=['GET'])
def hello_get(username):
    """ Router for GET method for /hello/username endpoint """
    return "{'result': 'OK'}"

@app.errorhandler(EndpointNamingError)
def handle_naming_errors(e):
    """ Custom error handler for lettersOnly convertor exceptions """
    response = {
        "error": e.description,
        "code": e.code
    }
    return jsonify(response), e.code

if __name__ == "__main__":
    app.run()