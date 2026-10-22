# Tailwind CSS Design System

## Utility Classes Overview

Tailwind uses utility classes that map directly to CSS properties. Combine them to build any design without writing custom CSS.

```html
<!-- Layout -->
<div class="flex items-center justify-between gap-4 p-6">
<!-- Sizing -->
<div class="h-12 w-full max-w-md min-h-screen">
<!-- Typography -->
<h1 class="text-2xl font-bold tracking-tight text-gray-900">
<p class="text-sm text-muted-foreground leading-relaxed">
<!-- Borders and Shadows -->
<div class="rounded-lg border border-gray-200 shadow-sm">
<!-- Transitions -->
<button class="transition-colors duration-200 hover:bg-gray-100">
```

## Responsive Design

Tailwind uses mobile-first breakpoints. Unprefixed utilities apply at all sizes; prefixed utilities apply at that breakpoint and above.

| Prefix | Min Width | Typical Target         |
|--------|-----------|------------------------|
| (none) | 0px       | Mobile (default)       |
| `sm:`  | 640px     | Large phones           |
| `md:`  | 768px     | Tablets                |
| `lg:`  | 1024px    | Laptops                |
| `xl:`  | 1280px    | Desktops               |
| `2xl:` | 1536px    | Large desktops         |

```html
<!-- Stack on mobile, row on desktop -->
<div class="flex flex-col gap-4 md:flex-row md:gap-6">
  <!-- Full width on mobile, sidebar on desktop -->
  <aside class="w-full md:w-64 lg:w-72">
    <nav>Sidebar</nav>
  </aside>
  <!-- Content fills remaining space -->
  <main class="flex-1">Content</main>
</div>

<!-- Responsive grid: 1 col mobile, 2 cols tablet, 3 cols desktop -->
<div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
  <div class="rounded-lg border p-4">Card</div>
</div>

<!-- Hide on mobile, show on desktop -->
<span class="hidden lg:inline">Desktop only text</span>
<span class="lg:hidden">Mobile only text</span>
```

## Dark Mode

Use the `class` strategy so users can toggle dark mode independently of their system preference.

```tsx
// tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  // ...
};
```

```html
<!-- Apply dark: variants for dark mode styles -->
<div class="bg-white text-gray-900 dark:bg-gray-950 dark:text-gray-100">
  <div class="border-gray-200 dark:border-gray-800">
    <h2 class="text-gray-900 dark:text-white">Title</h2>
    <p class="text-gray-600 dark:text-gray-400">Description</p>
  </div>
</div>
```

Toggle implementation:
```tsx
"use client";

import { useTheme } from "next-themes";
import { Moon, Sun } from "lucide-react";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <button
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
      className="rounded-md p-2 hover:bg-gray-100 dark:hover:bg-gray-800"
    >
      <Sun className="h-5 w-5 rotate-0 scale-100 transition-transform dark:-rotate-90 dark:scale-0" />
      <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-transform dark:rotate-0 dark:scale-100" />
      <span className="sr-only">Toggle theme</span>
    </button>
  );
}
```

## Custom Theme Configuration

