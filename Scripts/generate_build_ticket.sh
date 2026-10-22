#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
identity="$root/BuildTicket.conf"
output="$root/Generated/BuildTicket+Current.swift"

identity_value() {
  local key="$1"
  local value=""
  local line

  if [[ ! -f "$identity" ]]; then
    echo "error: missing $identity" >&2
    exit 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" == "$key="* ]]; then
      value="${line#"$key"=}"
    fi
  done < "$identity"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  if [[ -z "$value" ]]; then
    echo "error: BuildTicket.conf is missing a value for ${key}" >&2
    exit 1
  fi

  printf '%s' "$value"
}

normalize_repository_url() {
  local url="$1"
  url="${url%.git}"
  url="${url%/}"

  if [[ "$url" == git@*:* ]]; then
    local rest="${url#git@}"
    local host="${rest%%:*}"
    local path="${rest#*:}"
    url="https://${host}/${path}"
  elif [[ "$url" == ssh://* ]]; then
    url="${url#ssh://}"
    url="${url#git@}"
    url="https://${url}"
  fi

  printf '%s' "$url"
}

escape_swift_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}

year="$(date -u +%Y)"
sha="$(git -C "$root" rev-parse HEAD)"

if [[ -n "${RELEASE_TAG:-}" ]]; then
  reference="$RELEASE_TAG"
elif [[ -n "${GITHUB_HEAD_REF:-}" ]]; then
  reference="$GITHUB_HEAD_REF"
elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
  reference="$GITHUB_REF_NAME"
elif reference="$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null)" \
  && [[ -n "$reference" ]]; then
  :
else
  reference="$(git -C "$root" describe --tags --always)"
fi

if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  repository_url="${GITHUB_SERVER_URL%/}/${GITHUB_REPOSITORY}"
else
  repository_url="$(
    normalize_repository_url "$(git -C "$root" remote get-url origin)"
  )"
fi

copyright="$(identity_value copyright)"
license="$(identity_value license)"
license_url="$(identity_value licenseURL)"
marketing_url="$(identity_value marketingURL)"
privacy_policy_url="$(identity_value privacyPolicyURL)"
terms_of_service_url="$(identity_value termsOfServiceURL)"

copyright_literal="$(escape_swift_string "$copyright")"
license_literal="$(escape_swift_string "$license")"
license_url_literal="$(escape_swift_string "$license_url")"
marketing_url_literal="$(escape_swift_string "$marketing_url")"
privacy_policy_url_literal="$(escape_swift_string "$privacy_policy_url")"
terms_of_service_url_literal="$(escape_swift_string "$terms_of_service_url")"
year_literal="$(escape_swift_string "$year")"
sha_literal="$(escape_swift_string "$sha")"
reference_literal="$(escape_swift_string "$reference")"
repository_literal="$(escape_swift_string "$repository_url")"

mkdir -p "$(dirname "$output")"

cat > "$output" <<EOF
//
//  BuildTicket+Current.swift
//  dawnApp
//
//  Generated at build time by Scripts/generate_build_ticket.sh.
//  This file is untracked. Do not edit it by hand.
//

extension BuildTicket {
    static let current: BuildTicket = {
        do {
            return try BuildTicket(
                copyright: "${copyright_literal}",
                license: "${license_literal}",
                licenseURL: "${license_url_literal}",
                marketingURL: "${marketing_url_literal}",
                privacyPolicyURL: "${privacy_policy_url_literal}",
                termsOfServiceURL: "${terms_of_service_url_literal}",
                year: "${year_literal}",
                sha: "${sha_literal}",
                reference: "${reference_literal}",
                repositoryURL: "${repository_literal}"
            )
        } catch {
            fatalError("Invalid generated build ticket: \\(error)")
        }
    }()
}
EOF
