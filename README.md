# Kubernetes on Hetzner - k3s - €3 per month

code works, readme is work-in-progress

- €3 for small single node
- €15 for small master node + 2x medium worker nodes (default)

# Features
- [k3OS](https://github.com/rancher/k3os)
- Terraform to provision nodes
- Hetzner rescue mode abused to install k3s
- Lets encrypt / certmanager for on-demand TLS certs
- Built in docker registry
- Client TLS certificates (mutual-TLS) used to expose sensitive apps
	- Supported by all major browsers, desktop & mobile
- K8s API / kubectl access also guarded by nginx client certs
- Auto-generate kubeconfig for local interaction
- Auto-generate docker credentials
- Prometheus with full service auto discovery
- Longhorn for replicated persisted volumes
- Argo workflows
- Argo CD
- Cute server names auto-generated
- Single master setup with option for highly-available master
- Optional floating IPs
- Optional external volumes
- Secret/Cert backup
- Code pre-checks
- Provide your own k3s ISO / script
- As many worker nodes as you like

**References to 'k3s.hughobrien.ie' are hard coded in several places, be sure to adjust those accordingly.**
```
find . -type f -iname '*.yaml' -or -iname '*.tf' -or -iname '*.sh' | xargs -n 1 sed -i 's/hughobrien\.ie/foo\.app/g'
```

# Cluster Setup
1. Get: [Terraform](https://www.terraform.io/downloads.html), [ShellCheck](https://www.shellcheck.net/), [shfmt](https://github.com/mvdan/sh), [yamllint](https://pypi.org/project/yamllint/), [jq](https://stedolan.github.io/jq/), [yq](https://pypi.org/project/yq/), [openssl](https://www.openssl.org/), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), [apache](https://httpd.apache.org/)
1. Open a [Hetzner account](https://www.hetzner.com/).
1. Generate a Hetzner token: `https://console.hetzner.cloud/projects/<your project ID>/access/tokens`
	1. Save it as `secrets/hetzner-token`
1. Generate an SSH key. Use a damn password. `ssh-keygen -t ed25519 -f secrets/ssh-terraform`
	1. Add it to your SSH agent `ssh-add secrets/ssh-terraform`
1. Optional: If you want to store the K3OS ISO/install script somewhere (like B2 or S3) you can specify the URL prefix in `secrets/hosting`.
	1. If you do not specify this, it will pull from GitHub which may be slow, or broken, or compromised.
	1. The provided link must be publicly accessible.
1. Modify `terraform.tfvars`
	1. Set node count, location
1. `./build.sh`
1. Screw up? `destroy=1 ./build.sh`
1. Instructions for next steps are shown after build, CREATE THE DNS ENTRIES!
1. ./configure-remote.sh -  sets up local `kubectl` with protections
1. ./configure-local.sh  -  sets up remaining services
1. Install the `client.p12` browser certificate before attempting to access the services.
	1. Password is the FQDN
