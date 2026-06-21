# GitOps

ArgoCD manages everything in this directory. The root Application (`bootstrap/root-app.yaml`) is the only resource Terraform creates directly — it points ArgoCD at this repo and lets GitOps take over from there.

## Structure

```
gitops/
├── bootstrap/          # ArgoCD manages these directly (Helm apps + ApplicationSets)
│   ├── root-app.yaml           # Terraform creates this; it owns everything below
│   ├── app-*.yaml              # One Application per Helm chart (cert-manager, falco, etc.)
│   ├── applicationset-system.yaml    # Discovers gitops/apps/system/* as Applications
│   ├── applicationset-workloads.yaml # Discovers gitops/apps/workloads/* as Applications
│   └── applicationset-clusters.yaml  # Cluster generator — deploys monitoring to every registered cluster
│
├── apps/
│   ├── system/         # Plain YAML discovered by applicationset-system (Kyverno policies,
│   │                   #   PrometheusRules, StorageClass, Grafana dashboards, etc.)
│   └── workloads/      # Tenant workload Applications (one directory per team/app)
│
└── clusters/
    ├── dev/            # Dev cluster Helm values overrides
    └── prod/           # Prod cluster registration secret + Prometheus HA values
```

## Sync wave ordering

Sync waves control the order ArgoCD applies resources within a single sync operation. Higher waves wait for lower waves to be healthy before starting.

| Wave | What syncs |
|---|---|
| 0 | cert-manager, Kyverno, ESO — CRD providers that everything else depends on |
| 1 | Karpenter — needs ESO (wave 0) for secret availability |
| 2 | kube-prometheus-stack, Loki, Tempo, OTel, VPA, KEDA, Trivy, Falco, Kubecost, ArgoCD Image Updater |
| 3 | Kubecost — federated to Prometheus (wave 2), so must wait |

EC2NodeClass and NodePool (in `apps/system/karpenter/`) use wave 2 so the Karpenter CRDs (installed at wave 1) exist before the objects are applied.

## Adding a new system app (Helm chart)

1. Create `gitops/bootstrap/app-<name>.yaml` — an ArgoCD Application pointing at the chart
2. Set `argocd.argoproj.io/sync-wave` to the appropriate wave
3. Push — ArgoCD picks it up automatically via the root Application

## Adding a new plain-YAML resource

Drop a `.yaml` file anywhere under `gitops/apps/system/<existing-or-new-dir>/`. The `applicationset-system` ApplicationSet watches `gitops/apps/system/*` and creates an Application for each subdirectory. ArgoCD syncs it automatically.

## Adding a tenant workload

Create a directory under `gitops/apps/workloads/<team-name>/` with at minimum an ArgoCD Application manifest. The `applicationset-workloads` ApplicationSet discovers it and creates the Application. Combine with `gitops/tenants/<team-name>/` to trigger the namespace provisioner (Kyverno auto-creates RBAC, ResourceQuota, LimitRange, and NetworkPolicy for the namespace).
