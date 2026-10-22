import { describe, it, expect, beforeAll } from '@jest/globals';

const BASE = process.env.API_BASE || 'http://localhost:3000';
const headers = { 'Content-Type': 'application/json' };

let token: string;
let userId: string;
let taskId: string;

async function api(method: string, path: string, body?: object, auth?: string) {
  const opts: RequestInit = { method, headers: { ...headers } as Record<string, string> };
  if (body) opts.body = JSON.stringify(body);
  if (auth) (opts.headers as Record<string, string>)['Authorization'] = `Bearer ${auth}`;
  return fetch(`${BASE}${path}`, opts);
}

async function json(res: Response): Promise<any> {
  return res.json();
}

describe('API Integration Tests', () => {
  const email = `integration-${Date.now()}@test.com`;

  it('registers a new user', async () => {
    const res = await api('POST', '/auth/register', { email, displayName: 'Tester', password: 'password123' });
    expect(res.status).toBe(201);
    const data = await json(res);
    expect(data.token).toBeDefined();
    expect(data.user.email).toBe(email);
    token = data.token;
    userId = data.user.id;
  });

  it('rejects duplicate registration', async () => {
    const res = await api('POST', '/auth/register', { email, displayName: 'Dup', password: 'password123' });
    expect(res.status).toBe(409);
  });

  it('logs in with valid credentials', async () => {
    const res = await api('POST', '/auth/login', { email, password: 'password123' });
    expect(res.status).toBe(201);
    const data = await json(res);
    expect(data.token).toBeDefined();
    token = data.token;
  });

  it('rejects invalid credentials', async () => {
    const res = await api('POST', '/auth/login', { email, password: 'wrong' });
    expect(res.status).toBe(401);
  });

  it('rejects access without token', async () => {
    const res = await api('GET', '/tasks');
    expect(res.status).toBe(401);
  });

  it('creates a task', async () => {
    const res = await api('POST', '/tasks', { title: 'Integration test task', description: 'Auto-created', priority: 1 }, token);
    expect(res.status).toBe(201);
    const data = await json(res);
    expect(data.title).toBe('Integration test task');
    expect(data.status).toBe('pending');
    taskId = data.id;
  });

  it('lists tasks', async () => {
    const res = await api('GET', '/tasks', undefined, token);
    expect(res.status).toBe(200);
    const data = await json(res);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
    expect(data.pagination).toBeDefined();
  });

  it('gets a single task', async () => {
    const res = await api('GET', `/tasks/${taskId}`, undefined, token);
    expect(res.status).toBe(200);
    const data = await json(res);
    expect(data.id).toBe(taskId);
  });

  it('updates a task', async () => {
    const res = await api('PATCH', `/tasks/${taskId}`, { status: 'completed', priority: 3 }, token);
    expect(res.status).toBe(200);
    const data = await json(res);
    expect(data.status).toBe('completed');
    expect(data.priority).toBe(3);
  });

  it('deletes a task', async () => {
    const res = await api('DELETE', `/tasks/${taskId}`, undefined, token);
    expect(res.status).toBe(200);
  });

  it('returns 404 for deleted task', async () => {
    const res = await api('GET', `/tasks/${taskId}`, undefined, token);
    expect(res.status).toBe(404);
  });

  it('lists users', async () => {
    const res = await api('GET', '/users', undefined, token);
    expect(res.status).toBe(200);
    const data = await json(res);
    expect(data.data.length).toBeGreaterThanOrEqual(1);
  });

  it('rejects invalid registration input', async () => {
    const res = await api('POST', '/auth/register', { email: 'not-an-email' });
    expect(res.status).toBe(400);
  });
});
