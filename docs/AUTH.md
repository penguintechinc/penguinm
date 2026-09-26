# Authentication — Hosted Login & Backend Contract

Mobile apps use server-hosted login (authorization code + PKCE in the system browser) as the default. This document describes the flow, backend contract, and the transitional password-based fallback.

## Hosted Login Flow (Recommended)

The app never renders login credentials or provider buttons. Instead, it hands off to the system browser and lets the server decide OIDC/SAML/local + MFA.

### Sequence

1. **App opens system browser**
   - App constructs authorization URL with PKCE challenge
   - Opens Custom Tabs (Android) or SFSafariViewController (iOS)
   - Navigates to `<issuer>/.well-known/openid-configuration` (discovery) or explicit authorization endpoint

2. **System browser session (persistent per family)**
   - User authenticates (OIDC, SAML, or local username/password chosen by server)
   - Optional MFA challenge
   - Server issues authorization code (short-lived, one-time use)
   - Server redirects to `io.penguintech.<app>://oauth/callback?code=<code>&state=<state>`

3. **App intercepts redirect**
   - Deep link handler captures the redirect URL
   - App validates state parameter (CSRF protection)
   - App extracts authorization code

4. **Code → tokens exchange**
   - App sends POST request with code + PKCE verifier to `<issuer>/token`
   - Server validates code and PKCE verifier; issues access token + optional refresh token
   - App decodes JWT (no signature verification on client; server validates)
   - App stores tokens in `flutter_secure_storage` only

5. **API calls**
   - Subsequent requests include `Authorization: Bearer <access_token>` header
   - On 401: app calls `/token` to refresh; if refresh fails or 401 persists, app transitions to unauthenticated state

6. **Logout**
   - App calls `/end_session` (if available) to revoke tokens server-side
   - App clears local tokens from `flutter_secure_storage`

### Family Single Sign-On

Companion apps of one family share the **same system browser session**. A user signs in to one app, and sibling apps see the session:

1. **User signs in to Elder** (product: elder)
   - Browser session created, user authenticated
   - Access token stored in secure storage

2. **User opens Elder Support** (same family, product: elder)
   - App opens system browser → the existing session is alive
   - Authorization endpoint redirects immediately (no login prompt)
   - New access token issued in seconds

**Multi-family session**: Each product's authorization endpoint is different (`issuer` per product), so different browser sessions are maintained. A user signed in to Tobogganing and WaddleAI will have separate browser sessions for each.

## Backend Contract

Every product team must expose an OAuth2 authorization-code + PKCE flow for public mobile clients.

### Minimum Requirements

- **HTTPS only** (TLS 1.2+)
- **Public clients**: no client secret; `client_id` is `io.penguintech.<app>` (one per app, e.g., `io.penguintech.elder`, `io.penguintech.waddles`)
- **Authorization code flow** with PKCE (RFC 7636)
- **Redirect URI**: `io.penguintech.<app>://oauth/callback` (exact match required; registered per app)
- **Login page** (your UI): where OIDC/SAML/local and MFA are chosen server-side
- **JWT response** with standard claims: `sub`, `iss`, `aud`, `iat`, `exp`, `scope`, `tenant`, `teams`, `roles`
- **Token refresh** endpoint (rotate refresh tokens; reused refresh token = revoke all)
- **End session** endpoint (optional but recommended for logout)

### OpenID Connect Discovery

Preferred: publish `.well-known/openid-configuration` with:
```json
{
  "issuer": "https://auth.myproduct.app",
  "authorization_endpoint": "https://auth.myproduct.app/authorize",
  "token_endpoint": "https://auth.myproduct.app/token",
  "end_session_endpoint": "https://auth.myproduct.app/logout",
  "jwks_uri": "https://auth.myproduct.app/.well-known/jwks.json"
}
```

If not available, apps configure explicit endpoints in `AuthConfig.hosted(...)`.

### Authorization Endpoint

`GET <issuer>/authorize?client_id=<id>&response_type=code&scope=<scope>&state=<state>&code_challenge=<challenge>&code_challenge_method=S256&redirect_uri=<uri>`

| Parameter | Value |
|---|---|
| `client_id` | `io.penguintech.<app>` (no secret sent) |
| `response_type` | `code` |
| `scope` | `openid profile email offline_access` (app may request additional scopes) |
| `state` | CSRF token (random, validated on redirect) |
| `code_challenge` | PKCE challenge (base64url(SHA256(verifier))) |
| `code_challenge_method` | `S256` |
| `redirect_uri` | `io.penguintech.<app>://oauth/callback` (exact match) |

**Response**: Redirect to `io.penguintech.<app>://oauth/callback?code=<code>&state=<state>` (or error: `?error=<code>&error_description=<desc>`)

### Token Endpoint

`POST <issuer>/token`

```
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
code=<code>&
client_id=io.penguintech.<app>&
code_verifier=<verifier>&
redirect_uri=io.penguintech.<app>%3A%2F%2Foauth%2Fcallback
```

| Parameter | Value |
|---|---|
| `grant_type` | `authorization_code` |
| `code` | Authorization code from redirect |
| `client_id` | `io.penguintech.<app>` (no secret sent) |
| `code_verifier` | PKCE verifier (plaintext; server compares SHA256(verifier) to challenge) |
| `redirect_uri` | Must match the value sent to authorization endpoint |