```tsx
// tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Brand colors using CSS custom properties for runtime switching
        brand: {
          50: "hsl(var(--brand-50))",
          100: "hsl(var(--brand-100))",
          500: "hsl(var(--brand-500))",
          600: "hsl(var(--brand-600))",
          700: "hsl(var(--brand-700))",
          900: "hsl(var(--brand-900))",
        },
        // shadcn/ui semantic tokens
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: { DEFAULT: "hsl(var(--card))", foreground: "hsl(var(--card-foreground))" },
        primary: { DEFAULT: "hsl(var(--primary))", foreground: "hsl(var(--primary-foreground))" },
        secondary: { DEFAULT: "hsl(var(--secondary))", foreground: "hsl(var(--secondary-foreground))" },
        muted: { DEFAULT: "hsl(var(--muted))", foreground: "hsl(var(--muted-foreground))" },
        accent: { DEFAULT: "hsl(var(--accent))", foreground: "hsl(var(--accent-foreground))" },
        destructive: { DEFAULT: "hsl(var(--destructive))", foreground: "hsl(var(--destructive-foreground))" },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
      },
      fontFamily: {
        sans: ["var(--font-geist-sans)", "system-ui", "sans-serif"],
        mono: ["var(--font-geist-mono)", "monospace"],
      },
      spacing: {
        "sidebar": "16rem",       // 256px sidebar width
        "sidebar-sm": "4rem",     // 64px collapsed sidebar
        "header": "4rem",         // 64px header height
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "fade-in": { from: { opacity: "0" }, to: { opacity: "1" } },
        "slide-in-right": { from: { transform: "translateX(100%)" }, to: { transform: "translateX(0)" } },
      },
      animation: {
        "fade-in": "fade-in 0.2s ease-out",
        "slide-in-right": "slide-in-right 0.3s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

## CSS Custom Properties for Theming

```css
/* globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --primary: 221.2 83.2% 53.3%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 221.2 83.2% 53.3%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --primary: 217.2 91.2% 59.8%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 224.3 76.3% 48%;
  }
}
```

## Component Patterns

### Card
```html
<div class="rounded-lg border bg-card p-6 text-card-foreground shadow-sm">
  <h3 class="text-lg font-semibold">Card Title</h3>
  <p class="mt-2 text-sm text-muted-foreground">Card description text.</p>
  <div class="mt-4 flex gap-2">
    <button class="rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90">Action</button>
    <button class="rounded-md border px-4 py-2 text-sm font-medium hover:bg-accent">Cancel</button>
  </div>
</div>
```

### Sidebar Navigation
```html
<aside class="flex h-screen w-64 flex-col border-r bg-card">
  <div class="flex h-16 items-center gap-2 border-b px-6">
    <span class="text-lg font-bold">AppName</span>
  </div>
  <nav class="flex-1 space-y-1 overflow-y-auto p-3">
    <a href="/dashboard" class="flex items-center gap-3 rounded-md bg-accent px-3 py-2 text-sm font-medium text-accent-foreground">
      <HomeIcon class="h-4 w-4" /> Dashboard
    </a>
    <a href="/users" class="flex items-center gap-3 rounded-md px-3 py-2 text-sm text-muted-foreground hover:bg-accent hover:text-accent-foreground">
      <UsersIcon class="h-4 w-4" /> Users
    </a>
  </nav>
  <div class="border-t p-3">
    <div class="flex items-center gap-3 px-3 py-2">
      <div class="h-8 w-8 rounded-full bg-primary/10" />
      <div class="text-sm">
        <p class="font-medium">John Doe</p>
        <p class="text-xs text-muted-foreground">Admin</p>
      </div>
    </div>
  </div>
</aside>
```

### Modal / Dialog
```html
<div class="fixed inset-0 z-50 flex items-center justify-center">
  <div class="fixed inset-0 bg-black/50" aria-hidden="true" />
  <div class="relative z-10 w-full max-w-md rounded-lg bg-card p-6 shadow-lg">
    <h2 class="text-lg font-semibold">Confirm Action</h2>
    <p class="mt-2 text-sm text-muted-foreground">Are you sure you want to proceed?</p>
    <div class="mt-6 flex justify-end gap-2">
      <button class="rounded-md border px-4 py-2 text-sm hover:bg-accent">Cancel</button>
      <button class="rounded-md bg-destructive px-4 py-2 text-sm text-destructive-foreground hover:bg-destructive/90">Delete</button>
    </div>
  </div>
</div>
```

## shadcn/ui Setup

```bash
npx shadcn@latest init
# Select: New York style, Zinc base color, CSS variables: yes

# Add individual components as needed
npx shadcn@latest add button input card dialog table dropdown-menu toast
npx shadcn@latest add form select textarea badge avatar separator
npx shadcn@latest add sheet command popover calendar
```

Components are installed directly into `src/components/ui/` as editable source files — not a node_modules dependency. Customize them freely.

## Accessibility Utilities

```html
<!-- Screen reader only text -->
<span class="sr-only">Close dialog</span>

<!-- Focus styles -->
<button class="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2">

<!-- Skip to main content link -->
<a href="#main" class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-background focus:px-4 focus:py-2">
  Skip to main content
</a>

<!-- Reduced motion preference -->
<div class="transition-transform motion-reduce:transition-none">

<!-- Proper ARIA attributes (add alongside Tailwind classes) -->
<button aria-expanded="false" aria-controls="menu" class="...">
<nav aria-label="Main navigation" class="...">
<div role="alert" class="rounded-md bg-destructive/10 p-4 text-destructive">
```
