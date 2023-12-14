locals {
  empty_license = ""
  # Reading Vault license file, if it does not exists, OSS Vault will be used 
  #license = fileexists("../${path.root}/vault_license.hclic") ? file("../${path.root}/vault_license.hclic") : local.empty_license
  license = fileexists("${path.root}/vault_license.hclic") ? file("${path.root}/vault_license.hclic") : local.empty_license

  # Find the packages: sudo yum search  --showduplicates vault-enterprise
  vault_version= "vault-enterprise-hsm-1.15.2+ent-1"
  #vault_version= "vault-enterprise-hsm-1.14.5+ent-1"
  #vault_version= "vault-enterprise-hsm-1.7.7+ent-1"
  #vault_version= "vault-enterprise-hsm-1.15.0+ent-1"
  #vault_version= "vault-enterprise-hsm-1.14.3+ent-1"
  #vault_version= "vault-enterprise-hsm-1.10.0+ent-1"
}

