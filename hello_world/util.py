from werkzeug.routing import BaseConverter
from werkzeug.exceptions import HTTPException
import re

class EndpointNamingError(HTTPException):
    """ This class extends Flask HTTPException to return custom error if username validation failed """

    code = 400
    description = "Endpoint naming error"

class LettersOnlyConverter(BaseConverter):
    """ This class extends BaseConverter to match regular
    expression contains only uppercase and lowercase letters.
    On validation error HTTPException returned with HTTP code 400 """

    def to_python(self, value: str):
        if not re.match("^[A-z]+$", value):
            raise EndpointNamingError('Only letters are allowed for <username> endpoint')
        return value
