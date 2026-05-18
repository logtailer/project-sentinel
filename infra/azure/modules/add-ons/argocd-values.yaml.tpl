server:
  ingress:
    enabled: true
    ingressClassName: webapprouting.kubernetes.azure.com
    hostname: ${argocd_hostname}
    tls: true
    annotations:
      kubernetes.io/tls-acme: "true"

configs:
  params:
    server.insecure: false

  cm:
    url: "https://${argocd_hostname}"
    exec.enabled: "false"
    accounts.image-updater: apiKey

  rbac:
    policy.default: role:readonly
    policy.csv: |
      p, role:org-admin, applications, *, */*, allow
      p, role:org-admin, clusters, get, *, allow
      p, role:org-admin, repositories, *, *, allow
      g, platform-team, role:org-admin
