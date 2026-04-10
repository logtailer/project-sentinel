module "fis" {
  source = "../../modules/fis"

  cluster_name    = local.cluster_name
  node_group_name = "${local.cluster_name}-general"
  tags            = local.common_tags
}
