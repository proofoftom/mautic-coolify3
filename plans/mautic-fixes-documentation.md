# Mautic Coolify Deployment Fixes

## Problem Summary

The custom Mautic deployment was experiencing issues with theme asset URLs pointing to `localhost` instead of the actual Coolify URL:

```
GET http://localhost/themes/ThemeBlend/assets/mymind-3dmu0gu23uc-unsplash.jpg?vb40ec413 net::ERR_BLOCKED_BY_CLIENT
```

## Root Cause Analysis

### Issue 1: Wrong Environment Variable Name

In [`docker-compose.yaml`](../docker-compose.yaml:57), the configuration used:

```yaml
MAUTIC_URL: ${SERVICE_URL_MAUTIC_80}
```

However, Coolify generates environment variables based on the **service name** `mautic_web`, not the port suffix. The actual variable that gets populated is:

- `SERVICE_URL_MAUTIC_WEB` ✅ (populated with `https://mw4s8s8kcss4ggwwgcocg0ss.localnodes.xyz`)
- `SERVICE_URL_MAUTIC_80` ❌ (never populated)

### Issue 2: Fallback to localhost

In [`docker-entrypoint-custom.sh`](../docker-entrypoint-custom.sh:141):

```bash
SITE_URL="${MAUTIC_URL:-http://localhost}"
```

Since `MAUTIC_URL` was empty (wrong variable name), it defaulted to `http://localhost` during installation, and this value was persisted to the config volume.

## Fixes Applied

### 1. Fixed Environment Variable in docker-compose.yaml

Changed all instances of `SERVICE_URL_MAUTIC_80` to `SERVICE_URL_MAUTIC_WEB`:

- `mautic_web` service (line 57)
- `mautic_cron` service (line 103)
- `mautic_worker` service (line 145)

### 2. Added Fallback Logic to docker-entrypoint-custom.sh

Updated the URL resolution to try multiple Coolify environment variable patterns:

```bash
SITE_URL="${MAUTIC_URL:-${COOLIFY_URL:-${SERVICE_URL_MAUTIC_WEB:-${SERVICE_URL_MAUTIC_80:-http://localhost}}}"
```

This provides fallbacks in order:
1. `MAUTIC_URL` - explicit override
2. `COOLIFY_URL` - standard Coolify variable
3. `SERVICE_URL_MAUTIC_WEB` - service-based variable (correct for mautic_web)
4. `SERVICE_URL_MAUTIC_80` - port-based variable (legacy fallback)

### 3. Added Missing Volumes

Added `vendor` and `bin` volumes that were present in the one-click service but missing from the custom deployment:

```yaml
volumes:
  vendor:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./volumes/vendor
  bin:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./volumes/bin
```

These volumes are important for:
- `vendor` - Composer dependencies installed during build
- `bin` - Mautic console commands and utilities

## Coolify Environment Variable Patterns

When working with Coolify services, environment variables follow these patterns:

| Variable Type | Pattern | Example |
|--------------|---------|----------|
| Service URL | `SERVICE_URL_{SERVICE_NAME}` | `SERVICE_URL_MAUTIC_WEB` |
| Port-based URL | `SERVICE_URL_{SERVICE_NAME}_{PORT}` | `SERVICE_URL_MAUTIC_WEB_80` (rarely used) |
| Standard Coolify | `COOLIFY_URL` | Fallback for any service |
| Generated Passwords | `SERVICE_PASSWORD_64_{NAME}` | `SERVICE_PASSWORD_64_MYSQL` |
| Generated Users | `SERVICE_USER_{NAME}` | `SERVICE_USER_MYSQL` |

**Key Rule**: Use the service name (e.g., `mautic_web`) not the port (e.g., `80`) when referencing Coolify-generated URLs.

## Answer to Original Question

**Can we upload themes to the one-click Coolify Mautic Service?**

No, the one-click service has limitations:

| Feature | One-click Service | Custom Deployment |
|----------|------------------|-------------------|
| Custom themes | ❌ No themes volume, manual copy only | ✅ Baked into image, git-controlled |
| Composer packages | ❌ Cannot run composer install | ✅ Runs during build time |
| Plugins | ⚠️ Volume exists but no install mechanism | ✅ Baked into image |
| Git workflow | ❌ Manual intervention required | ✅ Full git push-to-deploy |
| Reproducible deploys | ❌ Manual steps required | ✅ Automated |

**Conclusion**: The custom deployment approach is correct for your use case. The issues were configuration bugs, not fundamental problems with the approach.

## Next Steps

1. Commit and push changes to git
2. Trigger redeploy in Coolify
3. Verify theme asset URLs are now correct (should be `https://mw4s8s8kcss4ggwwgcocg0ss.localnodes.xyz/themes/...`)
4. Test that themes appear correctly in Mautic admin panel
