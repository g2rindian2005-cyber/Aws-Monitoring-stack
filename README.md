# AWS Infrastructure Monitoring Project

End-to-end monitoring for **EC2, RDS, ALB, EKS, and Lambda** using **CloudWatch + SNS** (native AWS alerting)
and **Prometheus + Grafana** (unified dashboards / cross-service visibility).

```
aws-monitoring-project/
├── terraform/                  # CloudWatch alarms + SNS topic (IaC)
├── prometheus/                 # Prometheus, Alertmanager, CloudWatch exporter configs
├── grafana/                    # Dashboards + datasource provisioning
├── kubernetes/                 # Helm values + manifests to run the stack on EKS
├── docker-compose.yml          # Quick standalone deployment (e.g. on one EC2 host)
└── scripts/deploy.sh           # Automation script
```

## Architecture

```
 EC2 / RDS / ALB / Lambda / EKS
            │
            ├──> CloudWatch Metrics ──> CloudWatch Alarms ──> SNS Topic ──> Email/Slack/PagerDuty
            │                                                     ▲
            └──> CloudWatch Exporter ──> Prometheus ──> Alertmanager ──┘ (webhook forwarder)
                                              │
                                              ▼
                                          Grafana Dashboards
```

Two alerting paths are wired up on purpose: **CloudWatch Alarms → SNS** is the simplest, most
reliable path (use this alone if you just want alerts). **Prometheus/Grafana** layers on top for
richer dashboards, EKS pod-level metrics, and a single pane of glass across services.

---

## Prerequisites

Install these on your local machine / bastion before starting:

| Tool | Purpose | Install |
|---|---|---|
| AWS CLI v2 | Auth + resource IDs | `https://aws.amazon.com/cli/` |
| Terraform >= 1.5 | Provision CloudWatch alarms + SNS | `https://developer.hashicorp.com/terraform/install` |
| Docker + Docker Compose | Run Prometheus/Grafana stack | `https://docs.docker.com/get-docker/` |
| kubectl + helm (only if using EKS) | Deploy monitoring stack into your cluster | `https://helm.sh/docs/intro/install/` |

Run `aws configure` and confirm access:
```bash
aws sts get-caller-identity
```

---

## Step 1 — Gather your resource IDs

You need these before configuring anything:

```bash
# EC2 instance IDs
aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output table

# RDS instance identifiers
aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" --output table

# ALB ARN suffix (format: app/<name>/<id> — used by CloudWatch, not the full ARN)
aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output table
# then strip everything before "app/" from the ARN, e.g.:
#   arn:aws:elasticloadbalancing:us-east-1:123456789012:app/my-alb/50dc6c495c0c9188
#   -> app/my-alb/50dc6c495c0c9188

# Lambda function names
aws lambda list-functions --query "Functions[].FunctionName" --output table

# EKS cluster name
aws eks list-clusters --output table
```

---

## Step 2 — Deploy CloudWatch Alarms + SNS (Terraform)

This creates the 4 required alerts (EC2 CPU > 80%, RDS storage low, ALB 5xx errors, instance down)
plus Lambda error/throttle alarms, all wired to a single SNS topic.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with the IDs you gathered in Step 1 and your alert email

terraform init
terraform validate
terraform plan
terraform apply
```

**Critical step:** after `apply`, check your email for a message from AWS Notifications and click
**"Confirm subscription"**. Until you do this, SNS will silently drop every alert.

Verify:
```bash
terraform output sns_topic_arn
terraform output dashboard_url     # opens a native CloudWatch dashboard
```

To test an alarm fires end-to-end, temporarily lower a threshold (e.g. `ec2_cpu_threshold = 1`),
re-apply, wait for the alarm to trigger, confirm you get the email, then set it back.

---

## Step 3 — Deploy Prometheus + Grafana

You have two options — pick based on where you want the dashboards running.

### Option A: Standalone (single EC2 host / local Docker) — fastest to stand up

```bash
cd .. # back to project root
docker compose config          # validates the compose file first
docker compose up -d
```

Access:
- Prometheus: `http://<host>:9090`
- Alertmanager: `http://<host>:9093`
- Grafana: `http://<host>:3000` (login `admin` / `changeme123!` — **change this password immediately** in `docker-compose.yml` before deploying, or override with an env var)

The CloudWatch exporter container needs AWS credentials. On an EC2 host, attach an **IAM instance
profile** with the policy in `terraform/iam-cloudwatch-readonly-policy.json` — do not hardcode keys.

### Option B: Inside your EKS cluster (recommended if you're already monitoring EKS workloads)

```bash
kubectl apply -f kubernetes/namespace.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f kubernetes/prometheus-values.yaml

kubectl apply -f kubernetes/cloudwatch-exporter.yaml
```

