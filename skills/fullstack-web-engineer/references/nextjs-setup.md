# Next.js Project Setup — App Router

## Project Creation

```bash
npx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
cd my-app
```

This creates a Next.js project with TypeScript, Tailwind CSS, ESLint, the App Router, a `src/` directory, and `@/` import aliases.

## App Router Directory Structure

```
src/
├── app/
│   ├── layout.tsx              # Root layout (wraps all pages)
│   ├── page.tsx                # Home page (/)
│   ├── loading.tsx             # Loading UI for / route
│   ├── error.tsx               # Error UI for / route
│   ├── not-found.tsx           # 404 page
│   ├── globals.css             # Global styles (Tailwind directives)
│   ├── (auth)/                 # Route group (no URL segment)
│   │   ├── login/
│   │   │   └── page.tsx        # /login
│   │   └── register/
│   │       └── page.tsx        # /register
│   ├── dashboard/
│   │   ├── layout.tsx          # Dashboard layout (sidebar + header)
│   │   ├── page.tsx            # /dashboard
│   │   ├── loading.tsx         # Dashboard loading skeleton
│   │   ├── users/
│   │   │   ├── page.tsx        # /dashboard/users
│   │   │   └── [id]/
│   │   │       └── page.tsx    # /dashboard/users/:id
│   │   └── settings/
│   │       └── page.tsx        # /dashboard/settings
│   └── api/
│       ├── auth/
│       │   └── [...nextauth]/
│       │       └── route.ts    # NextAuth.js catch-all route
│       └── users/
│           └── route.ts        # GET/POST /api/users
├── components/
│   ├── ui/                     # shadcn/ui components
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   └── dialog.tsx
│   ├── layout/
│   │   ├── sidebar.tsx
│   │   ├── header.tsx
│   │   └── footer.tsx
│   └── features/
│       ├── user-table.tsx
│       └── stats-card.tsx
├── lib/
│   ├── api-client.ts           # API fetch wrapper
│   ├── auth.ts                 # NextAuth.js configuration
│   ├── utils.ts                # Utility functions (cn, formatDate, etc.)
│   └── validations.ts          # Zod schemas
├── hooks/
│   ├── use-users.ts            # TanStack Query hooks for users
│   └── use-debounce.ts         # Debounce hook
├── types/
│   ├── api.ts                  # API response types
│   └── user.ts                 # Domain types
└── providers/
    └── query-provider.tsx      # TanStack Query provider
```

## Special Files in the App Router

| File          | Purpose                                         |
|---------------|------------------------------------------------|
| `layout.tsx`  | Shared UI that wraps child routes; persists across navigations |
| `page.tsx`    | Unique UI for a route; makes the route publicly accessible |
| `loading.tsx` | Loading UI shown while the page's async data loads (uses Suspense) |
| `error.tsx`   | Error boundary UI; catches runtime errors in child components |
| `not-found.tsx` | 404 UI; rendered when `notFound()` is called |
| `route.ts`    | API route handler (GET, POST, PUT, DELETE, PATCH) |
| `template.tsx` | Like layout but re-mounts on every navigation |
| `default.tsx` | Fallback for parallel routes when no match exists |

## Server Components vs Client Components

Server Components (the default in App Router):
```tsx
// app/dashboard/page.tsx — this is a Server Component by default
import { db } from "@/lib/db";

export default async function DashboardPage() {
  const stats = await db.stats.getAll(); // Direct database access

  return (
    <div>
      <h1>Dashboard</h1>
      <pre>{JSON.stringify(stats, null, 2)}</pre>
    </div>
  );
}
```

Client Components (opt in with "use client"):
```tsx
"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";

export function Counter() {
  const [count, setCount] = useState(0);

  return (
    <Button onClick={() => setCount(count + 1)}>
      Count: {count}
    </Button>
  );
}
```

Rules for choosing:
- **Server Component** when the component only displays data, has no event handlers, uses no browser APIs, needs no React state or effects. This is the default — do not add "use client" unless needed.
- **Client Component** when the component uses `useState`, `useEffect`, `onClick`, `onChange`, browser APIs (`window`, `localStorage`), or third-party libraries that depend on the browser.

Pattern: keep the parent as a Server Component and push interactivity into small Client Component children.

## Server Actions

```tsx
// app/dashboard/users/actions.ts
"use server";

import { revalidatePath } from "next/cache";
import { db } from "@/lib/db";
import { userSchema } from "@/lib/validations";

export async function createUser(formData: FormData) {
  const raw = Object.fromEntries(formData);
  const validated = userSchema.parse(raw);

  await db.users.create(validated);
  revalidatePath("/dashboard/users");
}

export async function deleteUser(id: string) {
  await db.users.delete(id);
  revalidatePath("/dashboard/users");
}
```

Using server actions in a form:
```tsx
import { createUser } from "./actions";

export default function NewUserPage() {
  return (
    <form action={createUser}>
      <input name="name" required />
      <input name="email" type="email" required />
      <button type="submit">Create User</button>
    </form>
  );
}
```

## API Route Handlers

```tsx
// app/api/users/route.ts
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const page = parseInt(searchParams.get("page") ?? "1");

  const users = await db.users.findMany({ skip: (page - 1) * 20, take: 20 });
  return NextResponse.json({ users, page });
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const validated = userSchema.parse(body);

  const user = await db.users.create({ data: validated });
  return NextResponse.json(user, { status: 201 });
}
```

## Middleware

```tsx
// src/middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getToken } from "next-auth/jwt";

export async function middleware(request: NextRequest) {
  const token = await getToken({ req: request });
  const isAuthPage = request.nextUrl.pathname.startsWith("/login") ||
                     request.nextUrl.pathname.startsWith("/register");

  if (!token && !isAuthPage && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (token && isAuthPage) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/login", "/register"],
};
```

## TypeScript Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

## Environment Variables

```bash
# .env.local (git-ignored, local development)
DATABASE_URL="postgresql://user:pass@localhost:5432/mydb"
NEXTAUTH_SECRET="generate-with-openssl-rand-base64-32"
NEXTAUTH_URL="http://localhost:3000"

# Public variables (exposed to the browser)
NEXT_PUBLIC_API_URL="http://localhost:8080/api"
NEXT_PUBLIC_APP_NAME="My Dashboard"
```

Access in code:
```tsx
// Server-only (available in Server Components, route handlers, middleware)
const dbUrl = process.env.DATABASE_URL;

// Client and server (must have NEXT_PUBLIC_ prefix)
const apiUrl = process.env.NEXT_PUBLIC_API_URL;
```

## ESLint Configuration

```json
// .eslintrc.json
{
  "extends": [
    "next/core-web-vitals",
    "next/typescript"
  ],
  "rules": {
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    "prefer-const": "error",
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
```
