#!/bin/bash
set -e

# Import Claude Code Transcript and Extract Features
# Processes a transcript file and optionally creates GitHub issues

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
META_REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TRANSCRIPTS_DIR="$META_REPO_ROOT/features/transcripts"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Transcript file required${NC}"
    echo ""
    echo "Usage: $0 <transcript-file> [--create-issues]"
    echo ""
    echo "Example:"
    echo "  $0 ~/Downloads/transcript.jsonl"
    echo "  $0 ~/Downloads/transcript.jsonl --create-issues"
    echo ""
    echo "This will:"
    echo "  1. Copy transcript to features/transcripts/"
    echo "  2. Start Claude Code session"
    echo "  3. Ask Claude to analyze transcript and extract features"
    echo "  4. Optionally create GitHub issues for each feature"
    exit 1
fi

TRANSCRIPT_FILE=$1
CREATE_ISSUES=${2:-""}

if [ ! -f "$TRANSCRIPT_FILE" ]; then
    echo -e "${RED}Error: Transcript file not found: $TRANSCRIPT_FILE${NC}"
    exit 1
fi

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Transcript Import and Analysis                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Create transcripts directory if doesn't exist
mkdir -p "$TRANSCRIPTS_DIR"

# Copy transcript file
TRANSCRIPT_NAME=$(basename "$TRANSCRIPT_FILE")
TRANSCRIPT_DEST="$TRANSCRIPTS_DIR/$TRANSCRIPT_NAME"

echo -e "${BLUE}[1/3] Copying transcript...${NC}"
cp "$TRANSCRIPT_FILE" "$TRANSCRIPT_DEST"
echo -e "${GREEN}✓ Transcript saved to: features/transcripts/$TRANSCRIPT_NAME${NC}"
echo ""

# Create analysis file
ANALYSIS_FILE="$TRANSCRIPTS_DIR/${TRANSCRIPT_NAME%.jsonl}-analysis.md"

echo -e "${BLUE}[2/3] Creating analysis template...${NC}"

cat > "$ANALYSIS_FILE" << 'EOF'
# Transcript Analysis

## Source
[Transcript file](./[TRANSCRIPT_NAME])

## Executive Summary

[TO BE FILLED BY CLAUDE - High-level summary of the conversation]

## Key Features Identified

### Feature 1: [Name]
**Description**: [What this feature does]
**Priority**: High/Medium/Low
**Affected Services**: Tasks / BFF / Frontend
**Estimated Complexity**: Small / Medium / Large

**User Story**:
As a [user type], I want to [action] so that [benefit]

**Acceptance Criteria**:
- [ ] Criterion 1
- [ ] Criterion 2

---

### Feature 2: [Name]
[Same structure...]

---

## Technical Implications

### Architecture Changes
[TO BE FILLED BY CLAUDE - High-level architecture impacts]

### New Dependencies
[TO BE FILLED BY CLAUDE - New packages or services needed]

### Data Model Changes
[TO BE FILLED BY CLAUDE - Database schema changes]

### API Changes
[TO BE FILLED BY CLAUDE - New or modified endpoints]

## Risks and Considerations

[TO BE FILLED BY CLAUDE - Technical risks, breaking changes, etc.]

## Recommended Implementation Order

1. [Feature X] - [Reason]
2. [Feature Y] - [Reason]
3. [Feature Z] - [Reason]

## Next Steps

- [ ] Review analysis
- [ ] Create GitHub issues for approved features
- [ ] Prioritize in project board
- [ ] Begin implementation

---

**Instructions for Claude**:
1. Read the transcript at features/transcripts/[TRANSCRIPT_NAME]
2. Fill in all sections above
3. Extract specific, actionable features
4. Include technical details from the conversation
5. Prioritize features by value and complexity
EOF

# Replace placeholder
sed -i '' "s/\[TRANSCRIPT_NAME\]/$TRANSCRIPT_NAME/g" "$ANALYSIS_FILE"

echo -e "${GREEN}✓ Analysis template created: features/transcripts/${TRANSCRIPT_NAME%.jsonl}-analysis.md${NC}"
echo ""

# Provide next steps
echo -e "${CYAN}[3/3] Next Steps${NC}"
echo ""
echo -e "${YELLOW}1. Analyze the transcript:${NC}"
echo -e "   Run Claude Code from meta repo: ${GREEN}claude${NC}"
echo -e ""
echo -e "   Then prompt:"
echo -e "${BLUE}   Read features/transcripts/$TRANSCRIPT_NAME and analyze it.${NC}"
echo -e "${BLUE}   Fill in features/transcripts/${TRANSCRIPT_NAME%.jsonl}-analysis.md with:${NC}"
echo -e "${BLUE}   - Executive summary${NC}"
echo -e "${BLUE}   - Specific features identified (be thorough)${NC}"
echo -e "${BLUE}   - Technical implications${NC}"
echo -e "${BLUE}   - Recommended implementation order${NC}"
echo ""
echo -e "${YELLOW}2. Review the analysis${NC}"
echo -e "   Open: ${GREEN}features/transcripts/${TRANSCRIPT_NAME%.jsonl}-analysis.md${NC}"
echo ""

if [ "$CREATE_ISSUES" == "--create-issues" ]; then
    echo -e "${YELLOW}3. Create GitHub issues:${NC}"
    echo -e "   After reviewing the analysis, run:"
    echo -e "   ${GREEN}./scripts/create-issues-from-analysis.sh features/transcripts/${TRANSCRIPT_NAME%.jsonl}-analysis.md${NC}"
else
    echo -e "${YELLOW}3. Optionally create GitHub issues:${NC}"
    echo -e "   Re-run with: ${GREEN}$0 $TRANSCRIPT_FILE --create-issues${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Ready for Analysis!                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
