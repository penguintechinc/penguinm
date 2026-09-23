# penguin_auth

`AuthController` (implements `TokenProvider`), `Session`, `JwtClaims`,
`HostedLoginBackend` (`flutter_appauth`), `PasswordAuthBackend`, `SessionStore`
(`flutter_secure_storage` only — tokens never touch plaintext), and
`authRedirect` for `go_router`. See spec §4.5.
