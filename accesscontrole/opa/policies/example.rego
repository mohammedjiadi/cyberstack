package network.authz

import future.keywords.if
import future.keywords.in

# =============================================================================
# JIADI — OPA Authorization Policy
# =============================================================================
# Input schema expected:
# {
#   "input": {
#     "user": {
#       "name": "john.doe",
#       "groups": ["devops"]
#     },
#     "resource": {
#       "protocol": "ssh",      # ssh | rdp | vnc
#       "host":     "10.0.1.5",
#       "os":       "linux"     # linux | windows
#     }
#   }
# }
# =============================================================================

# Default deny everything
default allow := false

# =============================================================================
# RULE 1 — sysadmin: full access, all protocols, all hosts, any time
# =============================================================================
allow if {
    "sysadmin" in input.user.groups
}

# =============================================================================
# RULE 2 — devops: SSH to Linux servers, business hours only
# =============================================================================
allow if {
    "devops" in input.user.groups
    input.resource.protocol == "ssh"
    input.resource.os == "linux"
    business_hours
}

# =============================================================================
# RULE 3 — devops: RDP to Windows servers, business hours only
# =============================================================================
allow if {
    "devops" in input.user.groups
    input.resource.protocol == "rdp"
    input.resource.os == "windows"
    business_hours
}

# =============================================================================
# RULE 4 — readonly: VNC view-only sessions, business hours only
# =============================================================================
allow if {
    "readonly" in input.user.groups
    input.resource.protocol == "vnc"
    business_hours
}

# =============================================================================
# HELPER — Business hours: Monday–Friday, 08:00–18:00 UTC+1
# =============================================================================
business_hours if {
    now    := time.now_ns()
    # Offset to UTC+1 (3600000000000 ns)
    local  := now + 3600000000000
    hour   := time.clock([local, "Africa/Casablanca"])[0]
    day    := time.weekday(local)
    hour   >= 8
    hour   < 18
    day    != "Saturday"
    day    != "Sunday"
}

# =============================================================================
# HELPER — Deny reasons (useful for debugging)
# =============================================================================
deny_reason := "outside business hours" if {
    not business_hours
    "devops" in input.user.groups
}

deny_reason := "protocol not allowed for group" if {
    "readonly" in input.user.groups
    input.resource.protocol != "vnc"
}

deny_reason := "unknown group" if {
    not "sysadmin" in input.user.groups
    not "devops"   in input.user.groups
    not "readonly" in input.user.groups
}
