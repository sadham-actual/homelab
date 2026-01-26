# ADR-0005: Use Git for Documentation Instead of Wiki

**Date:** 2025-01-26

**Status:** Accepted

### Context

Need to document entire homelab journey: hardware, configurations, decisions, lessons learned. Options for documentation platform:

1. Git repository (Markdown files)
2. Wiki (MediaWiki, DokuWiki, etc.)
3. Notion/Obsidian (proprietary tools)
4. Blog platform (WordPress, Hugo, etc.)

**Requirements:**
- Version control (track changes over time)
- Easy to edit (from any computer)
- Portable (not locked to platform)
- Can share publicly later if desired
- Good for code snippets and configurations
- Free

### Decision

**Use Git repository with Markdown files** hosted on GitHub for all homelab documentation.

Structure documentation as described in main README.

### Consequences

**Positive:**
- Full version control (every change tracked)
- Markdown is universal and portable
- GitHub provides free hosting (public or private)
- Easy to edit locally (VS Code, vim, any text editor)
- Code snippets and configs in same repository
- Can generate static site later if desired (MkDocs, Docusaurus)
- Great for collaboration (pull requests, issues)
- Searchable (GitHub search + local grep)

**Negative:**
- Less visual than wiki (no WYSIWYG editor)
- Need basic Git knowledge (learning opportunity)
- Images require separate handling (store in repo or external)
- Not as easy to browse as wiki (no sidebar links, unless generated)

**Mitigation:**
- Learn Git basics (valuable skill anyway)
- Use clear folder structure and README links
- Can generate static site later with MkDocs for better navigation

### Alternatives Considered

**Wiki (DokuWiki, BookStack, etc.):**
- Pros: Easy to browse, WYSIWYG editing, good for non-technical users
- Cons: Need to host somewhere, harder to version control, may lose data if server fails
- Why rejected: Git provides better version control and portability

**Notion/Obsidian:**
- Pros: Beautiful UI, easy to use, good for personal notes
- Cons: Proprietary format, not great for code/configs, harder to share/collaborate
- Why rejected: Want open format (Markdown) and easy collaboration (Git)

**Blog platform:**
- Pros: Chronological posts work well for journey documentation
- Cons: Less structured for reference docs, harder to update old posts
- Why rejected: Need structured reference docs, not just chronological blog

---