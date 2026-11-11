# System Architecture Specification

- **Project Name**: `<Project Name>`
- **Status**: `DRAFT | APPROVED`
- **Owner**: `AgentsV2 Architect`
- **Last Updated**: `YYYY-MM-DD`

## 1. Technology Stack & Runtime

- **Language / Runtime**: `<e.g., TypeScript / Node 22, Go 1.23, Dart / Flutter>`
- **Framework(s)**: `<e.g., Next.js, FastAPI, Gin>`
- **Persistence / External Services**: `<e.g., PostgreSQL, SQLite, Redis>`

## 2. Directory Structure & Module Boundaries

```text
project/
├── docs/
├── src/
└── tests/
```

Explain responsibilities and dependency rules between layers.

## 3. Data Models & Schemas

Document tables, entities, types, constraints, and migration strategy.

## 4. API / Interface Contracts

Specify endpoints, commands, request/response payloads, status codes, and error schemas.

## 5. Security & Error-Handling Strategy

- Authentication / authorization boundaries
- Validation rules and error envelope
- Configuration / environment variables (`.env.example`)

## 6. Testing & Verification Strategy

- Unit test command: `<command>`
- Integration test command: `<command>`
- Linter / static analysis command: `<command>`

## 7. Architecture Decision Records (ADRs)

- **ADR-001**: `<Decision>` — Rationale and trade-offs.
