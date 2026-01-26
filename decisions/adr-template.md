# ADR Template

## ADR-XXXX: [Short Title]

**Date:** YYYY-MM-DD

**Status:** [Proposed | Accepted | Deprecated | Superseded by ADR-YYYY]

**Context:** What is the issue or situation prompting this decision?

**Decision:** What is the change being proposed or decided?

**Consequences:** What are the positive and negative outcomes of this decision?

**Alternatives Considered:** What other options were evaluated?

---

# Using ADRs in Your Homelab

## When to Write an ADR

Write an ADR when:
- Making a significant architectural decision
- Choosing between multiple viable options
- Decision will affect multiple systems
- Future you (or others) will wonder "why did we do this?"
- You want to document your reasoning

**Don't write ADRs for:**
- Trivial decisions (choice of text editor)
- Obvious decisions (use passwords for security)
- Implementation details (variable names)

## ADR Numbering

- **0001-0099:** Core architecture decisions
- **0100-0199:** Network and infrastructure
- **0200-0299:** Service-specific decisions
- **0300-0399:** Security and compliance
- **0400+:** Miscellaneous

## Updating ADRs

ADRs are immutable once accepted. If decision changes:

1. Create new ADR (e.g., ADR-0010 supersedes ADR-0003)
2. Update old ADR status to "Superseded by ADR-0010"
3. Explain why decision changed in new ADR

## Template Usage

```bash
# Copy template
cp decisions/adr-template.md decisions/0006-new-decision.md

# Edit and fill in sections
# Commit to Git
git add decisions/0006-new-decision.md
git commit -m "Add ADR-0006: Decision about X"
```

---

*Last Updated: 2025-01-26*