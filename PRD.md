# Product Requirements Document (PRD)

**Status:** DRAFT — UNVALIDATED<br>
**Project:** TBD<br>
**Owner:** Project owner<br>
**Last updated:** TBD

> This is a discovery template, not a product specification. No actual project requirements have been supplied. All TBD fields are unresolved; all examples are illustrative only. Do not implement example features unless the owner explicitly approves them. Replace or remove the examples after discovery.

## 1. Product overview

| Field | Confirmed requirement |
| --- | --- |
| Product name | TBD |
| One-sentence description | TBD |
| Problem to solve | TBD |
| Primary user | TBD |
| Desired outcome | TBD |
| Current state (idea / existing product / migration) | TBD |
| Platform and deployment target | TBD |

## 2. Users and use cases

| User / role | Goal | Main pain point | Priority |
| --- | --- | --- | --- |
| TBD | TBD | TBD | TBD |

Describe the primary end-to-end user journey: trigger → actions → successful outcome. Identify any secondary roles only if needed. Separate actual users from the human owner and implementation agent.

**Primary journey:** TBD

## 3. Goals, scope and non-goals

**Business/product goals:** TBD<br>
**MVP success condition:** TBD<br>
**In scope for first release:** TBD<br>
**Explicitly out of scope:** TBD<br>
**Constraints (time, cost, platform, dependencies):** TBD

Priorities: P0 = essential to the agreed release; P1 = important but can follow; P2 = optional. The owner confirms priority and release boundaries.

## 4. Functional requirements

Use stable IDs so tasks and tests can reference requirements without duplicating the entire PRD.

| ID | Requirement | Priority | Status |
| --- | --- | --- | --- |
| FR-001 | TBD | TBD | Unconfirmed |

For each approved feature, document only the detail necessary to implement and test it:

- User and goal.
- Preconditions, trigger, main flow and expected output.
- Validation, error cases and permissions where applicable.
- Observable acceptance criteria and relevant dependencies.

### Example only — NOT an approved requirement

Suppose the product were a simple task-list application. A possible requirement would be:

**EX-FR-001 — Create a task** (illustrative only)

- Given an authorized user and a valid nonempty title, when the user submits the form, then the task is saved and appears in the list.
- Given an empty title, when the user submits the form, then a clear validation error is shown and no task is created.
- Given a failed save, when the user submits, then the application does not falsely display a successful save.

This example demonstrates the format; it does not imply that this project has tasks, accounts, forms or a database.

## 5. UX and design

| Topic | Confirmed decision |
| --- | --- |
| Primary screens or interfaces | TBD |
| Core interaction flow | TBD |
| Design references / branding | TBD |
| Device and browser support | TBD |
| Accessibility requirements | TBD |
| Empty, loading and error states | TBD |

Use existing design assets where applicable. Do not invent a design system unless the owner requires one.

## 6. Data, integrations and permissions

| Topic | Confirmed decision |
| --- | --- |
| Data entities and source of truth | TBD |
| External services / APIs | TBD |
| Authentication and roles | TBD |
| Sensitive data and retention | TBD |
| Import / export | TBD |
| Data migration and compatibility | TBD |

If an area is not relevant, mark it N/A with a reason. Do not create authentication, storage, integrations or other features solely because the template contains these fields.

## 7. Non-functional requirements

Define measurable targets only when justified by the product's intended use. Do not invent arbitrary service-level objectives.

| Area | Target or agreed baseline |
| --- | --- |
| Performance / expected load | TBD |
| Reliability and availability | TBD |
| Security and privacy | TBD |
| Backup and recovery (if applicable) | TBD |
| Observability / error reporting | TBD |
| Supported environments | TBD |
| Cost / operational limits | TBD |

Regardless of product targets, implementation must follow repository access controls, protect secrets and pass configured checks.

## 8. Release acceptance

A release is acceptable when:

- All approved P0 requirements have observable passing acceptance criteria.
- Relevant negative and regression cases pass.
- The agreed primary user journey works in the intended environment.
- Any explicitly agreed exclusions or known limitations are documented.
- Applicable delivery gates in `docs/DELIVERY.md` are verified.

**Release-specific acceptance criteria:** TBD<br>
**Success metrics / how they are measured:** TBD

## 9. Open questions and decisions

| ID | Question or decision | Status | Answer / owner decision |
| --- | --- | --- | --- |
| Q-001 | What product are we building, and for whom? | Open | TBD |
| Q-002 | What must work in the first usable release? | Open | TBD |

Keep only materially relevant questions. Record confirmed decisions here when they affect scope or resolve ambiguity; remove obsolete placeholders rather than maintaining a second specification.

## 10. Agent interview — run when the owner requests PRD discovery

First inspect available repository files to avoid asking about facts that already exist. Then ask questions in the owner's language, typically Polish if the owner writes in Polish. Use short batches (around 3–5 questions), adapt follow-ups to answers, and offer sensible options when the owner has not formed a preference. Do not ask for stack details that are objectively discoverable.

### Round A — product and scope

1. What are we building, in one or two sentences?
2. Who will use it, and what problem does it solve?
3. What is the single most important user journey?
4. What must be included in the first working release, and what should explicitly be excluded?
5. How will you know that the product is good enough to use or release?

### Round B — behavior and constraints (only relevant questions)

- What are the main screens, actions and expected outputs?
- What data is required, where does it come from, and who can access it?
- Which external systems must be integrated, if any?
- What happens when input is invalid or an external dependency fails?
- Are there existing design references, device requirements, constraints or deadlines?

### Round C — operational decisions (only unresolved essentials)

- Where should the product run, and what is the expected usage?
- Are there sensitive data, paid resources or irreversible actions that need special approval?
- What level of automated deployment and verification should be enabled?
- Which quality, recovery or performance targets actually matter for this product?

### Conclude discovery

Update this file with confirmed facts, stable requirement IDs, priorities and testable acceptance criteria. Distinguish recommendations from agreed decisions. Remove the illustrative example and irrelevant sections or mark them N/A. Present a concise summary of the agreed scope and unresolved decisions for approval. Set status to `APPROVED` only after owner confirmation. Subsequent changes to scope must be traceable to a confirmed owner decision and Git history.
