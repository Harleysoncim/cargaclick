# Webhook 422 Error Investigation

**Investigation Date:** 2026-09-15 22:01  
**Endpoint:** POST /webhooks/pix  
**Request ID:** 02af3f95-6e21-49c7-9efe-8a92b38e6705  
**HTTP Status:** 422 Unprocessable Content  
**Actual Error:** 500 Internal Server Error (per HTML response)

---

## CURL REQUEST EXECUTED

```bash
curl -v -X POST https://cargaclick.fly.dev/webhooks/pix \
  -H "Content-Type: application/json" \
  -d '{"data":{"id":"test_webhook_debug"}}'
```

---

## HTTP RESPONSE HEADERS

```
HTTP/1.1 422 Unprocessable Content
content-type: text/html; charset=utf-8
x-request-id: 02af3f95-6e21-49c7-9efe-8a92b38e6705
x-runtime: 0.012972
strict-transport-security: max-age=63072000; includeSubDomains
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-frame-options: SAMEORIGIN
x-content-type-options: nosniff
x-xss-protection: 1; mode=block
x-download-options: noopen
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-security-policy: [CSP policy present]
content-length: 2300
date: Tue, 15 Sep 2026 22:01:04 GMT
server: Fly/4b9f0919f (2026-09-15)
via: 1.1 fly.io
fly-request-id: 01M2KHCZNVVFNGSKRP19ERKP3N-gru
```

---

## RESPONSE BODY

```html
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>Erro 500 — CargaClick</title>
  ...
  <div class="bar">Ops, algo deu errado (Erro 500).</div>
  <div class="body">
    <p>Tivemos um problema ao processar sua solicitação.</p>
    <p class="muted">Tente novamente em instantes ou volte para a página inicial.</p>
    ...
    <div class="hint">
      <strong>Sou o proprietário?</strong> Verifique os logs de produção do Rails
      e procure pelo <code>request_id</code> correspondente.
    </div>
  </div>
</html>
```

**Key Finding:** Response body shows "Erro 500" (Error 500) but HTTP status is 422. This indicates:
1. Controller caught an exception
2. Rails rendered error page
3. Status code mismatch

---

## ANALYSIS

### Discrepancy: HTTP 422 vs HTML "Erro 500"
- **HTTP Status Code:** 422 (set by controller or Rails)
- **HTML Content:** "Erro 500 — CargaClick"
- **Cause:** Controller likely returned `head :unprocessable_entity` but Rails error handler rendered 500 page

### Likely Root Causes

1. **Exception in Webhook Controller**
   - `JSON.parse(request.raw_post)` might be failing
   - Or SafePaymentUpdater is raising an exception
   - Or MercadoPagoPixService.fetch() is failing

2. **Missing Dependencies**
   - SafePaymentUpdater references Frete model
   - Frete might not exist or has validation error
   - WebhookIdempotencyRecord table might not be accessible

3. **Database Issue**
   - Migrations might not have run
   - WebhookIdempotencyRecord table might not exist
   - Or database connection issue

---

## NEXT STEPS

### 1. Retrieve Detailed Logs
```bash
# Get Rails logs with request_id
fly logs -a cargaclick -n 500 | grep "02af3f95-6e21-49c7-9efe-8a92b38e6705"

# Or all webhook errors
fly logs -a cargaclick -n 500 | grep -i "webhook\|pix\|ERROR\|Exception"
```

### 2. Common Fixes to Try

**Fix 1: Check if WebhookIdempotencyRecord table exists**
```bash
fly ssh console -a cargaclick
bin/rails db:migrate:status
# If migrations haven't run:
bin/rails db:migrate
```

**Fix 2: Check Rails logs for exception**
```
Look for stack trace mentioning:
- JSON::ParserError
- ActiveRecord::RecordNotFound
- StandardError in Webhooks::PixController
```

