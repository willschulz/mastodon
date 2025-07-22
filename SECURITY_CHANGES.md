# Mastodon Security Configuration Changes

This document outlines the changes made to secure the Mastodon instance by disabling public access, registration, and federation.

## Changes Made

### 1. Disable Public Feed Without Login ✅

**File Modified:** `mastodon/config/settings.yml`
```yaml
# disable timeline preview to prevent logged-out users
# from seeing the content of public timelines
timeline_preview: false
```

**How it works:** The `timeline_preview` setting controls whether unauthenticated users can access public timelines. When set to `false`, the `require_auth?` method in `Api::V1::Timelines::PublicController` returns `true`, which triggers the `require_user!` before_action, forcing authentication.

### 2. Disable Account Registration ✅

**File Modified:** `mastodon/config/settings.yml`
```yaml
registrations_mode: 'none'
```

**How it works:** This setting completely disables new account registrations. The three possible values are:
- `'open'` - Anyone can register
- `'approved'` - Registration requires admin approval
- `'none'` - Registration completely disabled

### 3. Disable Federation ✅

**File Modified:** `mastodon/config/initializers/2_whitelist_mode.rb`
```ruby
Rails.application.configure do
  # Hard-code limited federation mode to disable all federation
  config.x.whitelist_mode = true
end
```

**Additional Federation Settings Modified:** `mastodon/config/settings.yml`
```yaml
activity_api_enabled: false
peers_api_enabled: false
```

**How it works:** 
- `LIMITED_FEDERATION_MODE=true` (hard-coded) enables whitelist mode, which means the server only federates with explicitly allowed domains
- `activity_api_enabled: false` disables the activity API that exposes federation statistics
- `peers_api_enabled: false` disables the peers API that lists known servers

## Testing the Changes

### Test 1: Public Feed Access
1. Try to access `https://alpha.argyle.social/public/local` without logging in
2. **Expected Result:** Should be redirected to login page or show access denied

### Test 2: Registration
1. Try to access the registration page
2. **Expected Result:** Should show that registration is disabled

### Test 3: Federation
1. Try to access `https://alpha.argyle.social/api/v1/instances/activity`
2. **Expected Result:** Should return 404 (API disabled)
3. Try to access `https://alpha.argyle.social/api/v1/instances/peers`
4. **Expected Result:** Should return 404 (API disabled)

## Environment Variables (if needed)

If you need to set these via environment variables instead of hard-coding, create a `.env.production` file with:

```bash
# Disable federation
LIMITED_FEDERATION_MODE=true
AUTHORIZED_FETCH=true

# Disable public API access
DISALLOW_UNAUTHENTICATED_API_ACCESS=true
```

## Verification Commands

To verify the settings are active, you can check:

```bash
# Check if timeline preview is disabled
curl -I https://alpha.argyle.social/public/local

# Check if registration is disabled
curl -I https://alpha.argyle.social/auth/sign_up

# Check if federation APIs are disabled
curl -I https://alpha.argyle.social/api/v1/instances/activity
curl -I https://alpha.argyle.social/api/v1/instances/peers
```

## Reverting Changes

To revert these changes:

1. **Public Feed:** Set `timeline_preview: true` in `settings.yml`
2. **Registration:** Set `registrations_mode: 'open'` in `settings.yml`
3. **Federation:** Set `config.x.whitelist_mode = false` in `2_whitelist_mode.rb`
4. **APIs:** Set `activity_api_enabled: true` and `peers_api_enabled: true` in `settings.yml`

## Notes

- These changes require a server restart to take effect
- The federation settings will prevent any ActivityPub communication with other servers
- Users will need to be created manually by administrators
- All public content will be restricted to authenticated users only 