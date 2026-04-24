# ------------------------------------------------------------------------------
# 02-configuration — outputs (consumed by 03-server)
# ------------------------------------------------------------------------------

output "apim_id"             { value = local.apim_id }
output "apim_name"           { value = local.apim_name }
output "resource_group_name" { value = local.resource_group_name }
output "tenant_id"           { value = local.tenant_id }
output "subscription_id"     { value = local.subscription_id }
output "obo_client_app_id"   { value = local.obo_client_app_id }

output "fragments_deployed" {
  description = "List of deployed fragment names."
  value       = keys(local.policy_fragments)
}
