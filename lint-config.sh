#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables used by sourcing script (lint.sh)
# Lint configuration - customize per repository
# This file is sourced by lint.sh for both local and CI runs

# MegaLinter Docker image (use digest for reproducibility)
# renovate: TODO
MEGALINTER_IMAGE="ghcr.io/oxsecurity/megalinter-documentation@sha256:c2f426be556c45c8ca6ca4bccb147160711531c698362dd0a05918536fc022bf"

# Skip linting for renovate/dependabot commits in CI
SKIP_BOT_COMMITS=true

# MegaLinter flavor (use "all" for custom images to bypass flavor validation)
MEGALINTER_FLAVOR="all"
