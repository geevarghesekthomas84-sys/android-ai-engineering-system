---
name: app-product-architect
description: App product architecture for planning Android and full-stack applications including requirements analysis, system design, technology selection, feature specification, and project scaffolding
metadata:
  author: Custom
  keywords:
  - architecture
  - product-design
  - system-design
  - requirements
  - specification
  - scaffolding
  - planning
---

# App Product Architect

A comprehensive skill for designing and planning Android and full-stack applications from concept to scaffolded project. Covers the full product architecture lifecycle: requirements gathering, system design, technology selection, feature specification, data modeling, API contracts, and project scaffolding.

## Trigger Conditions

Activate this skill when the user:

- Wants to plan or design a **new application** from scratch
- Needs **system architecture** design for a mobile or full-stack app
- Is making **technology selection** decisions (database, backend framework, cloud platform)
- Requires **feature planning** and specification for an app idea
- Wants an **architecture review** of an existing system design
- Needs to define an **MVP** or prioritize features for a product
- Asks for **project scaffolding** or module structure guidance
- Wants to design **data models**, **API contracts**, or **database schemas**
- Needs help writing **user stories** or **acceptance criteria**
- Is planning **iteration milestones** or estimating project timelines

## Capabilities

### Requirements Analysis
- Gather and document functional and non-functional requirements
- Write user stories in standard format with acceptance criteria (Given/When/Then)
- Apply MoSCoW prioritization to feature lists
- Define MVP scope with clear boundaries
- Map stakeholders and their concerns
- Identify constraints (budget, timeline, platform, compliance)

### System Architecture Design
- Design client-server architecture for Android + backend systems
- Choose between monolith, modular monolith, and microservices
- Apply patterns: BFF, API Gateway, CQRS, event-driven
- Create text-based architecture diagrams (component, sequence, data flow)
- Plan for scalability, caching, CDN, message queues

### Technology Stack Selection
- Evaluate Android stack options (Compose vs Views, Navigation3, DI frameworks)
- Compare backend frameworks (NestJS, FastAPI, Spring Boot)
- Select databases (PostgreSQL, MongoDB, Firestore, Room)
- Choose cloud platforms (Firebase, Supabase, AWS, GCP)
- Use weighted decision matrices for objective comparisons

### Feature Specification
- Break features into epics, stories, and tasks
- Define screen flows and navigation graphs
- Specify state management strategy per feature
- Document edge cases, error states, loading states
- Estimate complexity using T-shirt sizing or story points

### Data Model Design
- Design entity-relationship models
- Create Room entities with relationships (@Relation, @Embedded, junction tables)
- Design PostgreSQL schemas with proper normalization
- Plan migration strategies and seed data
- Define validation rules and audit fields

### API Contract Design
- Write OpenAPI 3.1 specifications
- Design RESTful resource models with proper naming
- Define authentication and authorization schemes
- Specify error formats (RFC 7807), pagination (cursor-based), versioning
- Design webhook contracts for real-time events

### Project Scaffolding
- Generate Android multi-module project structures (:app, :core, :feature, :data)
- Set up Gradle convention plugins and version catalogs
- Scaffold backend project structures (NestJS modules, FastAPI routers)
- Create CI/CD pipeline templates (GitHub Actions)
- Generate environment configuration and documentation templates

## Workflow

Follow this sequence when architecting a new application. Skip steps that are already completed or not relevant.

### Phase 1: Discovery
1. **Gather Requirements** - Ask about the app idea, target users, core problem being solved
2. **Define User Stories** - Convert requirements into structured user stories with acceptance criteria
3. **Prioritize Features** - Apply MoSCoW to separate MVP from future iterations
4. **Identify Constraints** - Budget, timeline, team size, platform requirements, compliance needs

### Phase 2: Design
5. **Design System Architecture** - Choose architecture pattern, define components and their interactions
6. **Select Technology Stack** - Use decision matrices to pick Android stack, backend, database, cloud
7. **Design Data Models** - Create entity-relationship diagrams, define schemas for Room and backend DB
8. **Define API Contracts** - Write OpenAPI specs for all endpoints, define auth and error handling

### Phase 3: Plan
9. **Scaffold Project** - Generate project structure, configure build system, set up CI/CD
10. **Plan Iterations** - Break work into sprints or milestones with clear deliverables
11. **Estimate Timeline** - Provide rough estimates per feature based on complexity

## Output Formats

### Architecture Diagrams
Use text-based diagrams for system components:
```
[Android App] --> [API Gateway] --> [Auth Service]
                                --> [User Service] --> [PostgreSQL]
                                --> [Media Service] --> [S3/Cloud Storage]
                                --> [Notification Service] --> [FCM]
```

### Project Structure Trees
```
project-root/
  app/                    # Application module
  core/
    common/               # Shared utilities, extensions
    network/              # Retrofit setup, API client
    database/             # Room database, DAOs
    ui/                   # Design system, theme, shared composables
  feature/
    auth/                 # Login, registration, profile
    home/                 # Main screen, dashboard
  data/
    model/                # Domain models
    repository/           # Repository implementations
  build-logic/            # Convention plugins
  gradle/
    libs.versions.toml    # Version catalog
```

### API Specifications
Provide endpoint tables with method, path, request body, response, and auth requirements.

### Data Models
Provide entity tables with field name, type, constraints, and relationships.

## Reference Files

- `references/requirements-analysis.md` - Requirements gathering techniques and formats
- `references/system-design.md` - System architecture patterns and design principles
- `references/tech-stack-selection.md` - Technology comparison and selection criteria
- `references/api-contracts.md` - API design standards and OpenAPI specification
- `references/data-modeling.md` - Entity design, Room entities, and schema patterns
- `references/project-scaffolding.md` - Project structure and build system setup
- `references/app-templates.md` - Pre-built architecture templates for common app types
