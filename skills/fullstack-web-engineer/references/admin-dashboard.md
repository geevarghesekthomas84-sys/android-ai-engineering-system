# Admin Dashboard Design

## Sidebar Navigation Layout

```tsx
// components/layout/dashboard-layout.tsx
"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import { Menu, X, Home, Users, Settings, BarChart3, FileText, LogOut } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

const navItems = [
  { href: "/dashboard", label: "Dashboard", icon: Home },
  { href: "/dashboard/users", label: "Users", icon: Users },
  { href: "/dashboard/analytics", label: "Analytics", icon: BarChart3 },
  { href: "/dashboard/reports", label: "Reports", icon: FileText },
  { href: "/dashboard/settings", label: "Settings", icon: Settings },
];

export function DashboardLayout({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const pathname = usePathname();

  return (
    <div className="flex h-screen overflow-hidden">
      {/* Mobile overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 bg-black/50 lg:hidden" onClick={() => setMobileOpen(false)} />
      )}

      {/* Sidebar */}
      <aside className={cn(
        "fixed inset-y-0 left-0 z-50 flex flex-col border-r bg-card transition-all duration-300 lg:relative",
        collapsed ? "w-16" : "w-64",
        mobileOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"
      )}>
        <div className="flex h-16 items-center justify-between border-b px-4">
          {!collapsed && <span className="text-lg font-bold">Admin</span>}
          <button onClick={() => setCollapsed(!collapsed)} className="hidden rounded-md p-1.5 hover:bg-accent lg:block">
            <Menu className="h-5 w-5" />
          </button>
          <button onClick={() => setMobileOpen(false)} className="rounded-md p-1.5 hover:bg-accent lg:hidden">
            <X className="h-5 w-5" />
          </button>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto p-2">
          {navItems.map((item) => (
            <Link key={item.href} href={item.href} className={cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
              pathname === item.href
                ? "bg-primary text-primary-foreground"
                : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
            )}>
              <item.icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          ))}
        </nav>
      </aside>

      {/* Main content */}
      <div className="flex flex-1 flex-col overflow-hidden">
        <header className="flex h-16 items-center gap-4 border-b px-6">
          <button onClick={() => setMobileOpen(true)} className="rounded-md p-1.5 hover:bg-accent lg:hidden">
            <Menu className="h-5 w-5" />
          </button>
          <h1 className="text-lg font-semibold">Dashboard</h1>
        </header>
        <main className="flex-1 overflow-y-auto p-6">{children}</main>
      </div>
    </div>
  );
}
```

## Data Tables with TanStack Table

```tsx
"use client";

import { useState } from "react";
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  flexRender,
  type ColumnDef,
  type SortingState,
  type ColumnFiltersState,
} from "@tanstack/react-table";
import { ArrowUpDown, ChevronLeft, ChevronRight } from "lucide-react";

interface DataTableProps<T> {
  columns: ColumnDef<T, unknown>[];
  data: T[];
  searchColumn?: string;
  pageSize?: number;
}

export function DataTable<T>({ columns, data, searchColumn, pageSize = 10 }: DataTableProps<T>) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([]);
  const [rowSelection, setRowSelection] = useState({});

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onRowSelectionChange: setRowSelection,
    state: { sorting, columnFilters, rowSelection },
    initialState: { pagination: { pageSize } },
  });

  return (
    <div className="space-y-4">
      {/* Search */}
      {searchColumn && (
        <input
          placeholder={`Filter by ${searchColumn}...`}
          value={(table.getColumn(searchColumn)?.getFilterValue() as string) ?? ""}
          onChange={(e) => table.getColumn(searchColumn)?.setFilterValue(e.target.value)}
          className="max-w-sm rounded-md border px-3 py-2 text-sm"
        />
      )}

      {/* Table */}
      <div className="overflow-x-auto rounded-md border">
        <table className="w-full text-sm">
          <thead className="border-b bg-muted/50">
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <th key={header.id} className="px-4 py-3 text-left font-medium text-muted-foreground">
                    {header.isPlaceholder ? null : (
                      <div className={cn("flex items-center gap-2", header.column.getCanSort() && "cursor-pointer select-none")}
                           onClick={header.column.getToggleSortingHandler()}>
                        {flexRender(header.column.columnDef.header, header.getContext())}
                        {header.column.getCanSort() && <ArrowUpDown className="h-4 w-4" />}
                      </div>
                    )}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row) => (
              <tr key={row.id} className="border-b transition-colors hover:bg-muted/50">
                {row.getVisibleCells().map((cell) => (
                  <td key={cell.id} className="px-4 py-3">
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          {table.getFilteredSelectedRowModel().rows.length} of {table.getFilteredRowModel().rows.length} row(s) selected
        </p>
        <div className="flex items-center gap-2">
          <button onClick={() => table.previousPage()} disabled={!table.getCanPreviousPage()}
                  className="rounded-md border p-2 disabled:opacity-50">
            <ChevronLeft className="h-4 w-4" />
          </button>
          <span className="text-sm">Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}</span>
          <button onClick={() => table.nextPage()} disabled={!table.getCanNextPage()}
                  className="rounded-md border p-2 disabled:opacity-50">
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

// Column definition example
const userColumns: ColumnDef<User>[] = [
  {
    id: "select",
    header: ({ table }) => (
      <input type="checkbox" checked={table.getIsAllPageRowsSelected()}
             onChange={(e) => table.toggleAllPageRowsSelected(e.target.checked)} />
    ),
    cell: ({ row }) => (
      <input type="checkbox" checked={row.getIsSelected()} onChange={(e) => row.toggleSelected(e.target.checked)} />
    ),
    enableSorting: false,
  },
  { accessorKey: "name", header: "Name", cell: ({ row }) => <span className="font-medium">{row.getValue("name")}</span> },
  { accessorKey: "email", header: "Email" },
  { accessorKey: "role", header: "Role", cell: ({ row }) => (
    <span className="rounded-full bg-primary/10 px-2 py-1 text-xs font-medium text-primary">{row.getValue("role")}</span>
  )},
  { accessorKey: "createdAt", header: "Created", cell: ({ row }) => new Date(row.getValue("createdAt")).toLocaleDateString() },
];
```

