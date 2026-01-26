#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables used by sourcing script (lint.sh)
# Lint configuration - customize per repository
# This file is sourced by lint.sh for both local and CI runs

# MegaLinter Docker image (use digest for reproducibility)
# renovate: TODO
MEGALINTER_IMAGE="ghcr.io/anthony-spruyt/megalinter-claude-config@sha256:e5107e15c6002e182810f869f6228a4eaab934eeb62096bbc6e3b7f90a394000"

# Skip linting for renovate/dependabot commits in CI
SKIP_BOT_COMMITS=true

# MegaLinter flavor (use "all" for custom images to bypass flavor validation)
MEGALINTER_FLAVOR="all"
