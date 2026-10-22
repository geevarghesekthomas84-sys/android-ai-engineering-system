# Requirements Analysis

## Gathering Techniques

### User Interviews
Structure interviews around the problem space, not the solution:
- "What is the biggest pain point in your current workflow?"
- "Walk me through your typical day when dealing with [problem]."
- "What would your ideal solution look like?"
- "What have you tried before? What worked and what didn't?"

Record answers, identify patterns across multiple interviews, and extract themes.

### Competitive Analysis
For each competitor, document:
- **Core features**: What does it do well?
- **Gaps**: What is missing or poorly implemented?
- **UX patterns**: What interaction models do they use?
- **Monetization**: How do they make money?
- **Reviews**: What do users complain about (app store reviews, Reddit, Twitter)?

Build a feature matrix comparing competitors on key dimensions. Identify underserved needs.

### Market Research
- **TAM/SAM/SOM**: Total addressable market, serviceable addressable market, serviceable obtainable market
- **User segments**: Define 2-4 distinct user personas with goals, frustrations, and technical proficiency
- **Market trends**: Growing or shrinking? What technology shifts are happening?
- **Regulatory environment**: GDPR, HIPAA, PCI-DSS, accessibility requirements (WCAG)

## Functional vs Non-Functional Requirements

### Functional Requirements
What the system **does**. Each functional requirement maps to a user-visible behavior:
- "Users can register with email and password"
- "Users can search products by name, category, or price range"
- "The system sends push notifications for order status changes"

### Non-Functional Requirements
How the system **performs**. Quantify whenever possible:

| Category | Example | Target |
|---|---|---|
| Performance | Screen load time | < 500ms for cached, < 2s for network |
| Availability | Uptime | 99.9% (8.7 hours downtime/year) |
| Scalability | Concurrent users | Support 10,000 DAU at launch, 100,000 at 12 months |
| Security | Authentication | OAuth 2.0 + PKCE, biometric unlock, token refresh |
| Accessibility | WCAG compliance | Level AA |
| Offline support | Core features available offline | Read-only for lists, queued writes for mutations |
| Data retention | User data storage | 90-day activity log, indefinite account data |
| Localization | Language support | English at launch, Spanish and French by v2 |

## User Story Format

### Standard Template
```
As a [role],
I want [feature/capability],
so that [benefit/value].
```

### Examples
```
As a shopper,
I want to save items to a wishlist,
so that I can purchase them later without searching again.

As a store owner,
I want to view sales analytics by date range,
so that I can identify trends and plan inventory.
```

### Story Quality Checklist (INVEST)
- **I**ndependent: Can be developed without depending on other stories
- **N**egotiable: Details can be discussed and refined
- **V**aluable: Delivers value to the user or business
- **E**stimable: Team can estimate the effort
- **S**mall: Completable in one sprint (1-2 weeks)
- **T**estable: Has clear pass/fail criteria

## Acceptance Criteria (Given/When/Then)

Write acceptance criteria in Gherkin format for clarity:

```gherkin
Feature: Wishlist Management

  Scenario: Add item to wishlist
    Given I am viewing a product detail page
    And I am logged in
    When I tap the heart icon
    Then the item is added to my wishlist
    And the heart icon changes to filled
    And a snackbar confirms "Added to wishlist"

  Scenario: Add item to wishlist when not logged in
    Given I am viewing a product detail page
    And I am not logged in
    When I tap the heart icon
    Then I am prompted to log in or register
    And after successful login the item is added to my wishlist

  Scenario: Remove item from wishlist
    Given I am viewing my wishlist
    When I swipe left on an item and tap "Remove"
    Then the item is removed from my wishlist
    And I see an undo snackbar for 5 seconds
```

## MoSCoW Prioritization

Categorize every requirement into one of four buckets:

### Must Have (MVP)
Without these, the product does not work. Ship-blocking:
- Core authentication (register, login, logout)
- Primary use case screens and flows
- Essential data operations (CRUD for core entities)
- Basic error handling and offline feedback

### Should Have (v1.1)
Important but the product can launch without them:
- Advanced search and filtering
- Push notifications
- Social sharing
- Profile customization

### Could Have (v2+)
Nice-to-have features that enhance the experience:
- Dark mode / theming
- Widgets
- Wearable companion
- Analytics dashboard for users

### Won't Have (Backlog / Never)
Explicitly out of scope for the foreseeable future. Document these to prevent scope creep:
- Web version (focus on mobile first)
- AI-powered recommendations (maybe v3)
- Marketplace for third-party plugins

## MVP Definition

An MVP is the smallest product that validates the core hypothesis. Define it with:

1. **Hypothesis**: "We believe [user segment] will [behavior] because [reason]."
2. **Core screens**: List the 3-7 screens that support the hypothesis.
3. **Core flows**: Map the 2-3 user journeys that must work end-to-end.
4. **Success metrics**: DAU, retention (Day 1, Day 7, Day 30), task completion rate, NPS.
5. **Timeline**: MVP should be achievable in 4-8 weeks with a small team.

## Requirement Traceability

Maintain a traceability matrix linking requirements to implementation:

| Req ID | User Story | Priority | Module | Status | Notes |
|---|---|---|---|---|---|
| REQ-001 | Register with email | Must | :feature:auth | Done | Email verification added |
| REQ-002 | Search products | Must | :feature:search | In Progress | Full-text search via backend |
| REQ-003 | Push notifications | Should | :core:notification | Planned | FCM integration |

## Stakeholder Mapping

Identify everyone with influence or interest:

| Stakeholder | Role | Interest | Influence | Communication |
|---|---|---|---|---|
| Product Owner | Decision maker | High | High | Weekly review, Slack |
| Engineering Lead | Technical decisions | High | High | Daily standup, PR reviews |
| Designer | UX/UI decisions | High | Medium | Design reviews, Figma |
| End Users | Feature feedback | High | Low | Beta testing, surveys |
| Business Sponsor | Budget, timeline | Medium | High | Monthly updates |

## Constraint Identification

Document constraints early to avoid surprises:

- **Budget**: Total budget and burn rate. Does it cover cloud costs, third-party APIs, app store fees?
- **Timeline**: Hard deadlines (launch event, seasonal window, funding milestone)?
- **Team**: How many developers? What skill levels? Any gaps (no iOS dev, no designer)?
- **Platform**: Android-only? Minimum SDK version? Tablet support? Foldable support?
- **Compliance**: GDPR (EU users), CCPA (California), HIPAA (health data), PCI-DSS (payments)?
- **Third-party dependencies**: Payment processor lock-in? Map API limits? Social login requirements?
- **Technical**: Must integrate with existing systems? Legacy API constraints? Required SSO provider?