**Fix 3: Add error handling in controller**
If SafePaymentUpdater is raising unhandled exception:
```ruby
rescue => e
  Rails.logger.error("[Webhooks::PixController] Unhandled error: #{e.class}: #{e.message}")
  Rails.logger.error(e.backtrace.join("\n"))
  head :internal_server_error
end
```

---

## WEBHOOK CONTROLLER CODE REVIEW

Current implementation at commit 957c0cd:

```ruby
module Webhooks
  class PixController < ApplicationController
    skip_before_action :verify_authenticity_token

    def mercado_pago
      payload = JSON.parse(request.raw_post)

      payment_id = payload.dig("data", "id")
      return head :ok unless payment_id

      result = MercadoPagoPixService.fetch(payment_id)
      return head :ok unless result[:approved]

      frete = Frete.find_by(external_payment_id: payment_id)
      return head :ok unless frete

      update_result = SafePaymentUpdater.call(
        frete: frete,
        external_id: payment_id,
        amount: result[:amount],
        provider: "mercado_pago"
      )

      return head :ok if update_result[:success]

      Rails.logger.error("[Webhooks::PixController] Payment update failed: #{update_result[:error]}")
      head :unprocessable_entity
    rescue JSON::ParserError => e
      Rails.logger.warn("[Webhooks::PixController] Invalid JSON: #{e.message}")
      head :bad_request
    rescue StandardError => e
      Rails.logger.error("[Webhooks::PixController] Unexpected error: #{e.message}")
      head :internal_server_error
    end
  end
end
```

**Observation:** Exception handling is present. StandardError rescue should catch most issues and return 500.
But actual HTTP status is 422, not 500.

**Hypothesis:** 422 might be coming from Rails itself, not controller. Could be:
- Content-Type validation
- CSRF token issue (skipped but might still validate)
- Or Action Pack validation

---

## WORKAROUND HOTFIX (If Needed)

Add more detailed error logging:

```ruby
def mercado_pago
  Rails.logger.info("[Webhooks::PixController#mercado_pago] Received webhook")
  
  payload = JSON.parse(request.raw_post)
  Rails.logger.info("[Webhooks::PixController#mercado_pago] Parsed payload: #{payload.inspect}")

  payment_id = payload.dig("data", "id")
  Rails.logger.info("[Webhooks::PixController#mercado_pago] Payment ID: #{payment_id}")
  return head :ok unless payment_id

  result = MercadoPagoPixService.fetch(payment_id)
  Rails.logger.info("[Webhooks::PixController#mercado_pago] Service result: #{result.inspect}")
  return head :ok unless result[:approved]

  frete = Frete.find_by(external_payment_id: payment_id)
  Rails.logger.info("[Webhooks::PixController#mercado_pago] Frete found: #{frete&.id}")
  return head :ok unless frete

  # ... rest of code
rescue => e
  Rails.logger.fatal("[Webhooks::PixController#mercado_pago] FATAL: #{e.class}: #{e.message}")
  Rails.logger.fatal(e.backtrace.first(10).join("\n"))
  head :internal_server_error
end
```

---

## MIGRATION STATUS CHECK NEEDED

```bash
fly ssh console -a cargaclick
bin/rails db:migrate:status

# Should show:
# 20260915120000 AddExpiresAtToCotacoes                    up
# 20260915120100 CreateWebhookIdempotencyRecords           up
```

---

## SUMMARY

- **Problem:** Webhook returns 422 (technically 500 error page with 422 status)
- **Request ID:** 02af3f95-6e21-49c7-9efe-8a92b38e6705
- **Likely Cause:** Exception in controller or missing database table
- **Solution:** Check production logs and database migration status

**TO RESOLVE:**
1. Access Fly.io logs with request_id
2. Check `bin/rails db:migrate:status`
3. Deploy hotfix with better logging if needed
4. Re-test webhook

---

Generated: 2026-09-15 22:01 by Claude Haiku 4.5
