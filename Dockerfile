# syntax = docker/dockerfile:1.4

ARG base_image=python:3.10-slim-bullseye

FROM ${base_image}

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="${PATH}:/root/.local/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

RUN set -eux && \
    apt-get update && \
    apt-get upgrade -qq --assume-yes && \
    apt-get install -qq --assume-yes build-essential python-dev zopfli && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install poetry && \
    useradd --home-dir /app/ --create-home --shell /bin/bash uwsgi

WORKDIR /app/

COPY --link --chown=uwsgi:uwsgi /static/ /app/static/

COPY --link --chown=uwsgi:uwsgi /templates/ /app/templates/

COPY --link --chown=uwsgi:uwsgi /divvy_onboarding_ux.py /pyproject.toml /poetry.lock /app/

RUN set -eux && \
    POETRY_VIRTUALENVS_CREATE=false poetry install --no-dev --no-root --no-interaction --no-ansi && \
    zopfli --gzip -v --i10 /app/static/app.js && \
    touch /app/static/app.js.gz /app/static/app.js

USER uwsgi
