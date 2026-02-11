#!/bin/bash
# Generate the Apps table in README.md from app.yml manifests.
# Runs in CI on every push to main, or manually via: ./scripts/generate-readme.sh
set -euo pipefail

CATALOG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
README="$CATALOG_DIR/README.md"

# Use Python to parse YAML reliably (PyYAML ships on GitHub runners + most systems)
TABLE=$(python3 -c "
import os, glob, yaml

rows = []
for yml_path in sorted(glob.glob('$CATALOG_DIR/apps/*/app.yml')):
    app_id = os.path.basename(os.path.dirname(yml_path))
    with open(yml_path) as f:
        m = yaml.safe_load(f)

    name = m.get('name', app_id)
    version = m.get('version', '?')
    categories = ', '.join(m.get('categories', []))
    os_tmpl = m.get('lxc', {}).get('ostemplate', '?')

    gpu_list = m.get('gpu', {}).get('supported', [])
    gpu = ', '.join(gpu_list) if gpu_list else '-'

    rows.append(f'| [{name}](apps/{app_id}/) | {version} | {categories} | {os_tmpl} | {gpu} |')

print('| App | Version | Category | OS | GPU |')
print('|-----|---------|----------|----|-----|')
for r in rows:
    print(r)
")

# Replace content between markers in README
if grep -q '<!-- BEGIN_APP_TABLE -->' "$README"; then
    awk -v table="$TABLE" '
        /<!-- BEGIN_APP_TABLE -->/ { print; print ""; print table; skip=1; next }
        /<!-- END_APP_TABLE -->/ { skip=0 }
        !skip { print }
    ' "$README" > "$README.tmp"
    mv "$README.tmp" "$README"
    count=$(echo "$TABLE" | grep -c '^\|' || true)
    echo "Updated app table in README.md ($((count - 2)) apps)"
else
    echo "ERROR: Missing <!-- BEGIN_APP_TABLE --> / <!-- END_APP_TABLE --> markers in README.md"
    exit 1
fi
