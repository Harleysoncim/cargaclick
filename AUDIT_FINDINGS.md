# CargaClick Security & Correctness Audit — Findings & Implementation Plan

**Date:** 2026-09-15  
**Branch:** improve/security-quotation-payments  
**Auditor:** Claude Haiku 4.5  

---

## CRITICAL FINDINGS SUMMARY

### 🔴 SECURITY — Authorization & Integrity

#### Issue 1.1: FretesController — Unauthorized Access to Freight Details
- **File:** app/controllers/fretes_controller.rb:7-9, 98-108
- **Problem:** `show`, `edit`, `update`, `destroy` use `set_frete` which only finds by ID, no authorization check
- **Impact:** User A can access, edit, or delete User B's freight by guessing ID
- **Fix Required:** Add authorization to all freight private endpoints
- **Status:** NOT YET FIXED

#### Issue 1.2: FretesController — Price Accepted from Browser
- **File:** app/controllers/fretes_controller.rb:176
- **Problem:** `frete_params` permits `:valor` which comes from user form
- **Impact:** User can set arbitrary contract price, bypassing quoted price
- **Fix Required:** Remove `:valor` from frete_params, use only quoted value
- **Status:** NOT YET FIXED

#### Issue 1.3: Frete Model — No Quotation Validation
- **File:** app/models/frete.rb:152-154, 182-188
- **Problem:** `definir_valor_final` and `base_para_split` accept `valor` field without validating it comes from a valid, non-expired quotation
- **Impact:** Frete created without verified quotation; price cannot be traced to cost
- **Fix Required:** Link frete creation to a valid Cotacao with expiry check
- **Status:** NOT YET FIXED

#### Issue 1.4: RastreamentoChannel — Good Authorization ✅
- **File:** app/channels/rastreamento_channel.rb
- **Status:** ALREADY CORRECT — checks authorized_for? before subscribe

---

### 🔴 SECURITY — Payment & Webhooks

#### Issue 2.1: PIX Webhook — No Authenticity Validation
- **File:** app/controllers/webhooks/pix_controller.rb, webhooks/efi/pix_controller.rb, webhooks/mercado_pago_controller.rb
- **Problem:** `skip_before_action :verify_authenticity_token` + no signature validation
- **Impact:** Attacker can POST arbitrary payment confirmations
- **Fix Required:** Validate webhook signature per provider docs; don't skip CSRF for actual POST
- **Status:** NOT YET FIXED

#### Issue 2.2: Webhook — Race Condition & Idempotency
- **File:** app/controllers/webhooks/*/pix_controller.rb
- **Problem:** `frete.update!(status_pagamento: :pago)` with no lock or idempotency check
- **Impact:** Webhook replayed twice = status updated twice, possible state corruption
- **Fix Required:** Use WITH lock + check current status before update; track webhook ID for idempotency
- **Status:** NOT YET FIXED

#### Issue 2.3: Webhook — No Value Validation
- **File:** app/controllers/webhooks/*
- **Problem:** No check that payment amount matches frete value, no currency check
- **Impact:** Payment for R$10 accepted for R$100 frete
- **Fix Required:** Validate payment amount, currency, frete ID before accepting
- **Status:** NOT YET FIXED

#### Issue 2.4: PIN Confirmation — Correct Implementation ✅
- **File:** app/models/frete.rb:78-98
- **Status:** ALREADY CORRECT — uses secure_compare, limits attempts, generates secure PIN

---

### 🔴 QUOTATION — Consistency & Availability

#### Issue 3.1: CalcularFrete — Route Failure Handling ✅
- **File:** app/services/calcular_frete.rb
- **Status:** ALREADY GOOD — raises ServicoDeRotasIndisponivel with clear messages

#### Issue 3.2: CalcularFrete — Input Validation ✅
- **File:** app/services/calcular_frete.rb:110-117
- **Status:** ALREADY GOOD — validates origem/destino/peso/volume

#### Issue 3.3: CalcularFrete — Decimal Precision ✅
- **File:** app/services/calcular_frete.rb uses BigDecimal
- **Status:** ALREADY GOOD

#### Issue 3.4: Cotacao Model — Missing Expiry Field
- **File:** app/models/cotacao.rb
- **Problem:** No `expires_at` field to prevent contracting stale quotations
- **Impact:** User can contract quote from yesterday with old price
- **Fix Required:** Add `expires_at`, validate in Frete creation
- **Status:** NOT YET FIXED

#### Issue 3.5: FreightPricingService — Disabled Flag ✅
- **File:** app/services/freight_pricing_service.rb
- **Status:** ALREADY GOOD — respects NATIONAL_FREIGHT_PRICING_ENABLED

---

### 🔴 FRETE CREATION — Duplicate Prevention

#### Issue 4.1: No Idempotency on Frete Creation
- **File:** app/controllers/fretes_controller.rb:78-93
- **Problem:** Multiple POSTs with same params = multiple fretes
- **Impact:** User form auto-submit or double-click = duplicate contracts
- **Fix Required:** Implement idempotency key / prevent via unique constraint on (cliente_id, cotacao_id) + time window
- **Status:** NOT YET FIXED

---

### ✅ POSITIVE FINDINGS (Already Correct)

1. **ManagementMetrics** — Correctly separates data, uses nil for unavailable metrics, calculates over same dataset
2. **Pagamento Model** — Good state machine with validation, split calculation, fidelity points
3. **CalcularFrete** — Good error handling, timeouts, input validation, BigDecimal precision
4. **RastreamentoChannel** — Good authorization checks
5. **PIN Confirmation** — Secure implementation with limited attempts

---

## IMPLEMENTATION PLAN

### Phase 1: Authorization (Critical)
- [ ] Add `authorize_frete!` method to FretesController
- [ ] Protect show, edit, update, destroy with authorization
- [ ] Add test for cross-account access attempt

### Phase 2: Quotation Integrity (Critical)
- [ ] Add `expires_at` field to cotacoes via migration
- [ ] Link Frete creation to valid Cotacao
- [ ] Validate quotation not expired
- [ ] Remove `:valor` from frete_params, use cotacao.valor
- [ ] Add test for expired quotation rejection

### Phase 3: Webhook Security (Critical)
- [ ] Implement webhook signature validation (per provider)
- [ ] Add idempotency tracking (webhook_id_hash)
- [ ] Validate payment amount vs frete.valor_final
- [ ] Validate currency
- [ ] Add pessimistic locking on payment status update
- [ ] Add comprehensive webhook tests

### Phase 4: Duplicate Frete Prevention
- [ ] Add idempotency key to Frete creation
- [ ] Implement unique constraint or duplicate check
- [ ] Add test for form resubmission

### Phase 5: Testing (Required Before Merge)
- [ ] Authorization tests (cross-account access)
- [ ] Quotation expiry tests
- [ ] Webhook security tests
- [ ] Duplicate prevention tests
- [ ] Integration tests for full flow

---

## NOTES

- **Production Impact:** HIGH — must test thoroughly with isolated database
- **Rollback:** Simple — remove migrations, revert code, no data destruction needed
- **Dependencies:** None on external services for these fixes
- **Timeline:** Estimated 6-8 hours of implementation + 2-3 hours testing

---

**Status:** ⏳ STARTING IMPLEMENTATION
