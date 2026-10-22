# Web Deployment

## Vercel Deployment

Vercel is the default deployment platform for Next.js. It handles builds, serverless functions, edge middleware, and CDN distribution automatically.

### Setup

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy from the project root (follow the prompts on first run)
vercel

# Deploy to production
vercel --prod
```

### vercel.json Configuration

```json
{
  "framework": "nextjs",
  "regions": ["iad1"],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "no-store" },
        { "key": "Access-Control-Allow-Origin", "value": "https://yourdomain.com" }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    }
  ],
  "redirects": [
    { "source": "/old-path", "destination": "/new-path", "permanent": true }
  ],
  "rewrites": [
    { "source": "/api/proxy/:path*", "destination": "https://backend.example.com/:path*" }
  ]
}
```

### Environment Variables

Set them in the Vercel dashboard (Settings > Environment Variables) or via CLI:

```bash
vercel env add DATABASE_URL production
vercel env add NEXTAUTH_SECRET production preview
vercel env add NEXT_PUBLIC_API_URL production preview development
```

Variable scopes:
- **Production** — applied only to production deployments
- **Preview** — applied to all branch/PR preview deployments
- **Development** — available when running `vercel dev` locally

### Preview Deployments

Every push to a non-production branch generates a unique preview URL. Use this for:
- QA review before merging
- Sharing work-in-progress with stakeholders
- Testing against staging APIs

## Docker Deployment

### Dockerfile for Next.js (multi-stage build)

```dockerfile
# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

# Stage 2: Build the application
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Stage 3: Production runtime
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

Enable standalone output in next.config.ts:

```tsx
// next.config.ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
};

export default nextConfig;
```

### docker-compose for Full Stack

```yaml
# docker-compose.yml
version: "3.9"

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
      - NEXTAUTH_URL=http://localhost:3000
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - NEXT_PUBLIC_API_URL=http://localhost:8080/api
    depends_on:
      db:
        condition: service_healthy
      api:
        condition: service_started

  api:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

```bash
# Build and start all services
docker compose up --build -d

# View logs
docker compose logs -f web

# Stop and remove
docker compose down
```

## Static Export

For simple sites that do not need server-side rendering or API routes:

```tsx
// next.config.ts
const nextConfig: NextConfig = {
  output: "export",       // Generates static HTML/CSS/JS in the out/ directory
  images: {
    unoptimized: true,    // Required: Image Optimization needs a server
  },
};
```

```bash
npm run build            # Generates out/ directory
# Deploy out/ to any static host: S3, Cloudflare Pages, GitHub Pages, Netlify
```

Limitations of static export: no server components fetching at request time, no API routes, no middleware, no ISR. Use only for fully static sites.

## Performance Optimization

### next/image — automatic image optimization

```tsx
import Image from "next/image";

<Image
  src="/hero.jpg"
  alt="Hero banner"
  width={1200}
  height={600}
  priority            // Load above-the-fold images eagerly
  className="rounded-lg object-cover"
/>

// For remote images, configure allowed domains
// next.config.ts
const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "images.example.com" },
      { protocol: "https", hostname: "avatars.githubusercontent.com" },
    ],
  },
};
```

### next/font — zero-layout-shift fonts

```tsx
// app/layout.tsx
import { Inter } from "next/font/google";

const inter = Inter({ subsets: ["latin"], variable: "--font-sans" });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans">{children}</body>
    </html>
  );
}
```

### Bundle Analysis

```bash
npm install -D @next/bundle-analyzer

# next.config.ts
import bundleAnalyzer from "@next/bundle-analyzer";

const withBundleAnalyzer = bundleAnalyzer({ enabled: process.env.ANALYZE === "true" });

export default withBundleAnalyzer(nextConfig);

# Run analysis
ANALYZE=true npm run build
```

Common optimizations:
- Dynamic imports for heavy components: `const Chart = dynamic(() => import("./chart"), { ssr: false })`
- Tree-shake large libraries: import only what you need (`import { format } from "date-fns"` not `import * as dateFns`)
- Use `React.lazy` + `Suspense` for code splitting within client components
- Avoid importing server-only code in client components

## Monitoring

### Vercel Analytics

```bash
npm install @vercel/analytics @vercel/speed-insights
```

```tsx
// app/layout.tsx
import { Analytics } from "@vercel/analytics/react";
import { SpeedInsights } from "@vercel/speed-insights/next";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
```

### Custom Error Logging

```tsx
// lib/logger.ts
export function logError(error: unknown, context?: Record<string, unknown>) {
  const payload = {
    message: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : undefined,
    timestamp: new Date().toISOString(),
    ...context,
  };

  // Send to your logging service
  if (process.env.NODE_ENV === "production") {
    fetch("/api/log", { method: "POST", body: JSON.stringify(payload), headers: { "Content-Type": "application/json" } }).catch(() => {});
  } else {
    console.error("[Error]", payload);
  }
}
```

## SSL/TLS and Custom Domains

- **Vercel**: Add the domain in Settings > Domains. Vercel issues and renews SSL certificates automatically via Let's Encrypt. Point your DNS CNAME to `cname.vercel-dns.com`.
- **Docker**: Place a reverse proxy (Caddy, Nginx, or Traefik) in front of the Next.js container. Caddy handles automatic HTTPS with zero configuration:

```
# Caddyfile
yourdomain.com {
    reverse_proxy web:3000
}
```

## Deployment Checklist

1. All environment variables set for the target environment
2. `npm run build` succeeds with no errors
3. TypeScript strict mode passes (`npx tsc --noEmit`)
4. ESLint passes (`npm run lint`)
5. All tests pass
6. Lighthouse score checked (aim for 90+ on Performance, Accessibility, Best Practices)
7. Security headers configured (X-Frame-Options, CSP, HSTS)
8. Error pages (/404, /500) look correct
9. SEO metadata present on all public pages (title, description, og:image)
10. Analytics and monitoring wired up
