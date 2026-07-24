# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a personal documentation repository (Markdown only, no application code, no build/lint/test tooling) chronicling the user's homelab build-out: TrueNAS SCALE storage, Proxmox VE virtualization, a planned k3s cluster, and a planned OPNsense/VLAN network migration. The purpose is learning (toward CompTIA Network+, Security+, Linux+) and producing a reference others could later follow.

## Repository structure

- `docs/01-architecture/` — high-level design decisions and diagrams (Mermaid)
- `docs/02-hardware/` — hardware specs and capabilities per host
- `docs/03-truenas/` — storage config and service management on TrueNAS
- `docs/04-proxmox/` — Proxmox setup, networking, VM guides
- `docs/05-kubernetes/` — k3s installation and cluster docs
- `docs/06-networking/` — network design, VLANs, current setup
- `docs/07-migration/` — service migration strategy between hosts
- `docs/10-lessons-learned/` — journal/retrospective entries (e.g. `git-basics.md`)
- `decisions/` — Architecture Decision Records (ADRs), numbered `NNNN-title.md`
- `README.md` — project overview, roadmap, and the canonical statement of repository conventions

Numbered `docs/` subfolders are referenced by number in the README's "Documentation Structure" section — if adding a new category, follow that numbering scheme (e.g. `08-monitoring`, `09-security` are reserved but not yet created).

## Architecture Decision Records (ADRs)

- Copy `decisions/adr-template.md` when starting a new ADR; do not hand-roll the structure.
- Number ranges: `0001-0099` core architecture, `0100-0199` network/infrastructure, `0200-0299` service-specific, `0300-0399` security/compliance, `0400+` misc.
- ADRs are immutable once accepted. To change a decision, write a new ADR and mark the old one "Superseded by ADR-XXXX" — never edit an accepted ADR's decision in place.
- Only write an ADR for decisions with real trade-offs worth remembering later, not trivial or obvious choices.

## Content conventions

- **Sanitize all examples**: IPs as `192.168.X.X` / `10.0.X.X`, internal domains as `example.local`, external as `example.com`, hostnames generic-but-descriptive (`truenas-01`, `pve-node-01`). This repo may go public later, so nothing identifying (real IPs, real domain `example.com`, credentials, tokens) belongs in committed docs.
- Fenced code blocks always specify a language for syntax highlighting.
- Configuration snippets include comments explaining *why*, not just *what*.
- Diagrams use Mermaid fenced blocks (see recent history: network and VLAN diagrams were converted to Mermaid) rather than external image tools, so they render and diff directly on GitHub.

## Working conventions

- Commit messages are descriptive present-tense summaries (e.g. "Add k3s installation guide and architecture decision records"), not conventional-commit prefixes.
- When adding a new doc, cross-link it from the README's "Documentation Structure" or "Quick Links" section if it represents a new major topic.
