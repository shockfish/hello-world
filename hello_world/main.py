from flask import Flask, jsonify, request
from util import LettersOnlyConverter, EndpointNamingError
import json

app = Flask(__name__)
app.url_map.converters['lettersOnly'] = LettersOnlyConverter

@app.route('/hello/<lettersOnly:username>', methods=['PUT'])
def hello_put(username):
    """ Router for PUT method for /hello/username endpoint """
    if request.content_type != "application/json":
        return "Required content-type/json", 500

    try:
        data = json.loads(request.data)

    except json.decoder.JSONDecodeError:
        return "Invalid JSON provided", 500

    return (data)

@app.route('/hello/<lettersOnly:username>', methods=['GET'])
def hello_get(username):
    """ Router for GET method for /hello/username endpoint """
    return "{'result': 'OK'}"

@app.errorhandler(EndpointNamingError)
def handle_naming_errors(e):
    """ Custom error handler for lettersOnly convertor exceptions """
    response = {
        "error": e.description
    }
    return jsonify(response), e.code

if __name__ == "__main__":
    app.run()