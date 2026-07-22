output "tf_test01_ipv4" {
  description = "Static IPv4 address assigned to tf-test01 via cloud-init (not agent-reported — see main.tf's agent block comment)"
  value       = var.vm_ip
}
