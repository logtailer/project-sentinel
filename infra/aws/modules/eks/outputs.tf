output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group.arn
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "kms_key_arn" {
  value = aws_kms_key.eks.arn
}

output "karpenter_controller_role_arn" {
  value = aws_iam_role.karpenter_controller.arn
}

output "karpenter_interruption_queue_name" {
  value = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_node_instance_profile_name" {
  value = aws_iam_instance_profile.karpenter_node.name
}
