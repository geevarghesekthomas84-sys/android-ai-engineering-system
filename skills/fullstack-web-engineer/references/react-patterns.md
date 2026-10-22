# React Patterns with TypeScript

## Functional Components with Proper Typing

```tsx
// Props interface — always define explicitly
interface UserCardProps {
  user: User;
  onEdit: (id: string) => void;
  onDelete: (id: string) => Promise<void>;
  variant?: "compact" | "full"; // Optional with union type
  className?: string;
}

export function UserCard({ user, onEdit, onDelete, variant = "full", className }: UserCardProps) {
  return (
    <div className={cn("rounded-lg border p-4", className)}>
      <h3>{user.name}</h3>
      {variant === "full" && <p>{user.email}</p>}
      <button onClick={() => onEdit(user.id)}>Edit</button>
    </div>
  );
}

// Children prop
interface LayoutProps {
  children: React.ReactNode;
  title: string;
}

// Generic component
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
  keyExtractor: (item: T) => string;
}

export function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul>
      {items.map((item) => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}
```

## Hooks

### useState — typed state

```tsx
const [user, setUser] = useState<User | null>(null);
const [items, setItems] = useState<string[]>([]);
const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");
```

### useEffect — side effects with cleanup

```tsx
useEffect(() => {
  const controller = new AbortController();

  async function fetchData() {
    try {
      const res = await fetch(`/api/users/${id}`, { signal: controller.signal });
      const data = await res.json();
      setUser(data);
    } catch (err) {
      if (err instanceof DOMException && err.name === "AbortError") return;
      setError(err);
    }
  }

  fetchData();
  return () => controller.abort();
}, [id]);
```

### useMemo and useCallback — memoization

```tsx
// Expensive computation
const sortedUsers = useMemo(
  () => users.slice().sort((a, b) => a.name.localeCompare(b.name)),
  [users]
);

// Stable callback reference for child components
const handleDelete = useCallback(async (id: string) => {
  await deleteUser(id);
  refetch();
}, [refetch]);
```

### useRef — DOM references and mutable values

```tsx
const inputRef = useRef<HTMLInputElement>(null);
const intervalRef = useRef<ReturnType<typeof setInterval>>(null);

function focusInput() {
  inputRef.current?.focus();
}
```

### useContext — dependency injection

```tsx
interface ThemeContextType {
  theme: "light" | "dark";
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType | null>(null);

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) throw new Error("useTheme must be used within ThemeProvider");
  return context;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const toggleTheme = useCallback(() => {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  }, []);

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
```

## Custom Hooks

```tsx
// useDebounce — delay a value update
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}

// useLocalStorage — persist state to localStorage
export function useLocalStorage<T>(key: string, initialValue: T) {
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === "undefined") return initialValue;
    try {
      const item = window.localStorage.getItem(key);
      return item ? (JSON.parse(item) as T) : initialValue;
    } catch {
      return initialValue;
    }
  });

  const setValue = useCallback(
    (value: T | ((val: T) => T)) => {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    },
    [key, storedValue]
  );

  return [storedValue, setValue] as const;
}

// useMediaQuery — responsive hooks
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);

    const listener = (event: MediaQueryListEvent) => setMatches(event.matches);
    media.addEventListener("change", listener);
    return () => media.removeEventListener("change", listener);
  }, [query]);

  return matches;
}
```

## TanStack Query (React Query)

### Provider Setup

```tsx
// providers/query-provider.tsx
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { useState } from "react";

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,       // Data fresh for 60 seconds
            gcTime: 5 * 60 * 1000,      // Cache kept for 5 minutes
            retry: 1,
            refetchOnWindowFocus: false,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

### useQuery — data fetching

```tsx
import { useQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export function useUsers(page: number, search: string) {
  return useQuery({
    queryKey: ["users", { page, search }],
    queryFn: () => apiClient.get<PaginatedResponse<User>>(`/users?page=${page}&search=${search}`),
    placeholderData: (previousData) => previousData, // Keep old data while fetching new
  });
}

// In a component
function UsersPage() {
  const { data, isLoading, isError, error } = useUsers(1, "");

  if (isLoading) return <UserTableSkeleton />;
  if (isError) return <ErrorMessage error={error} />;

  return <UserTable users={data.items} total={data.total} />;
}
```

### useMutation — creating, updating, deleting

```tsx
import { useMutation, useQueryClient } from "@tanstack/react-query";

export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (newUser: CreateUserInput) => apiClient.post<User>("/users", newUser),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}

