# Terraform GCP Web App Infrastructure

A practice project for learning Terraform by provisioning a small, self-contained web app stack on Google Cloud Platform (GCP).

## What This Deploys

Running this project creates:

- **Compute Engine VM** (`web-app-server`) — a `debian-11` instance (`e2-medium`) with a startup script that serves a simple "Hello from Terraform" page on port 80.
- **HTTP Health Check** (`app-http-health-check`) — checks `/` on the VM every 5 seconds to confirm it's healthy.
- **Target Pool** (`app-target-pool`) — groups the VM instance and attaches the health check.
- **External Load Balancer** (`app-lb-forwarding-rule`) — a network load balancer with an external IP that forwards port 80 traffic to the target pool.
- **GCS Bucket** (`<project_id>-app-assets-bucket`) — a standard storage bucket with uniform bucket-level access.
- **Service Account** (`app-instance-sa`) — attached to the VM, granted `roles/storage.objectViewer` on the bucket above (nothing more).

**Output:** the external IP address of the load balancer, so you can immediately curl/browse it once resources finish provisioning.

> This project was built to practice core Terraform + GCP concepts (providers, resources, IAM, outputs, variables) — it's not hardened for production use.

## Repository Structure

```
.
├── main.tf              # All resources, provider config, and variable declarations
├── variables.tf          # (if kept separate) variable declarations — no secrets, safe to commit
├── terraform.tfvars      # YOU CREATE THIS — holds your actual project_id (gitignored, not committed)
├── .gitignore            # Ignores *.tfvars and *.auto.tfvars
└── README.md
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.0`
- A GCP project with billing enabled
- The following APIs enabled on your GCP project:
  - Compute Engine API
  - Cloud Storage API
  - IAM API
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated with credentials Terraform can use:
  ```bash
  gcloud auth application-default login
  ```

## Setup

### 1. Clone the repo

```bash
git clone <your-repo-url>
cd <your-repo-folder>
```

### 2. Create your `terraform.tfvars` file

This project requires your GCP `project_id`, which is treated as sensitive and is **not** committed to git. Create a file named `terraform.tfvars` in the project root:

```hcl
project_id = "your-actual-gcp-project-id"

# Optional — defaults are already set in the variable declarations,
# only override if you want a different region/zone
# region = "us-central1"
# zone   = "us-central1-a"
```

`terraform.tfvars` (and any `*.auto.tfvars` file) is automatically picked up by Terraform and is listed in `.gitignore`, so it will never be committed.

> ⚠️ Don't rename this file's extension away from `.tfvars` — Terraform only auto-loads variable *values* from files with that exact naming pattern. It should only contain `key = value` pairs, not `variable` block declarations.

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the plan

```bash
terraform plan
```

### 5. Apply

```bash
terraform apply
```

Confirm with `yes` when prompted. Once complete, Terraform will print the load balancer's external IP:

```
Outputs:

load_balancer_ip = "<external-ip>"
```

### 6. Test it

Give the load balancer/health check a minute to register the instance as healthy, then:

```bash
curl http://<load_balancer_ip>
```

You should see:

```
Hello from Terraform
```

## Cleaning Up

To avoid ongoing GCP charges, destroy all resources when you're done:

```bash
terraform destroy
```

## Notes

- The service account follows least-privilege: it only has `storage.objectViewer` on the specific bucket created here, not project-wide access.
- The GCS bucket has `prevent_destroy = false`, so `terraform destroy` will remove it along with everything else.
- `project_id` has no default and **must** be supplied via `terraform.tfvars` — Terraform will prompt for it interactively if the file is missing.
- The useage of dot notation like 'google_storage_bucket.app_storage.name' and 'google_compute_forwarding_rule.lb_frontend.ip_address' to reference resource even if there are not yet created.
