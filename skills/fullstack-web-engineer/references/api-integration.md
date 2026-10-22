# API Integration

## Type-Safe API Client with Fetch

```tsx
// lib/api-client.ts

class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public data: unknown,
  ) {
    super(`API Error ${status}: ${statusText}`);
    this.name = "ApiError";
  }
}

class ApiClient {
  private baseUrl: string;
  private getToken: () => Promise<string | null>;

  constructor(baseUrl: string, getToken: () => Promise<string | null>) {
    this.baseUrl = baseUrl;
    this.getToken = getToken;
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const token = await this.getToken();

    const headers: HeadersInit = {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    };

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const data = await response.json().catch(() => null);
      throw new ApiError(response.status, response.statusText, data);
    }

    if (response.status === 204) return undefined as T;
    return response.json() as Promise<T>;
  }

  get<T>(path: string) {
    return this.request<T>(path);
  }

  post<T>(path: string, body: unknown) {
    return this.request<T>(path, { method: "POST", body: JSON.stringify(body) });
  }

  put<T>(path: string, body: unknown) {
    return this.request<T>(path, { method: "PUT", body: JSON.stringify(body) });
  }

  patch<T>(path: string, body: unknown) {
    return this.request<T>(path, { method: "PATCH", body: JSON.stringify(body) });
  }

  delete<T>(path: string) {
    return this.request<T>(path, { method: "DELETE" });
  }
}

// Initialize with your backend URL and token provider
export const apiClient = new ApiClient(
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080/api",
  async () => {
    if (typeof window === "undefined") return null;
    const { getSession } = await import("next-auth/react");
    const session = await getSession();
    return (session as any)?.accessToken ?? null;
  }
);
```

## Axios Setup with Interceptors

```tsx
// lib/axios-client.ts
import axios, { type AxiosError, type InternalAxiosRequestConfig } from "axios";

export const axiosClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 15000,
  headers: { "Content-Type": "application/json" },
});

// Request interceptor — attach auth token
axiosClient.interceptors.request.use(async (config: InternalAxiosRequestConfig) => {
  if (typeof window !== "undefined") {
    const { getSession } = await import("next-auth/react");
    const session = await getSession();
    if (session?.accessToken) {
      config.headers.Authorization = `Bearer ${session.accessToken}`;
    }
  }
  return config;
});

// Response interceptor — handle errors globally
axiosClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Token expired — redirect to login
      if (typeof window !== "undefined") {
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);
```

## TanStack Query — Data Fetching Patterns

### Query hooks per resource

```tsx
// hooks/use-users.ts
import { useQuery, useMutation, useQueryClient, useInfiniteQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// Paginated query
export function useUsers(page: number, search: string) {
  return useQuery({
    queryKey: ["users", { page, search }],
    queryFn: () => apiClient.get<PaginatedResponse<User>>(
      `/users?page=${page}&pageSize=20&search=${encodeURIComponent(search)}`
    ),
    placeholderData: (prev) => prev,
  });
}

// Single resource
export function useUser(id: string) {
  return useQuery({
    queryKey: ["users", id],
    queryFn: () => apiClient.get<User>(`/users/${id}`),
    enabled: !!id,
  });
}

// Mutation with cache invalidation
export function useCreateUser() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateUserInput) => apiClient.post<User>("/users", data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["users"] }); },
  });
}

// Mutation with optimistic update
export function useDeleteUser() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/users/${id}`),
    onMutate: async (id) => {
      await qc.cancelQueries({ queryKey: ["users"] });
      const snapshot = qc.getQueriesData<PaginatedResponse<User>>({ queryKey: ["users"] });
      qc.setQueriesData<PaginatedResponse<User>>({ queryKey: ["users"] }, (old) =>
        old ? { ...old, items: old.items.filter((u) => u.id !== id), total: old.total - 1 } : old
      );
      return { snapshot };
    },
    onError: (_err, _id, ctx) => {
      ctx?.snapshot.forEach(([key, data]) => qc.setQueryData(key, data));
    },
    onSettled: () => { qc.invalidateQueries({ queryKey: ["users"] }); },
  });
}
```

### Infinite query for endless scrolling

```tsx
export function useInfiniteUsers(search: string) {
  return useInfiniteQuery({
    queryKey: ["users", "infinite", search],
    queryFn: ({ pageParam }) =>
      apiClient.get<PaginatedResponse<User>>(`/users?page=${pageParam}&pageSize=20&search=${encodeURIComponent(search)}`),
    initialPageParam: 1,
    getNextPageParam: (lastPage) =>
      lastPage.page < lastPage.totalPages ? lastPage.page + 1 : undefined,
  });
}
```

## Error Handling Patterns

```tsx
import { ApiError } from "@/lib/api-client";

