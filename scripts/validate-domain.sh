#!/bin/bash
# Validates a domain configuration file against the JSON schema

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Source libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"

DOMAIN_FILE="$1"
SCHEMA_FILE="$ROOT_DIR/platform/schemas/domain-config.schema.json"

# Usage
if [ -z "$DOMAIN_FILE" ]; then
    echo "Usage: $0 <domain-config-file>"
    echo ""
    echo "Example:"
    echo "  $0 platform/examples/simple-notes.yaml"
    exit 1
fi

# Check if domain file exists
if [ ! -f "$DOMAIN_FILE" ]; then
    log_error "Domain file not found: $DOMAIN_FILE"
    exit 1
fi

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    log_error "Schema file not found: $SCHEMA_FILE"
    exit 1
fi

log_info "Validating domain configuration: $DOMAIN_FILE"

# Check if we have validation tools
if ! command -v node &> /dev/null; then
    log_error "Node.js is required for validation"
    exit 1
fi

# Check if ajv-cli is available globally, if not check locally
if ! command -v ajv &> /dev/null; then
    # Try local node_modules
    if [ ! -f "$ROOT_DIR/node_modules/.bin/ajv" ]; then
        log_warning "ajv-cli not found. Installing validation dependencies..."
        cd "$ROOT_DIR"
        npm install --save-dev ajv-cli ajv-formats js-yaml
        cd - > /dev/null
    fi
    AJV_CMD="$ROOT_DIR/node_modules/.bin/ajv"
else
    AJV_CMD="ajv"
fi

# Convert YAML to JSON for validation
log_info "Converting YAML to JSON..."
TEMP_JSON=$(mktemp)
node -e "
const yaml = require('js-yaml');
const fs = require('fs');
try {
  const doc = yaml.load(fs.readFileSync('$DOMAIN_FILE', 'utf8'));
  fs.writeFileSync('$TEMP_JSON', JSON.stringify(doc, null, 2));
  process.exit(0);
} catch (e) {
  console.error('YAML parsing error:', e.message);
  process.exit(1);
}
" || {
    log_error "Failed to parse YAML file"
    rm -f "$TEMP_JSON"
    exit 1
}

# Validate against schema
log_info "Validating against schema..."

# Use Node.js with ajv directly for better error messages
node -e "
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

try {
  const schema = JSON.parse(fs.readFileSync('$SCHEMA_FILE', 'utf8'));
  const data = JSON.parse(fs.readFileSync('$TEMP_JSON', 'utf8'));

  const validate = ajv.compile(schema);
  const valid = validate(data);

  if (!valid) {
    console.error('Validation errors:');
    validate.errors.forEach(err => {
      console.error('  -', err.instancePath || '(root)', ':', err.message);
      if (err.params) {
        console.error('    ', JSON.stringify(err.params));
      }
    });
    process.exit(1);
  }

  process.exit(0);
} catch (e) {
  console.error('Validation error:', e.message);
  process.exit(1);
}
"

VALIDATION_RESULT=$?
rm -f "$TEMP_JSON"

if [ $VALIDATION_RESULT -eq 0 ]; then
    log_success "✓ Domain configuration is valid"
    exit 0
else
    log_error "✗ Domain configuration validation failed"
    exit 1
fi
