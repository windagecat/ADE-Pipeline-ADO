locals {
  subscription_id = "<サブスクリプションID>"      #サブスクリプションIDを記入
  ado_orz         = "<ADOのorgnization名>" #ADOのorgnization名を記入
  devcenter = {
    devcenter_name     = "<Dev Center名>"           # Dev Center名を記入
    devcenter_endpoint = "<Dev Center Endpoint>"   # Dev Center Endpointを記入　例）xxxxxxx-testdevcenter.japaneast.devcenter.azure.com
    devcenter_rg       = "<Dev Center のリソースグループ名>" # Dev Center のリソースグループ名を記入
    devcenter_catalog  = "<Dev Center のカタログ名>"     # Dev Center上でインポートしたカタログ名を記入
  }
  vnet_cidr = "10.1.0.0/16"
  mdp_subnets = [
    # 10.1.0.0/28 10.1.0.16/28 10.1.0.32/28 10.1.0.48/28 10.1.0.64/28
    {
      subnet_address = "10.1.0.0/28"
      ado_pj_name    = "<ADOのプロジェクト名>"         #ADOのプロジェクト名を記入
      ado_repo_name  = "<ADOプロジェクトのgitリポジトリ名>" #インポートしたADOプロジェクトのgitリポジトリ名を記入
      devc_pj_name   = "<Dev Center のプロジェクト名>" #Dev Center のプロジェクト名を記入
    },
  ]
  managed_subnets = [
    {
      name           = "AzureBastionSubnet"
      subnet_address = "10.1.2.0/26"
    },
    {
      name           = "GatewaySubnet"
      subnet_address = "10.1.1.160/27"
    },
    {
      name           = "AzureFirewallSubnet"
      subnet_address = "10.1.1.64/26"
    },
  ]
}
