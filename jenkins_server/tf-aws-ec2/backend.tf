terraform {
  # Supply bucket, key, and region at `terraform init` time.
  backend "s3" {
    use_lockfile = true
  }
}
