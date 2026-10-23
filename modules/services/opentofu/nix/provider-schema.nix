# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
# The caller supplies locked nixpkgs + one selected provider derivation.
{ lib, runCommand, formats, jq, coreutils, opentofu, provider }:
let
  engine = opentofu.withPlugins (_: [ provider ]);
  # nixpkgs' OpenTofu wrapper publishes Terraform providers under this registry.
  address = lib.replaceStrings
    [ "registry.terraform.io/" ] [ "registry.opentofu.org/" ]
    (lib.toLower provider.provider-source-address);
  input = (formats.json { }).generate "main.tf.json" {
    terraform.required_providers.selected = {
      source = address;
      version = "= ${provider.version}";
    };
  };
in
runCommand "${provider.pname}-${provider.version}-schema" {
  nativeBuildInputs = [ engine jq coreutils ];
  passthru = { inherit provider engine; };
} ''
  set -euo pipefail
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME" "$out"
  export CHECKPOINT_DISABLE=1 TF_IN_AUTOMATION=1
  cp ${input} main.tf.json
  # withPlugins installs a package-local mirror and excludes registry fallback.
  tofu init -backend=false -input=false -no-color
  tofu providers schema -json > "$out/schema.json"
  jq -e --arg address ${lib.escapeShellArg address} \
    '.format_version == "1.0" and (.provider_schemas | has($address))' \
    "$out/schema.json" > /dev/null
  digest=$(sha256sum "$out/schema.json" | cut -d ' ' -f 1)
  # Retain the exact engine used to obtain this Schema in the same output.
  # Consumers never reconstruct an executable from PATH or a second selection.
  ln -s ${engine} "$out/engine"
  mkdir -p "$out/indexes" "$out/inputs/"{provider,resource,data}
  # Validate path components before using exported names as package paths.
  jq -e --arg address ${lib.escapeShellArg address} '
    .provider_schemas[$address] |
    (.provider.block | type == "object") and
    ([((.resource_schemas // {}), (.data_source_schemas // {})) |
      to_entries[] | (.key | test("^[A-Za-z0-9_]+$")) and
                     (.value.block | type == "object")] | all)
  ' "$out/schema.json" > /dev/null
  jq -r --arg address ${lib.escapeShellArg address} '
    .provider_schemas[$address] |
    ([{kind: "provider", name: "provider", entry: .provider}] +
     [(.resource_schemas // {} | to_entries[]) |
       {kind: "resource", name: .key, entry: .value}] +
     [(.data_source_schemas // {} | to_entries[]) |
       {kind: "data", name: .key, entry: .value}])[] |
    .kind + "\t" + .name + "\t" + (.entry | tojson)
  ' "$out/schema.json" > "$TMPDIR/entries"
  while IFS=$'\t' read -r kind name entry; do
    printf '%s\n' "$entry" > "$out/inputs/$kind/$name.json"
  done < "$TMPDIR/entries"

  # One metadata-only index per kind. Hash in batches, not one process/type.
  shopt -s nullglob
  for kind in provider resource data; do
    (
      cd "$out"
      files=(inputs/"$kind"/*.json)
      if (( ''${#files[@]} )); then sha256sum "''${files[@]}"; fi
    ) > "$TMPDIR/$kind.hashes"
    jq -Rn --arg provider ${lib.escapeShellArg address} \
      --arg version ${lib.escapeShellArg provider.version} --arg digest "$digest" \
      --arg kind "$kind" '
      {provider: $provider, version: $version, "schema-sha256": $digest,
       kind: $kind,
       entries: ([inputs |
         capture("^(?<hash>[0-9a-f]{64})  inputs/" + $kind + "/(?<name>[A-Za-z0-9_]+)[.]json$") |
         {key: .name, value: .hash}] | from_entries)}
    ' < "$TMPDIR/$kind.hashes" > "$out/indexes/$kind.json"
  done
  (cd "$out"; sha256sum indexes/*.json) | jq -Rn '
    [inputs | capture("^(?<hash>[0-9a-f]{64})  indexes/(?<kind>[a-z]+)[.]json$") |
     {key: .kind, value: .hash}] | from_entries
  ' > "$TMPDIR/index-digests.json"
  jq -n --arg provider ${lib.escapeShellArg address} \
    --arg version ${lib.escapeShellArg provider.version} --arg digest "$digest" \
    --slurpfile indexes "$TMPDIR/index-digests.json" \
    '{format: "yuanxu/provider-schema-v2", provider: $provider,
      version: $version, "schema-sha256": $digest,
      indexes: $indexes[0]}' > "$out/manifest.json"
''
