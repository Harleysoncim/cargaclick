# Webhook 422 Error — Log Analysis

**Request ID:** 02af3f95-6e21-49c7-9efe-8a92b38e6705  
**Timestamp:** 2026-09-15T22:01:04Z  
**Status Code:** 422 (Unprocessable Entity)  
**Response Time:** 13ms (service)  
**Wait Time:** 9ms

---

## LOG EXCERPT FROM PRODUCTION

```
2026-09-15T22:01:04Z app[e827944b10d308] gru [info][02af3f95-6e21-49c7-9efe-8a92b38e6705] 
/usr/local/bundle/ruby/3.2.0/gems/actionpack-7.1.5.2/lib/action_dispatch/middleware/exception_wrapper.rb:174: 
warning: Status code :unprocessable_entity is deprecated and will be removed in a future version of Rack. 
Please use :unprocessable_content instead.

2026-09-15T22:01:04Z app[e827944b10d308] gru [info]
source=rack-timeout id=02af3f95-6e21-49c7-9efe-8a92b38e6705 
wait=9ms timeout=15000ms service=13ms state=completed
```

---

## KEY FINDINGS

### 1. **Deprecation Warning Found**
**Message:** Status code `:unprocessable_entity` is deprecated  
**Recommendation:** Use `:unprocessable_content` instead  
**Location:** actionpack-7.1.5.2/lib/action_dispatch/middleware/exception_wrapper.rb:174  
**Severity:** INFO (not error)

### 2. **Quick Response Time**
- Wait: 9ms
- Service: 13ms
- Total: ~22ms
- **Implication:** Not a performance issue; request processed quickly

### 3. **State: Completed**
- Request completed successfully (as far as Rack knows)
- No timeout (15000ms limit not reached)
- Controller returned proper response

### 4. **No Exception Logged**
- No application-level ERROR or FATAL logs found
- No SafePaymentUpdater errors
- No Frete lookup failures  
- No ActiveRecord errors
- **Implication:** Controller is executing but returning 422 intentionally

---

## ROOT CAUSE HYPOTHESIS

Based on logs, the 422 status is **intentional**, not an error. The controller is likely:

1. **Entering rescue block** and calling `head :unprocessable_entity`
2. **OR** Rails validating request and rejecting as invalid
3. **OR** SafePaymentUpdater validation failing silently and controller returning 422

**Specific line in PixController:**
```ruby
rescue StandardError => e
  Rails.logger.error("[Webhooks::PixController] Unexpected error: #{e.message}")
  head :internal_server_error  # This should return 500, not 422
```

**OR potentially:**
```ruby
rescue ArgumentError => e
  head :unprocessable_entity  # This would return 422
```

But ArgumentError handler not visible in current code.

---

## FIX RECOMMENDATION

### Option 1: Update Deprecation (Quick Fix)
Replace in controller:
```ruby
head :unprocessable_entity
```

With:
```ruby
head :unprocessable_content
```

### Option 2: Add Detailed Logging (Better Fix)
```ruby
def mercado_pago
  payload = JSON.parse(request.raw_post)
  Rails.logger.info("[Webhooks::PixController] Payload: #{payload.inspect}")
  
  payment_id = payload.dig("data", "id")
  Rails.logger.info("[Webhooks::PixController] Payment ID: #{payment_id.inspect}")
  return head :ok unless payment_id
  
  # ... rest of code
rescue ArgumentError => e
  Rails.logger.error("[Webhooks::PixController] ArgumentError: #{e.message}")
  head :unprocessable_content
rescue StandardError => e
  Rails.logger.error("[Webhooks::PixController] StandardError: #{e.class}: #{e.message}")
  Rails.logger.error(e.backtrace.first(10).join("\n"))
  head :internal_server_error
end
```

### Option 3: Check SafePaymentUpdater Response
```ruby
update_result = SafePaymentUpdater.call(...)
Rails.logger.info("[Webhooks::PixController] Update result: #{update_result.inspect}")

unless update_result[:success]
  Rails.logger.error("[Webhooks::PixController] Payment failed: #{update_result[:error]}")
  head :unprocessable_content  # Use new status code
end
```

---

## ACTUAL ERROR LIKELY IS

Looking at SafePaymentUpdater code:

```ruby
def validate_payment_consistency!
  cotacao = frete.cotacao
  raise ArgumentError, "Frete not linked to quotation" if cotacao.nil?
  raise ArgumentError, "Quotation has no value" if cotacao.valor.blank?
  raise ArgumentError, "Quotation has expired" if cotacao.expired?
  ...
end
```

**Most probable cause:** One of these ArgumentErrors is being raised:
1. **"Frete not linked to quotation"** — frete.cotacao is nil
2. **"Quotation has expired"** — quotation's expires_at < now
3. **"Amount mismatch"** — webhook amount != quotation value

Since no frete exists with external_payment_id="test_webhook_debug", the error is probably occurring before SafePaymentUpdater even runs (controller returns 200 ok unless frete).

**OR** the SafePaymentUpdater.call() is raising ArgumentError which is NOT caught by current rescue blocks.

---

## VERIFICATION STEPS

1. **Check if ArgumentError is handled:**
   ```bash
   grep -n "rescue.*ArgumentError" app/controllers/webhooks/*.rb
   ```
   Expected: Should see `rescue ArgumentError => e` handler

2. **Add class-level error handling:**
   ```ruby
   rescue ArgumentError => e
     Rails.logger.warn("[Webhooks::PixController] Validation error: #{e.message}")
     head :unprocessable_content  # 422 is correct for validation errors
   ```

3. **Deploy hotfix and test:**
   ```bash
   git add app/controllers/webhooks/
   git commit -m "fix: improve webhook error handling and logging"
   git push origin main
   # Fly.io redeploy automatic
   ```

---

## CONCLUSION

**Status 422 is technically correct** for "Unprocessable Content" when:
- Payload is malformed
- Required fields missing
- Validation fails

**The deprecation warning** suggests using `:unprocessable_content` instead of `:unprocessable_entity`.

**The missing ERROR logs** suggest the controller is handling this gracefully without crashing, which is good.

**The fix:** Update status code name and add better logging to identify which validation is failing.

---

Generated: 2026-09-15 from production logs (request ID: 02af3f95-6e21-49c7-9efe-8a92b38e6705)
