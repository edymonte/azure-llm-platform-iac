project_name         = "azllm"
environment          = "dev"
location             = "East US"
resource_group_name  = "rg-azllm-tfstate-dev"
storage_account_name = "stazllmtfdev"
blob_container_name  = "tfstate"

tags = {
  environment = "dev"
  project     = "azure-llm-platform"
  managed_by  = "terraform"
  workload    = "terraform-backend"
}