// In a component using a mutation
const createUser = useCreateUser();

async function handleSubmit(data: CreateUserInput) {
  try {
    await createUser.mutateAsync(data);
    toast.success("User created successfully");
  } catch (err) {
    if (err instanceof ApiError) {
      if (err.status === 409) {
        toast.error("A user with this email already exists");
      } else if (err.status === 422) {
        toast.error("Invalid data. Please check your inputs.");
      } else {
        toast.error(`Error: ${err.message}`);
      }
    } else {
      toast.error("An unexpected error occurred");
    }
  }
}

// Global error handler for TanStack Query
const queryClient = new QueryClient({
  defaultOptions: {
    mutations: {
      onError: (error) => {
        if (error instanceof ApiError && error.status >= 500) {
          toast.error("Server error. Please try again later.");
        }
      },
    },
  },
});
```

## Real-Time Updates — WebSocket

```tsx
// hooks/use-websocket.ts
"use client";

import { useEffect, useRef, useCallback, useState } from "react";

interface UseWebSocketOptions {
  url: string;
  onMessage: (data: unknown) => void;
  enabled?: boolean;
  reconnectInterval?: number;
}

export function useWebSocket({ url, onMessage, enabled = true, reconnectInterval = 5000 }: UseWebSocketOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const [status, setStatus] = useState<"connecting" | "open" | "closed">("closed");

  const connect = useCallback(() => {
    if (!enabled) return;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => setStatus("open");
    ws.onmessage = (event) => { onMessage(JSON.parse(event.data)); };
    ws.onclose = () => {
      setStatus("closed");
      setTimeout(connect, reconnectInterval);
    };
    ws.onerror = () => ws.close();
  }, [url, enabled, onMessage, reconnectInterval]);

  useEffect(() => {
    connect();
    return () => { wsRef.current?.close(); };
  }, [connect]);

  const send = useCallback((data: unknown) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data));
    }
  }, []);

  return { status, send };
}
```

## Real-Time Updates — Server-Sent Events

```tsx
// hooks/use-sse.ts
export function useSSE<T>(url: string, onEvent: (data: T) => void, enabled = true) {
  useEffect(() => {
    if (!enabled) return;

    const eventSource = new EventSource(url);
    eventSource.onmessage = (event) => { onEvent(JSON.parse(event.data) as T); };
    eventSource.onerror = () => { eventSource.close(); };

    return () => eventSource.close();
  }, [url, onEvent, enabled]);
}

// Usage: live dashboard updates
function LiveDashboard() {
  const qc = useQueryClient();

  useSSE<{ type: string; payload: unknown }>("/api/events", (event) => {
    if (event.type === "user.created") {
      qc.invalidateQueries({ queryKey: ["users"] });
      qc.invalidateQueries({ queryKey: ["stats"] });
    }
  });

  return <Dashboard />;
}
```

## File Upload with Progress

```tsx
export function useFileUpload() {
  const [progress, setProgress] = useState(0);
  const [uploading, setUploading] = useState(false);

  const upload = useCallback(async (file: File, endpoint: string): Promise<{ url: string }> => {
    setUploading(true);
    setProgress(0);

    const formData = new FormData();
    formData.append("file", file);

    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("POST", endpoint);

      xhr.upload.onprogress = (event) => {
        if (event.lengthComputable) {
          setProgress(Math.round((event.loaded / event.total) * 100));
        }
      };

      xhr.onload = () => {
        setUploading(false);
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(JSON.parse(xhr.responseText));
        } else {
          reject(new Error(`Upload failed: ${xhr.status}`));
        }
      };

      xhr.onerror = () => { setUploading(false); reject(new Error("Upload failed")); };
      xhr.send(formData);
    });
  }, []);

  return { upload, progress, uploading };
}
```
