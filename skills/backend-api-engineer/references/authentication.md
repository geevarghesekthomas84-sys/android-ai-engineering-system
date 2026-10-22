# Authentication & Authorization

## JWT Token Flow

### Token Pair: Access + Refresh

Access tokens are short-lived (15 minutes) and carry authorization claims. Refresh tokens are long-lived (7 days) and are used only to obtain new access tokens.

**Token payload (access token):**
```json
{
  "sub": "user-uuid",
  "roles": ["user"],
  "iat": 1700000000,
  "exp": 1700000900,
  "jti": "unique-token-id"
}
```

Keep JWT payloads minimal. Never include email, name, or other PII in the token — look it up from the database using the `sub` claim.

### NestJS JWT Implementation

```typescript
// auth.service.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuid } from 'uuid';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private config: ConfigService,
  ) {}

  async validateUser(email: string, password: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return user;
  }

  async login(user: { id: string; roles: string[] }) {
    const tokenId = uuid();
    const payload = { sub: user.id, roles: user.roles, jti: tokenId };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.config.get('jwt.secret'),
      expiresIn: this.config.get('jwt.accessExpiresIn'),
    });

    const refreshToken = this.jwtService.sign(
      { sub: user.id, jti: tokenId, type: 'refresh' },
      {
        secret: this.config.get('jwt.secret'),
        expiresIn: this.config.get('jwt.refreshExpiresIn'),
      },
    );

    // Store refresh token hash in DB for revocation support
    await this.usersService.storeRefreshToken(user.id, tokenId);

    return { accessToken, refreshToken, expiresIn: 900 };
  }

  async refresh(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret: this.config.get('jwt.secret'),
      });
      if (payload.type !== 'refresh') throw new Error();

      // Verify token hasn't been revoked
      const valid = await this.usersService.verifyRefreshToken(payload.sub, payload.jti);
      if (!valid) throw new Error();

      // Rotate: revoke old, issue new pair
      await this.usersService.revokeRefreshToken(payload.sub, payload.jti);
      const user = await this.usersService.findById(payload.sub);
      return this.login(user);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async logout(userId: string, tokenId: string) {
    await this.usersService.revokeRefreshToken(userId, tokenId);
  }
}
```

### JWT Strategy (Passport.js)

```typescript
// strategies/jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get('jwt.secret'),
    });
  }

  async validate(payload: { sub: string; roles: string[]; jti: string }) {
    if (!payload.sub) throw new UnauthorizedException();
    return { userId: payload.sub, roles: payload.roles, tokenId: payload.jti };
  }
}
```

### FastAPI JWT Implementation

```python
# utils/security.py
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(user_id: str, roles: list[str], jti: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_access_expire_minutes)
    payload = {"sub": user_id, "roles": roles, "jti": jti, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")

def create_refresh_token(user_id: str, jti: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.jwt_refresh_expire_days)
    payload = {"sub": user_id, "jti": jti, "type": "refresh", "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")

def decode_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        if payload.get("type") == "refresh":
            return None  # Reject refresh tokens used as access tokens
        return payload
    except JWTError:
        return None
```

## OAuth 2.0 with PKCE (Mobile Clients)

PKCE (Proof Key for Code Exchange) prevents authorization code interception on mobile devices where a client secret cannot be safely stored.

### Flow

1. **Mobile app** generates a random `code_verifier` (43-128 chars, URL-safe)
2. **Mobile app** computes `code_challenge = BASE64URL(SHA256(code_verifier))`
3. **Mobile app** opens browser to authorization URL with `code_challenge` and `code_challenge_method=S256`
4. **User** authenticates with the provider (Google, Apple, etc.)
5. **Provider** redirects back with an authorization `code`
6. **Mobile app** sends `code` + `code_verifier` to your backend
7. **Backend** exchanges `code` + `code_verifier` with the provider for tokens
8. **Backend** creates or links the user account, issues your own JWT pair

### Backend Token Exchange Endpoint

