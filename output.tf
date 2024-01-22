output "cblocaladmin" {
  value     = random_password.password.result
  sensitive = true
}