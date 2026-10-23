# многоступенчатая сборка, запуск не от root
#
# воспроизводимая сборка: идентичный код даёт одинаковые слои и digest,
# чтобы при повторном деплое контейнер сервиса не пересоздавался:
#  - фиксированные версии poetry и плагина экспорта
#  - установка пакетов pip с флагом --no-compile
#  - для adduser зафиксирован SOURCE_DATE_EPOCH
#  - kaniko собирает с параметром --reproducible
FROM python:3.11.6-slim-bookworm AS base


FROM base AS build
SHELL [ "/bin/sh", "-eu", "-c" ]
WORKDIR /build

RUN python -m pip install \
      --no-color \
      --no-cache-dir \
      --disable-pip-version-check \
      --no-python-version-warning \
      --no-warn-script-location \
      --break-system-packages \
      --progress-bar off \
      poetry==2.5.1 poetry-plugin-export==1.10.1 setuptools wheel

COPY pyproject.toml poetry.lock README.md ./
COPY src/ src/

RUN mkdir -p dist \
 && poetry export \
      --without-hashes \
      --format constraints.txt \
      --output dist/constraints.txt \
 && poetry run \
      python -m pip wheel \
        --isolated \
        --no-cache-dir \
        --requirement dist/constraints.txt \
        --wheel-dir dist/vendor \
 && poetry build --format wheel


FROM base AS final
SHELL [ "/bin/sh", "-eu", "-c" ]

ARG USER=audit
ARG HOME=/app
ARG UID=1001
ARG GID=1001
RUN \
  export SOURCE_DATE_EPOCH=0 \
  && addgroup --gid "${GID}" "${USER}" \
  && adduser --disabled-password --gecos "" \
       --home "${HOME}" --ingroup "${USER}" --uid "${UID}" "${USER}"

WORKDIR ${HOME}
COPY --from=build /build/dist/ /tmp/dist/

# ставим колёса и сразу удаляем dist; скрипты server, migrate, generate попадают в /usr/local/bin
RUN packages=$(find /tmp/dist /tmp/dist/vendor -maxdepth 1 -iname '*.whl' -print0 | xargs --null) \
 && python -m pip install \
      --isolated \
      --no-index \
      --no-color \
      --no-cache-dir \
      --no-compile \
      --disable-pip-version-check \
      --no-python-version-warning \
      --no-warn-script-location \
      --no-deps \
      --break-system-packages \
      --progress-bar off \
      ${packages} \
 && rm -rf /tmp/dist

USER ${USER}
ENV HOST=0.0.0.0 \
    PORT=8080 \
    AUDIT_SVC_CONFIG=/etc/audit-svc/config.yaml \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
EXPOSE 8080
CMD [ "server" ]
