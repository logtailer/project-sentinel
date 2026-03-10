output "node_remediation_function_arn" {
  value = aws_lambda_function.node_remediation.arn
}

output "scaling_advisor_function_arn" {
  value = aws_lambda_function.scaling_advisor.arn
}
