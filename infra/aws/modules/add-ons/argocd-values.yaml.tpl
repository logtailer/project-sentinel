server:
  # TLS terminated at ALB — remove --insecure and add TLS cert in production
  extraArgs:
    - --insecure

configs:
  cm:
    url: "https://${argocd_hostname}"

    dex.config: |
      connectors:
        - type: github
          id: github
          name: GitHub
          config:
            clientID: ${oidc_client_id}
            clientSecret: $dex.github.clientSecret
            orgs:
              - name: ${github_org}

  rbac:
    policy.default: role:readonly
    policy.csv: |
      g, ${github_org}:platform-eng, role:admin
    scopes: "[groups]"

  secret:
    # Secret value is injected via set_sensitive in Terraform — never committed to Git
    createSecret: true
