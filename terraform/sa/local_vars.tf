locals {
  subscription_id = "<サブスクリプションID>" #サブスクリプションIDを記入
  ado_orz         = "<ado名>"        #ADO名を記入
  devcenter = {
    devcenter_name     = "<Dev center名>"           # Dev center名を記入
    devcenter_endpoint = "<Dev center URI>"        # Dev center URIを記入
    devcenter_rg       = "<Dev center のリソースグループ名>" # Dev center のリソースグループ名を記入
    devcenter_catalog  = "<Dev center のカタログ名>"     # Dev center上でインポートしたカタログ名を記入
  }
  vnet_cidr = "10.1.0.0/16"
  mdp_subnets = [
    # 10.1.0.0/28 10.1.0.16/28 10.1.0.32/28 10.1.0.48/28 10.1.0.64/28
    {
      subnet_address = "10.1.0.0/28"
      ado_pj_name    = "<ADOのプロジェクト名>"         #ADOのプロジェクト名を記入
      ado_repo_name  = "<ADOプロジェクトのgitリポジトリ名>" #インポートしたADOプロジェクトのgitリポジトリ名を記入
      devc_pj_name   = "<Dev center のプロジェクト名>" #Dev center のプロジェクト名を記入
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
