terraform {
  # Supply bucket, key, and region at `terraform init` time. See README.md.
  backend "s3" {
    use_lockfile = true
  }
}
