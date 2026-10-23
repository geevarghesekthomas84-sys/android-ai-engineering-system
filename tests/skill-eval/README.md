# Skill Evaluation Framework

Automated validation for the 14 AI engineering skills.

## Evaluation Types

### Deterministic Checks (automated, CI-safe)
These run in CI and produce pass/fail results without AI:
- **Structure validation** — every skill has SKILL.md, references/, correct layout
- **Content completeness** — reference files are non-empty, headings present
- **Code example syntax** — fenced code blocks have valid language tags
- **Link integrity** — internal cross-references resolve
- **Privacy compliance** — no hardcoded paths, credentials, or personal data
- **Command safety** — no unsupported Android CLI commands recommended

### AI Behavior Evaluations (manual, model-specific)
These require an AI assistant and vary by model:
- **Skill routing accuracy** — does the AI load the right skill for a prompt?
- **Code quality** — does generated code follow the skill's patterns?
- **Honest reporting** — does the AI avoid claiming unexecuted tests passed?
- **Tool usage** — does the AI use appropriate tools (ADB, Gradle, etc.)?

AI evaluations MUST report: model name, model version, exact prompts used, actual responses, and pass/fail determination.

## Running Deterministic Checks

```bash
# Run all deterministic evaluations
./tests/skill-eval/run-eval.sh

# Or via the CI workflow
gh workflow run skills-validation.yml
```

## Evaluation Catalog

See `eval-cases.json` for the full test matrix.