Before applying `cloudwatch-exporter.yaml`, set up IRSA so the exporter can call CloudWatch:
```bash
eksctl create iamserviceaccount \
  --name cloudwatch-exporter-sa \
  --namespace monitoring \
  --cluster <your-eks-cluster-name> \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/cloudwatch-exporter-readonly \
  --approve
```
(Create that IAM policy from `terraform/iam-cloudwatch-readonly-policy.json` first via
`aws iam create-policy --policy-name cloudwatch-exporter-readonly --policy-document file://terraform/iam-cloudwatch-readonly-policy.json`.)

Port-forward to check Grafana without exposing it publicly yet:
```bash
kubectl -n monitoring port-forward svc/kube-prom-stack-grafana 3000:80
```

---

## Step 4 — Load the dashboard

If using Docker Compose, the dashboard in `grafana/dashboards/aws-overview-dashboard.json` is
auto-provisioned — it will already appear under **AWS Infrastructure** in Grafana on first login.

If using Helm/EKS, import it manually the first time:
1. Grafana → Dashboards → New → Import
2. Upload `grafana/dashboards/aws-overview-dashboard.json`
3. Select the `Prometheus` datasource when prompted

It includes panels for: EC2 CPU, RDS free storage, ALB 5xx rate, Lambda error rate, instance up/down count, and EKS pod restarts.

---

## Step 5 — Connect Alertmanager to SNS (optional, only if using Prometheus alerting too)

`prometheus/alertmanager.yml` is pre-configured to POST to a webhook (`sns-forwarder`). The
simplest way to implement that forwarder is a tiny Lambda + API Gateway that takes the Alertmanager
webhook payload and calls `sns:Publish` on the topic ARN from Step 2's `terraform output sns_topic_arn`.
If you'd rather skip this, that's fine — CloudWatch Alarms already send to SNS independently in Step 2, so you have working alerting either way.

---

## Verifying everything end-to-end

1. **EC2 CPU alarm**: SSH into an instance and run `stress --cpu 4 --timeout 600` (install via `sudo yum install -y stress` or `apt install -y stress`) to push CPU over 80% and confirm the alarm + email fire.
2. **RDS storage**: check `terraform output` / CloudWatch console shows current `FreeStorageSpace`; lower the threshold temporarily to test the alarm path without waiting for real disk pressure.
3. **ALB 5xx**: hit a route that returns 500s (or temporarily break a health check) and confirm the alarm fires within ~2 minutes.
4. **Instance down**: stop an EC2 instance (in a non-prod env!) and confirm `StatusCheckFailed` alarm fires within ~3 minutes.
5. **Grafana**: confirm all panels show data (not "No data") within a few minutes of the stack starting.

---

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `Error: no valid credential sources found` (terraform) | AWS CLI not configured | Run `aws configure` or set `AWS_PROFILE` |
| No emails received despite alarms in ALARM state | SNS subscription not confirmed | Check spam folder, re-run `terraform output sns_topic_arn`, resend confirmation via SNS console |
| Grafana panels show "No data" | CloudWatch exporter can't reach AWS | Check exporter logs: `docker compose logs cloudwatch-exporter` — usually missing/incorrect IAM permissions |
| `AccessDenied` from cloudwatch-exporter | IAM role missing permissions | Attach the policy in `terraform/iam-cloudwatch-readonly-policy.json` |
| Terraform `for_each` errors on empty list | `ec2_instance_ids` etc. left as `[]` | Fill in real resource IDs in `terraform.tfvars` |
| ALB panel empty | Wrong `alb_arn_suffix` format | Must be `app/<name>/<id>`, not the full ARN |
| Docker Compose port already in use | Another service on 3000/9090 | Change the left-hand port mapping in `docker-compose.yml`, e.g. `3001:3000` |  



---

## Security notes before going to production

- Change the Grafana admin password (`docker-compose.yml` / Helm values) — do not ship the defaults in this repo.
- Restrict Grafana/Prometheus access with a security group, VPN, or put them behind an authenticating reverse proxy — don't expose ports 3000/9090 to `0.0.0.0/0`.
- Use an IAM role (instance profile or IRSA), never long-lived access keys, for the CloudWatch exporter.
- Consider AWS Managed Grafana / Amazon Managed Prometheus if you'd rather not operate this stack yourself.

-      ########################## project explaination ###############################################################################
-
-
-         "I worked on an AWS Infrastructure Monitoring project where the goal was to monitor the health and performance of AWS resources and Linux servers in real time.

The monitoring stack was containerized using Docker Compose and deployed on an Amazon EC2 instance. I used Prometheus as the monitoring system, Grafana for visualization, Alertmanager for notifications, Node Exporter to collect Linux server metrics, and CloudWatch Exporter to collect AWS CloudWatch metrics."  




  ################################################# explain you role ################################################

  Explain your role

Answer:

"My responsibility was to deploy and configure the complete monitoring stack.

I created the infrastructure using Terraform, deployed the monitoring tools using Docker Compose, configured Prometheus to scrape metrics from Node Exporter and CloudWatch Exporter, connected Prometheus to Grafana for visualization, and configured Alertmanager to send email notifications through Amazon SNS whenever predefined thresholds were crossed."
