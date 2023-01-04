ARG base_image=python:3.10-slim-bullseye

FROM ${base_image}

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="${PATH}:/root/.local/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

WORKDIR /app/

COPY --link /divvy_onboarding_ux.py /pyproject.toml /poetry.lock /app/

COPY --link /static/ /app/static/

COPY --link /templates/ /app/templates/

RUN set -eux && \
    apt-get update && \
    apt-get upgrade -qq --assume-yes && \
    apt-get install -qq --assume-yes build-essential python-dev && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install poetry && \
    POETRY_VIRTUALENVS_CREATE=false poetry install --no-dev --no-root --no-interaction --no-ansi && \
    zopfli --gzip -v --i10 /app/static/app.js && \
    touch /app/static/app.js.gz /app/static/app.js
