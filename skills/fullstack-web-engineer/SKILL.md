---
name: fullstack-web-engineer
description: Full-stack web engineering with React, Next.js, TypeScript, Tailwind CSS, responsive design, admin dashboards, and API integration for web companions to Android apps
metadata:
  author: Custom
  keywords:
  - react
  - nextjs
  - typescript
  - tailwind
  - web
  - dashboard
  - responsive
  - fullstack
---

# Full-Stack Web Engineer

## Trigger Conditions

Activate this skill when the user asks to:
- Build a web dashboard or admin panel
- Create a landing page or marketing site
- Build a web companion app for an Android application
- Set up a React or Next.js project from scratch
- Implement data tables, charts, or analytics views
- Create authenticated web interfaces
- Build CRUD admin interfaces for managing backend data
- Design responsive layouts with Tailwind CSS
- Connect a web frontend to REST or GraphQL APIs
- Deploy a web application to Vercel, Docker, or other platforms
- Build real-time dashboards with WebSocket or SSE

## Core Capabilities

### Frontend Framework — React with TypeScript
- Functional components with strict TypeScript typing
- React 18+ features: Suspense, transitions, concurrent rendering
- State management: React Context for simple state, Zustand or Jotai for complex state
- Component libraries: shadcn/ui for polished UI, Radix UI for accessible primitives
- Form handling: react-hook-form with zod schema validation
- Data fetching: TanStack Query for server state management

### Meta-Framework — Next.js (App Router)
- App Router with nested layouts and parallel routes
- Server Components for data fetching without client-side JavaScript
- Server Actions for form mutations without API routes
- Route Handlers (route.ts) for REST API endpoints
- Middleware for authentication, redirects, and request modification
- Static generation (SSG), server-side rendering (SSR), and incremental static regeneration (ISR)
- Image optimization with next/image, font optimization with next/font

### Styling — Tailwind CSS
- Utility-first CSS with responsive breakpoints (sm, md, lg, xl, 2xl)
- Dark mode support with class-based toggling
- Custom theme configuration: brand colors, typography scale, spacing system
- Component extraction with @apply for repeated patterns
- shadcn/ui integration for pre-built accessible components
- CSS custom properties for runtime theme switching
- Animation utilities: transition, animate, and Framer Motion integration

### Admin Dashboard Patterns
- Sidebar navigation with collapsible sections and active indicators
- Data tables with TanStack Table: sorting, filtering, column visibility, pagination
- Charts with Recharts: line, bar, pie, area, composed charts with tooltips
- Stat cards with KPIs, trend indicators, and sparklines
- CRUD interfaces with inline editing, bulk actions, and confirmation dialogs
- Search with debounce, date range pickers, and advanced filters
- Export functionality: CSV, Excel, PDF generation
- Role-based UI: conditional rendering based on user permissions

### Authentication and Authorization
- NextAuth.js v5 with credentials, Google, and GitHub providers
- JWT strategy for stateless auth, session strategy for server-managed state
- Middleware-based route protection for entire route groups
- Role-based access control (RBAC) with permission checks
- Login, register, forgot password, and email verification flows
- Secure cookie handling, CSRF protection, refresh token rotation

### API Integration
- Type-safe API client with fetch or Axios
- TanStack Query for caching, refetching, and optimistic updates
- Real-time updates via WebSocket connections and Server-Sent Events
- File upload with progress tracking and drag-and-drop
- Error handling with typed error responses and retry logic
- API route handlers for BFF (Backend-for-Frontend) patterns

### Deployment
- Vercel: zero-config deployment, preview branches, environment variables
- Docker: multi-stage Dockerfile for Next.js, docker-compose for full stack
- Static export for CDN hosting (GitHub Pages, Cloudflare Pages, S3)
- Performance monitoring with Vercel Analytics or custom instrumentation
- Bundle analysis and optimization strategies

## Workflow

1. **Define Web Requirements** — Identify pages, user roles, data sources, and integration points with the Android app's backend API.

2. **Choose Framework Configuration** — Decide between full Next.js (SSR/SSG needed, SEO matters, API routes needed) or Vite + React (pure SPA, simpler deployment). Default to Next.js App Router for most projects.

3. **Scaffold Project** — Initialize with `create-next-app`, configure TypeScript strict mode, set up Tailwind CSS, install shadcn/ui, configure ESLint and Prettier, set up project structure.

4. **Implement Pages and Components** — Build layouts (sidebar, header, content area), implement pages as server components where possible, create reusable UI components, add responsive design for mobile through desktop.

5. **Connect API** — Set up the API client with base URL and auth headers, implement TanStack Query hooks for each endpoint, add loading and error states, implement optimistic updates for mutations.

6. **Add Authentication** — Configure NextAuth.js with the required providers, protect routes with middleware, implement login/register UI, add role-based access control to pages and API routes.

7. **Test and Polish** — Test responsive design across breakpoints, verify dark mode, check accessibility (keyboard navigation, screen readers, contrast), test error states, verify loading skeletons.

8. **Deploy** — Configure deployment target, set environment variables, verify build output, deploy with preview URL, run smoke tests, configure custom domain and SSL.

## Reference Files

- `references/nextjs-setup.md` — Next.js App Router project structure, server/client components, configuration
- `references/react-patterns.md` — React patterns with TypeScript, hooks, TanStack Query, form handling
- `references/tailwind-design.md` — Tailwind CSS design system, responsive design, shadcn/ui, theming
- `references/admin-dashboard.md` — Dashboard layouts, data tables, charts, stat cards, CRUD interfaces
- `references/web-auth.md` — NextAuth.js setup, OAuth, JWT, protected routes, RBAC
- `references/api-integration.md` — API client setup, TanStack Query, real-time updates, file uploads
- `references/deployment.md` — Vercel, Docker, static export, CDN, monitoring, performance

## Conventions

- Always use TypeScript strict mode — no `any` types in production code
- Prefer server components; add "use client" only when the component needs interactivity
- Use named exports for components, default exports only for page.tsx/layout.tsx
- Co-locate related files: component, styles, types, and tests in the same directory
- Use absolute imports with `@/` prefix configured in tsconfig.json
- Environment variables: NEXT_PUBLIC_ prefix for client-side, plain for server-only
- Error handling: every async operation gets a try/catch or error boundary
- Loading states: always show skeletons or spinners, never blank screens
