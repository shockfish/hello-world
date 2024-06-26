FROM python:3.9-alpine

RUN adduser -D nonroot
RUN mkdir /home/app/ && chown -R nonroot:nonroot /home/app
WORKDIR /home/app
USER nonroot

COPY --chown=nonroot:nonroot hello_world ./hello_world
COPY --chown=nonroot:nonroot migrations ./migrations
COPY --chown=nonroot:nonroot requirements.txt .
COPY --chown=nonroot:nonroot --chmod=755 scripts/entrypoint.sh entrypoint.sh

ENV VIRTUAL_ENV=/home/app/venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$PATH:$VIRTUAL_ENV/bin:/home/nonroot/.local/bin"
ENV FLASK_APP=hello_world

RUN pip install -r requirements.txt

EXPOSE 5000/tcp

ENTRYPOINT ["/home/app/entrypoint.sh"]