export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateUserInput }) =>
      apiClient.patch<User>(`/users/${id}`, data),
    // Optimistic update
    onMutate: async ({ id, data }) => {
      await queryClient.cancelQueries({ queryKey: ["users"] });
      const previous = queryClient.getQueryData<User[]>(["users"]);

      queryClient.setQueryData<User[]>(["users"], (old) =>
        old?.map((user) => (user.id === id ? { ...user, ...data } : user))
      );

      return { previous };
    },
    onError: (_err, _vars, context) => {
      queryClient.setQueryData(["users"], context?.previous);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}
```

## Form Handling — react-hook-form + zod

```tsx
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const userFormSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
  role: z.enum(["admin", "editor", "viewer"]),
  bio: z.string().max(500).optional(),
});

type UserFormValues = z.infer<typeof userFormSchema>;

export function UserForm({ onSubmit, defaultValues }: {
  onSubmit: (data: UserFormValues) => Promise<void>;
  defaultValues?: Partial<UserFormValues>;
}) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<UserFormValues>({
    resolver: zodResolver(userFormSchema),
    defaultValues: { role: "viewer", ...defaultValues },
  });

  const handleFormSubmit = async (data: UserFormValues) => {
    await onSubmit(data);
    reset();
  };

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} className="space-y-4">
      <div>
        <label htmlFor="name" className="text-sm font-medium">Name</label>
        <input id="name" {...register("name")} className="mt-1 block w-full rounded border px-3 py-2" />
        {errors.name && <p className="mt-1 text-sm text-red-500">{errors.name.message}</p>}
      </div>

      <div>
        <label htmlFor="email" className="text-sm font-medium">Email</label>
        <input id="email" type="email" {...register("email")} className="mt-1 block w-full rounded border px-3 py-2" />
        {errors.email && <p className="mt-1 text-sm text-red-500">{errors.email.message}</p>}
      </div>

      <div>
        <label htmlFor="role" className="text-sm font-medium">Role</label>
        <select id="role" {...register("role")} className="mt-1 block w-full rounded border px-3 py-2">
          <option value="viewer">Viewer</option>
          <option value="editor">Editor</option>
          <option value="admin">Admin</option>
        </select>
      </div>

      <button type="submit" disabled={isSubmitting} className="rounded bg-blue-600 px-4 py-2 text-white disabled:opacity-50">
        {isSubmitting ? "Saving..." : "Save"}
      </button>
    </form>
  );
}
```

## Error Boundaries

```tsx
"use client";

import { Component, type ReactNode } from "react";

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback: (error: Error, reset: () => void) => ReactNode;
}

interface ErrorBoundaryState {
  error: Error | null;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  resetErrorBoundary = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      return this.props.fallback(this.state.error, this.resetErrorBoundary);
    }
    return this.props.children;
  }
}
```

## Suspense and Lazy Loading

```tsx
import { Suspense, lazy } from "react";

const HeavyChart = lazy(() => import("@/components/features/heavy-chart"));

export function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<div className="h-64 animate-pulse rounded bg-gray-200" />}>
        <HeavyChart />
      </Suspense>
    </div>
  );
}
```

## Component Composition Patterns

```tsx
// Compound component pattern
interface TabsProps {
  children: React.ReactNode;
  defaultTab: string;
}

const TabsContext = createContext<{ activeTab: string; setActiveTab: (tab: string) => void } | null>(null);

export function Tabs({ children, defaultTab }: TabsProps) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return <TabsContext.Provider value={{ activeTab, setActiveTab }}>{children}</TabsContext.Provider>;
}

Tabs.List = function TabList({ children }: { children: React.ReactNode }) {
  return <div className="flex border-b">{children}</div>;
};

Tabs.Trigger = function TabTrigger({ value, children }: { value: string; children: React.ReactNode }) {
  const ctx = useContext(TabsContext)!;
  return (
    <button onClick={() => ctx.setActiveTab(value)} className={cn("px-4 py-2", ctx.activeTab === value && "border-b-2 border-blue-600")}>
      {children}
    </button>
  );
};

Tabs.Content = function TabContent({ value, children }: { value: string; children: React.ReactNode }) {
  const ctx = useContext(TabsContext)!;
  if (ctx.activeTab !== value) return null;
  return <div className="py-4">{children}</div>;
};

// Usage
<Tabs defaultTab="overview">
  <Tabs.List>
    <Tabs.Trigger value="overview">Overview</Tabs.Trigger>
    <Tabs.Trigger value="analytics">Analytics</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Content value="overview"><Overview /></Tabs.Content>
  <Tabs.Content value="analytics"><Analytics /></Tabs.Content>
</Tabs>
```