```python
# routers/auth.py
import httpx
from fastapi import APIRouter, HTTPException
from app.schemas.auth import OAuthCallbackRequest, TokenResponse

router = APIRouter()

@router.post("/oauth/google/callback", response_model=TokenResponse)
async def google_oauth_callback(payload: OAuthCallbackRequest, db=Depends(get_db)):
    # Exchange authorization code for Google tokens
    async with httpx.AsyncClient() as client:
        resp = await client.post("https://oauth2.googleapis.com/token", data={
            "code": payload.code,
            "code_verifier": payload.code_verifier,
            "client_id": settings.google_client_id,
            "redirect_uri": payload.redirect_uri,
            "grant_type": "authorization_code",
        })
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="OAuth token exchange failed")

    google_tokens = resp.json()
    # Decode ID token to get user info (verify signature in production)
    id_token_payload = jwt.decode(
        google_tokens["id_token"], options={"verify_signature": False}
    )

    # Find or create user
    service = UserService(db)
    user = await service.find_or_create_oauth(
        provider="google",
        provider_id=id_token_payload["sub"],
        email=id_token_payload["email"],
    )

    # Issue your own tokens
    return create_token_pair(user)
```

## Password Hashing

Always use bcrypt with cost factor 12 or argon2id:

```typescript
// NestJS
import * as bcrypt from 'bcrypt';
const SALT_ROUNDS = 12;

const hash = await bcrypt.hash(plainPassword, SALT_ROUNDS);
const isMatch = await bcrypt.compare(plainPassword, hash);
```

```python
# FastAPI — using passlib
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

hashed = pwd_context.hash(plain_password)
is_valid = pwd_context.verify(plain_password, hashed)
```

## Role-Based Access Control (RBAC)

### NestJS Guard

```typescript
// guards/roles.guard.ts
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) return true;
    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}
```

### FastAPI Dependency

```python
from fastapi import Depends, HTTPException, status

def require_roles(*roles: str):
    def checker(current_user=Depends(get_current_user)):
        if not any(r in current_user.roles for r in roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return current_user
    return checker

# Usage:
@router.delete("/{user_id}")
async def delete_user(user_id: str, admin=Depends(require_roles("admin"))):
    ...
```

## API Key Authentication

For service-to-service or third-party integrations:

```python
from fastapi import Security
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(
    api_key: str = Security(api_key_header),
    db: AsyncSession = Depends(get_db),
):
    key_record = await db.execute(
        select(ApiKey).where(
            ApiKey.key_hash == hash_api_key(api_key),
            ApiKey.is_active == True,
            ApiKey.expires_at > datetime.now(timezone.utc),
        )
    )
    key = key_record.scalar_one_or_none()
    if not key:
        raise HTTPException(status_code=401, detail="Invalid API key")
    # Update last_used_at
    key.last_used_at = datetime.now(timezone.utc)
    return key
```

Store only the hash of the API key (SHA-256). Show the full key exactly once at creation time.

## Rate Limiting

### Per-User Rate Limiting with Redis

```typescript
// NestJS — using @nestjs/throttler
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

@Module({
  imports: [
    ThrottlerModule.forRoot([
      { name: 'short', ttl: 1000, limit: 3 },    // 3 req/sec
      { name: 'medium', ttl: 10000, limit: 20 },  // 20 req/10sec
      { name: 'long', ttl: 60000, limit: 100 },   // 100 req/min
    ]),
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
```

Apply stricter limits to auth endpoints:

```typescript
@Throttle({ short: { ttl: 60000, limit: 5 } }) // 5 attempts per minute
@Post('login')
async login(@Body() dto: LoginDto) { ... }
```

## Secure Cookie Settings

When using cookies (e.g., for refresh tokens in web apps):

```typescript
response.cookie('refreshToken', token, {
  httpOnly: true,      // Not accessible via JavaScript
  secure: true,        // HTTPS only
  sameSite: 'lax',     // CSRF protection
  path: '/api/v1/auth/refresh', // Only sent to refresh endpoint
  maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days in ms
});
```

## CSRF Protection

Required when using cookie-based authentication with a web frontend. Not needed for mobile apps using Bearer tokens.

- Use the Synchronizer Token Pattern or Double Submit Cookie
- In NestJS: `csurf` middleware (deprecated) or implement custom CSRF tokens
- Always verify `Origin` and `Referer` headers as a secondary check
- Set `SameSite=Lax` or `Strict` on all auth cookies
