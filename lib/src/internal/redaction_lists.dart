/// Library-internal hidden-name lists behind [TelescopeRedaction].
///
/// Kept here (like `http_adapter_registry.dart`) so [TelescopeStore.resetForTesting]
/// can restore them from library code without calling a `@visibleForTesting`
/// member. Not exported from the public barrel. Every entry is lowercased.
library;

// Laravel's defaults (`authorization`, `php-auth-pw`) widened to the headers
// a Flutter client actually sends a credential in: proxy auth, cookies (a
// session is a credential) and the common API-key header. `php-auth-pw` is a
// PHP server variable, never a client header.
const Set<String> defaultHiddenRequestHeaders = <String>{
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
};

// Laravel hides `password` and `password_confirmation`; the rest are the
// names a Fortify-style password change, two-factor challenge
// (`two_factor_token`, `recovery_code`) and OAuth or social login
// (`authorization_code`, `id_token`) send a credential under. Kept to names
// that are credentials in practice, so a debugging agent still sees the
// ordinary fields of a request. A one-time `code` is left visible: the name
// is too generic to hide.
const Set<String> defaultHiddenRequestParameters = <String>{
  'password',
  'password_confirmation',
  'current_password',
  'new_password',
  'token',
  'access_token',
  'refresh_token',
  'secret',
  'client_secret',
  'authorization_code',
  'id_token',
  'two_factor_token',
  'recovery_code',
};

// Laravel hides nothing in a response by default, but a Sanctum login
// answers with `token` (`plain_text_token` on the NewAccessToken shape), a
// two-factor login with `two_factor_token`, an OAuth exchange with
// `access_token` / `refresh_token` / `id_token`, and a two-factor setup with
// `recovery_codes` plus the TOTP secret three times (`secret`, and inside
// `qr_url` and `qr_svg`). A bare list of codes under `data` has no key to
// match and is not covered.
const Set<String> defaultHiddenResponseParameters = <String>{
  'token',
  'access_token',
  'refresh_token',
  'plain_text_token',
  'secret',
  'client_secret',
  'id_token',
  'two_factor_token',
  'recovery_codes',
  'qr_url',
  'qr_svg',
};

final Set<String> hiddenRequestHeaders = <String>{
  ...defaultHiddenRequestHeaders,
};

final Set<String> hiddenRequestParameters = <String>{
  ...defaultHiddenRequestParameters,
};

final Set<String> hiddenResponseParameters = <String>{
  ...defaultHiddenResponseParameters,
};

/// Restore the three lists to their defaults.
void resetRedactionLists() {
  hiddenRequestHeaders
    ..clear()
    ..addAll(defaultHiddenRequestHeaders);
  hiddenRequestParameters
    ..clear()
    ..addAll(defaultHiddenRequestParameters);
  hiddenResponseParameters
    ..clear()
    ..addAll(defaultHiddenResponseParameters);
}