## Charts with Recharts

```tsx
"use client";

import { LineChart, Line, BarChart, Bar, PieChart, Pie, AreaChart, Area,
         XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Cell } from "recharts";

const CHART_COLORS = ["hsl(221, 83%, 53%)", "hsl(160, 60%, 45%)", "hsl(30, 90%, 55%)", "hsl(280, 65%, 60%)", "hsl(0, 70%, 55%)"];

// Line chart — trends over time
export function RevenueChart({ data }: { data: { month: string; revenue: number; target: number }[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
        <XAxis dataKey="month" className="text-xs" />
        <YAxis className="text-xs" />
        <Tooltip contentStyle={{ borderRadius: "8px", border: "1px solid hsl(var(--border))" }} />
        <Legend />
        <Line type="monotone" dataKey="revenue" stroke={CHART_COLORS[0]} strokeWidth={2} dot={{ r: 4 }} />
        <Line type="monotone" dataKey="target" stroke={CHART_COLORS[1]} strokeWidth={2} strokeDasharray="5 5" />
      </LineChart>
    </ResponsiveContainer>
  );
}

// Bar chart — comparisons
export function UsersByRoleChart({ data }: { data: { role: string; count: number }[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data}>
        <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
        <XAxis dataKey="role" className="text-xs" />
        <YAxis className="text-xs" />
        <Tooltip />
        <Bar dataKey="count" radius={[4, 4, 0, 0]}>
          {data.map((_, i) => (<Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
```

## Stat Cards with KPIs

```tsx
import { ArrowUp, ArrowDown, Users, DollarSign, Activity, ShoppingCart } from "lucide-react";

interface StatCardProps {
  title: string;
  value: string;
  change: number;        // percentage change
  icon: React.ElementType;
}

function StatCard({ title, value, change, icon: Icon }: StatCardProps) {
  const isPositive = change >= 0;
  return (
    <div className="rounded-lg border bg-card p-6">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium text-muted-foreground">{title}</p>
        <Icon className="h-5 w-5 text-muted-foreground" />
      </div>
      <p className="mt-2 text-3xl font-bold">{value}</p>
      <div className="mt-2 flex items-center gap-1 text-sm">
        {isPositive ? <ArrowUp className="h-4 w-4 text-green-500" /> : <ArrowDown className="h-4 w-4 text-red-500" />}
        <span className={isPositive ? "text-green-500" : "text-red-500"}>{Math.abs(change)}%</span>
        <span className="text-muted-foreground">from last month</span>
      </div>
    </div>
  );
}

// Usage in dashboard page
export function StatsOverview() {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <StatCard title="Total Users" value="12,345" change={12.5} icon={Users} />
      <StatCard title="Revenue" value="$45,231" change={8.2} icon={DollarSign} />
      <StatCard title="Active Now" value="573" change={-3.1} icon={Activity} />
      <StatCard title="Orders" value="1,234" change={19.0} icon={ShoppingCart} />
    </div>
  );
}
```

## Search with Debounce

```tsx
"use client";

import { useState } from "react";
import { Search } from "lucide-react";
import { useDebounce } from "@/hooks/use-debounce";
import { useUsers } from "@/hooks/use-users";

export function UserSearch() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);
  const { data, isLoading } = useUsers(1, debouncedQuery);

  return (
    <div className="relative">
      <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search users..."
        className="w-full rounded-md border bg-background py-2 pl-10 pr-4 text-sm"
      />
      {isLoading && <div className="absolute right-3 top-1/2 -translate-y-1/2"><Spinner /></div>}
    </div>
  );
}
```

## Export to CSV

```tsx
function exportToCSV<T extends Record<string, unknown>>(data: T[], filename: string) {
  if (data.length === 0) return;

  const headers = Object.keys(data[0]);
  const csvRows = [
    headers.join(","),
    ...data.map((row) =>
      headers.map((h) => {
        const val = String(row[h] ?? "");
        return val.includes(",") || val.includes('"') ? `"${val.replace(/"/g, '""')}"` : val;
      }).join(",")
    ),
  ];

  const blob = new Blob([csvRows.join("\n")], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${filename}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}
```

## Role-Based UI

```tsx
import { useSession } from "next-auth/react";

type Role = "admin" | "editor" | "viewer";

function hasPermission(userRole: Role, requiredRole: Role): boolean {
  const hierarchy: Record<Role, number> = { viewer: 0, editor: 1, admin: 2 };
  return hierarchy[userRole] >= hierarchy[requiredRole];
}

export function RoleGate({ children, requiredRole }: { children: React.ReactNode; requiredRole: Role }) {
  const { data: session } = useSession();
  if (!session || !hasPermission(session.user.role as Role, requiredRole)) return null;
  return <>{children}</>;
}

// Usage
<RoleGate requiredRole="admin">
  <button className="rounded bg-destructive px-3 py-1.5 text-sm text-white">Delete User</button>
</RoleGate>
```
