---
name: changelog
description: Maintains a high-signal, semantic CHANGELOG.md using an AI "Intelligence Officer" subagent. Use when you want to update the project's changelog, summarize recent work, or prepare a release. Triggers on "update changelog", "/changelog", "generate changelog", "what has changed recently".
---

# Changelog Skill (The Intelligence Officer)

This skill automates the process of translating raw git history into high-signal, semantic project logs. It ensures that the `CHANGELOG.md` remains a "knowledge hub" that explains the *why* and *how* of changes.

## Workflow

1.  **Extract Commits**: The skill identifies the last recorded date in `CHANGELOG.md` and fetches all commits since that date.
2.  **Semantic Analysis**: Raw commits are passed to a `@generalist` subagent to be categorized (`Added`, `Changed`, `Fixed`, `Security`) and summarized.
3.  **Review**: You will be shown the proposed changelog entries for review.
4.  **Integration**: Approved entries are prepended to `CHANGELOG.md` under a new date heading.

## Usage

When triggered, follow this internal procedure:

1.  **Run Research**:
    ```python
    # Logic in skills/changelog/scripts/update_log.py
    latest_date = get_latest_date_from_file("CHANGELOG.md")
    commits = get_commits_since(latest_date)
    ```
2.  **Analyze with Subagent**:
    Use the template in `skills/changelog/references/prompt_template.md` and dispatch to `@generalist`.
    
    **Example Dispatch**:
    "Using the 'Intelligence Officer' prompt, analyze these commits and return a Keep a Changelog formatted snippet: [COMMIT_LIST]"

3.  **Apply Changes**:
    Use `update_changelog("CHANGELOG.md", ai_snippet)` after user approval.

## Principles
- **Consolidate**: Group small fixes (typos, formatting) into single, meaningful bullets.
- **Components**: **Bold** component names and file paths.
- **Signal over Noise**: Omit trivial changes that don't add project-level value.
