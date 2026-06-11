#!/bin/sh
# =============================================================================
# JIADI — Vault initialization script
# Run with: docker exec -it vault sh /vault/init.sh
# =============================================================================

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="dev-root-token"

echo ">>> Vault is ready."

# =============================================================================
# 1. OIDC AUTH METHOD (Keycloak)
# =============================================================================
echo ">>> Enabling OIDC auth method..."
vault auth enable oidc || echo "OIDC already enabled, skipping."

echo ">>> Configuring OIDC with Keycloak..."
vault write auth/oidc/config \
  oidc_discovery_url="http://192.168.2.89:8080/realms/corp" \
  oidc_client_id="vault" \
  oidc_client_secret="${VAULT_CLIENT_SECRET}" \
  default_role="default"

echo ">>> Creating OIDC default role..."
vault write auth/oidc/role/default \
  bound_audiences="vault" \
  allowed_redirect_uris="http://192.168.2.89:8200/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="sub" \
  groups_claim="groups" \
  token_policies="default" \
  ttl="1h"

# =============================================================================
# 2. SSH SECRETS ENGINE (OTP mode)
# =============================================================================
echo ">>> Enabling SSH secrets engine..."
vault secrets enable ssh || echo "SSH secrets engine already enabled, skipping."

echo ">>> Creating SSH OTP role..."
vault write ssh/roles/otp-role \
  key_type=otp \
  default_user=ubuntu \
  cidr_list=0.0.0.0/0 \
  ttl=300

# =============================================================================
# 3. POLICIES
# =============================================================================
echo ">>> Writing sysadmin policy..."
vault policy write sysadmin - <<POLICY
path "ssh/creds/otp-role" {
  capabilities = ["create", "update"]
}
path "ssh/roles/*" {
  capabilities = ["read", "list"]
}
path "secret/*" {
  capabilities = ["read", "list"]
}
POLICY

echo ">>> Writing devops policy..."
vault policy write devops - <<POLICY
path "ssh/creds/otp-role" {
  capabilities = ["create", "update"]
}
path "ssh/roles/otp-role" {
  capabilities = ["read"]
}
POLICY

echo ">>> Writing readonly policy..."
vault policy write readonly - <<POLICY
path "secret/*" {
  capabilities = ["read", "list"]
}
POLICY

# =============================================================================
# 4. GROUP → POLICY MAPPING
# =============================================================================
echo ">>> Creating identity groups..."

vault write identity/group \
  name="sysadmin" \
  type="external" \
  policies="sysadmin"

vault write identity/group \
  name="devops" \
  type="external" \
  policies="devops"

vault write identity/group \
  name="readonly" \
  type="external" \
  policies="readonly"

echo ">>> Vault initialization complete."