# Web Authentication — NextAuth.js v5

## Installation

```bash
npm install next-auth@beta @auth/core
npm install bcryptjs
npm install -D @types/bcryptjs
```

## NextAuth.js Configuration

```tsx
// src/lib/auth.ts
import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import Google from "next-auth/providers/google";
import GitHub from "next-auth/providers/github";
import { z } from "zod";
import bcrypt from "bcryptjs";

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        const parsed = loginSchema.safeParse(credentials);
        if (!parsed.success) return null;

        const user = await db.users.findByEmail(parsed.data.email);
        if (!user || !user.hashedPassword) return null;

        const passwordMatch = await bcrypt.compare(parsed.data.password, user.hashedPassword);
        if (!passwordMatch) return null;

        return { id: user.id, name: user.name, email: user.email, role: user.role };
      },
    }),
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHub({
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    }),
  ],

  session: { strategy: "jwt" },

  pages: {
    signIn: "/login",
    error: "/login",
  },

  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = user.role;
        token.id = user.id;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.role = token.role as string;
        session.user.id = token.id as string;
      }
      return session;
    },
    async authorized({ auth, request }) {
      const isLoggedIn = !!auth?.user;
      const isOnDashboard = request.nextUrl.pathname.startsWith("/dashboard");
      if (isOnDashboard) return isLoggedIn;
      return true;
    },
  },
});
```

## Route Handler

```tsx
// src/app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/lib/auth";

export const { GET, POST } = handlers;
```

## Type Augmentation

```tsx
// src/types/next-auth.d.ts
import { DefaultSession } from "next-auth";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      role: string;
    } & DefaultSession["user"];
  }

  interface User {
    role: string;
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    id: string;
    role: string;
  }
}
```

## Middleware-Based Route Protection

```tsx
// src/middleware.ts
import { auth } from "@/lib/auth";
import { NextResponse } from "next/server";

export default auth((req) => {
  const { nextUrl } = req;
  const isLoggedIn = !!req.auth;

  const publicRoutes = ["/", "/login", "/register", "/forgot-password"];
  const authRoutes = ["/login", "/register"];
  const adminRoutes = ["/dashboard/admin"];

  // Redirect logged-in users away from auth pages
  if (isLoggedIn && authRoutes.includes(nextUrl.pathname)) {
    return NextResponse.redirect(new URL("/dashboard", nextUrl));
  }

  // Protect dashboard routes
  if (!isLoggedIn && nextUrl.pathname.startsWith("/dashboard")) {
    const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search);
    return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, nextUrl));
  }

  // Protect admin routes
  if (nextUrl.pathname.startsWith("/dashboard/admin")) {
    if (req.auth?.user?.role !== "admin") {
      return NextResponse.redirect(new URL("/dashboard", nextUrl));
    }
  }

  return NextResponse.next();
});

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
```

## Login Page

```tsx
"use client";

import { useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const callbackUrl = searchParams.get("callbackUrl") ?? "/dashboard";
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleCredentialLogin(formData: FormData) {
    setLoading(true);
    setError("");

    const result = await signIn("credentials", {
      email: formData.get("email"),
      password: formData.get("password"),
      redirect: false,
    });

    setLoading(false);

    if (result?.error) {
      setError("Invalid email or password");
    } else {
      router.push(callbackUrl);
      router.refresh();
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-sm space-y-6 rounded-lg border bg-card p-8 shadow-sm">
        <div className="text-center">
          <h1 className="text-2xl font-bold">Sign In</h1>
          <p className="mt-1 text-sm text-muted-foreground">Enter your credentials to continue</p>
        </div>

        {error && <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{error}</div>}

        <form action={handleCredentialLogin} className="space-y-4">
          <div>
            <label htmlFor="email" className="text-sm font-medium">Email</label>
            <input id="email" name="email" type="email" required className="mt-1 block w-full rounded-md border px-3 py-2" />
          </div>
          <div>
            <label htmlFor="password" className="text-sm font-medium">Password</label>
            <input id="password" name="password" type="password" required className="mt-1 block w-full rounded-md border px-3 py-2" />
          </div>
          <button type="submit" disabled={loading} className="w-full rounded-md bg-primary py-2 text-sm font-medium text-primary-foreground disabled:opacity-50">
            {loading ? "Signing in..." : "Sign In"}
          </button>
        </form>

        <div className="relative">
          <div className="absolute inset-0 flex items-center"><div className="w-full border-t" /></div>
          <div className="relative flex justify-center text-xs uppercase"><span className="bg-card px-2 text-muted-foreground">Or continue with</span></div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <button onClick={() => signIn("google", { callbackUrl })} className="rounded-md border px-4 py-2 text-sm hover:bg-accent">Google</button>
          <button onClick={() => signIn("github", { callbackUrl })} className="rounded-md border px-4 py-2 text-sm hover:bg-accent">GitHub</button>
        </div>
      </div>
    </div>
  );
}
```

## Role-Based Access Control

```tsx
// lib/rbac.ts
export type Role = "admin" | "editor" | "viewer";
export type Permission = "users:read" | "users:write" | "users:delete" | "settings:read" | "settings:write" | "analytics:read";

const rolePermissions: Record<Role, Permission[]> = {
  viewer: ["users:read", "analytics:read"],
  editor: ["users:read", "users:write", "analytics:read", "settings:read"],
  admin: ["users:read", "users:write", "users:delete", "analytics:read", "settings:read", "settings:write"],
};

export function hasPermission(role: Role, permission: Permission): boolean {
  return rolePermissions[role]?.includes(permission) ?? false;
}

// Server-side check in API routes
import { auth } from "@/lib/auth";

export async function GET() {
  const session = await auth();
  if (!session) return new Response("Unauthorized", { status: 401 });
  if (!hasPermission(session.user.role as Role, "users:read")) {
    return new Response("Forbidden", { status: 403 });
  }
  // ... fetch data
}

// Server-side check in Server Components
export default async function AdminPage() {
  const session = await auth();
  if (!session || session.user.role !== "admin") {
    redirect("/dashboard");
  }
  return <div>Admin content</div>;
}
```

## Password Reset Flow

1. User submits email on `/forgot-password`
2. Server generates a time-limited token (expires in 1 hour), stores its hash in the database
3. Server sends an email with a link: `/reset-password?token=<token>`
4. User clicks the link, enters a new password
5. Server verifies the token hash and expiration, updates the password, invalidates the token

```tsx
// Server action for password reset request
"use server";

import crypto from "crypto";

export async function requestPasswordReset(email: string) {
  const user = await db.users.findByEmail(email);
  if (!user) return; // Do not reveal whether the email exists

  const token = crypto.randomBytes(32).toString("hex");
  const hashedToken = crypto.createHash("sha256").update(token).digest("hex");
  const expires = new Date(Date.now() + 3600000); // 1 hour

  await db.passwordResetTokens.create({ userId: user.id, token: hashedToken, expires });
  await sendEmail({ to: email, subject: "Reset your password", link: `${process.env.NEXTAUTH_URL}/reset-password?token=${token}` });
}
```

## Security Checklist

- Set `NEXTAUTH_SECRET` to a strong random value (at least 32 bytes)
- Use HTTPS in production (NEXTAUTH_URL must be https://)
- Set `secure: true` on cookies in production
- Enable CSRF protection (built into NextAuth.js)
- Hash passwords with bcrypt (cost factor 12+)
- Rate-limit login attempts at the API layer
- Store OAuth client secrets in environment variables, never in code
- Validate and sanitize all inputs with zod before database operations
- Use HttpOnly cookies for session tokens (NextAuth.js default)
- Implement refresh token rotation for long-lived sessions