**Response** (200 OK, `application/json`):
```json
{
  "access_token": "<jwt>",
  "refresh_token": "<refresh_jwt>",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Error response** (400 Bad Request):
```json
{
  "error": "invalid_code",
  "error_description": "Authorization code has expired"
}
```

### Token Refresh

`POST <issuer>/token`

```
grant_type=refresh_token&
refresh_token=<refresh_jwt>&
client_id=io.penguintech.<app>
```

**Response**: Same as authorization code exchange (new access token + optional new refresh token).

**Token rotation**: every refresh must return a new refresh token; a refresh token used twice (or after expiration) indicates compromise — revoke the entire token chain.

### End Session

`POST <issuer>/end_session` or `GET <issuer>/logout?id_token_hint=<jwt>&post_logout_redirect_uri=<uri>`

Revokes the user's session server-side. Optional but recommended.

### JWT Claims (Required)

Every token issued by the authorization endpoint must include:

| Claim | Type | Example | Use |
|---|---|---|---|
| `sub` | string | `user-12345` | User identifier; unique per user per issuer |
| `iss` | string | `https://auth.myproduct.app` | Issuer; must match `issuer` in request |
| `aud` | array | `["io.penguintech.elder"]` | Intended audience; includes client_id |
| `iat` | number | 1630703240 | Issued at (seconds since epoch) |
| `exp` | number | 1630707240 | Expiration (seconds since epoch); typically 1h |
| `scope` | string | `openid profile email offline_access` | Granted scopes |
| `tenant` | string | `tenant-xyz` | Tenant identifier; used for multi-tenant isolation |
| `teams` | array | `["eng", "founders"]` | Teams the user belongs to (for display) |
| `roles` | array | `["viewer", "editor"]` | Roles (for display; authz uses scopes, not roles) |

**Authorization scopes** (clients check these, never role names):

| Scope | Meaning |
|---|---|
| `openid` | Basic identity (sub, iss, aud) |
| `profile` | User display name, picture |
| `email` | Email address |
| `offline_access` | Refresh token issued |
| `<product>.<module>` | Module-level permission (e.g., `elder.springboard`, `waddlebot.waddles`) |
| `<product>.<module>:read` | Read-only access to a module |
| `<product>.<module>:write` | Write access (implies read) |
| `<product>.<module>:admin` | Admin access (implies read+write) |
| `<product>.users:admin` | User management (global) |

See `security.md` Authentication & Authorization section in admin rules for the full model.

## Transitional Password-Based Login

**For products without hosted login yet** (penguincloud today):

### Configuration

```dart
auth: AuthConfig.password(
  loginPath: '/api/v1/auth/login',
  refreshPath: '/api/v1/auth/refresh',
  logoutPath: '/api/v1/auth/logout',
  profilePath: '/api/v1/auth/profile',
  mfa: true,
)
```

The app renders an in-app login form (via `flutter_libs` `LoginPageBuilder`) instead of opening the browser.

### Login Endpoints

`POST /api/v1/auth/login`
```json
{
  "email": "user@example.com",
  "password": "password",
  "mfa_code": "123456"  // optional if MFA is enabled
}
```

Response (200 OK):
```json
{
  "access_token": "<jwt>",
  "refresh_token": "<refresh_jwt>",
  "expires_in": 3600
}
```

`POST /api/v1/auth/refresh`
```json
{
  "refresh_token": "<refresh_jwt>"
}
```

`POST /api/v1/auth/logout`
```json
{
  "access_token": "<jwt>"
}
```

`GET /api/v1/auth/profile` (requires Bearer auth)
Response: user profile JSON (name, email, etc.)

### Migration Path

All password-based endpoints are tracked in the relevant app's `README.md` under a "Transitional Auth" section until the backend is upgraded to hosted login.

Currently on password auth:
- **penguincloud** → track until hosted login is added

## Implementation (App Side)

```dart
// Use hosted login (recommended)
final authConfig = AuthConfig.hosted(
  issuer: Uri.parse(config.apiBaseUrl),
  clientId: 'io.penguintech.myapp',
  redirectUri: 'io.penguintech.myapp://oauth/callback',
  // optionally: explicit endpoints if discovery unavailable
  authorizationEndpoint: Uri.parse('https://auth.myproduct.app/authorize'),
  tokenEndpoint: Uri.parse('https://auth.myproduct.app/token'),
  endSessionEndpoint: Uri.parse('https://auth.myproduct.app/logout'),
);

// Or password (transitional, for penguincloud)
final authConfig = AuthConfig.password(
  loginPath: '/api/v1/auth/login',
  refreshPath: '/api/v1/auth/refresh',
  logoutPath: '/api/v1/auth/logout',
  profilePath: '/api/v1/auth/profile',
  mfa: true,
);

// Create auth controller
final authBackend = HostedLoginBackend(authConfig)
  // or PasswordAuthBackend for transitional
final authController = AuthController(...); // from shell bootstrap
await authController.initialize();

// Login (hosted opens browser; password shows form)
await authController.login(const LoginRequest.interactive());

// Token is now available for API calls
final token = await ref.read(authControllerProvider.select((s) =>
  s is AuthState.authenticated ? s.session.accessToken : null
));
```

See `packages/penguin_auth/` for full implementation.

## Tokens in Logs

Tokens are never logged, even at DEBUG level. The `LogSanitizer` masks by key pattern:

```dart
LogSanitizer.maskValue('Bearer eyJhb...') → 'Bearer ****...ub3'
```

Masked tokens log the key pattern and last 4 chars only.
