# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile for hevcesbrowser (SMALL form, on the org C/C++ base).
FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# Extra build deps: boost (parser test suite + console use system / program_options /
# unit_test_framework), cmake, and wget/ca-certificates to fetch the test sample streams.
USER root
RUN [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true ; \
    apt-get update && apt-get install -yq --no-install-recommends \
        cmake \
        libboost-dev \
        libboost-system-dev \
        libboost-program-options-dev \
        libboost-test-dev \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*
USER mayhem

WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

# Fetch the upstream test sample streams (referenced by hevcparser/tests/Parsing.cpp via
# getSourceDir()+"/samples/..."). Baked into the image so build.sh/test.sh re-run offline.
# Network is only needed HERE, at image-build time — never during the air-gapped build.sh re-run.
RUN bash mayhem/fetch-test-samples.sh

RUN bash mayhem/build.sh

# Run the project's functional suite at build time; a failing suite fails the image build.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
