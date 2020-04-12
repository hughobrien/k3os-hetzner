# Kubernetes on Hetzner - k3s - €3 per month

code works, readme is work-in-progress

Features:
	- Terraform to provision nodes
	- Hetzner rescue mode abused to install k3s
	- Lets encrypt / certmanager for on-demand TLS certs
	- Built in docker registry
	- Client TLS certificates (mutual-TLS) used to expose sensitive apps
	- K8s API / kubectl access also guarded by nginx client certs
	- Auto-generate kubeconfig for local interaction
	- Auto-generate docker credentials
	- Prometheus with full service auto discovery
	- Longhorn for replicated persisted volumes
	- Cute server names auto-generated
	- Single master setup with option for highly-available master
	- Optional floating IPs
	- Optional external volumes
	- Secret/Cert backup
	- Code pre-checks
	- Provide your own k3s ISO / script
	- As many worker nodes as you like
	- Argo workflows
	- Argo CD

- [k3OS](https://github.com/rancher/k3os)
- [multi-master](https://rancher.com/docs/k3s/latest/en/installation/ha-embedded/)

References to 'k3s.hughobrien.ie' are hard coded in several places, be sure to adjust those accordingly.

# Cluster Setup
1. Get [Terraform](https://www.terraform.io/downloads.html)
1. Get [ShellCheck](https://www.shellcheck.net/)
1. Get [shfmt](https://github.com/mvdan/sh)
1. Get [yamllint](https://pypi.org/project/yamllint/)
1. Get [jq](https://stedolan.github.io/jq/)
1. Get [yq](https://pypi.org/project/yq/)
1. Get [openssl](https://www.openssl.org/)
1. Get [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
1. Get [apache](https://httpd.apache.org/) (to create docker registry htpasswd file)
1. Open a [Hetzner account](https://www.hetzner.com/).
1. Generate a Hetzner token: `https://console.hetzner.cloud/projects/<your project ID>/access/tokens`
	1. Save it as `secrets/hetzner-token`
1. Generate an SSH key. Use a damn password. `ssh-keygen -t ed25519 -f secrets/ssh-terraform`
	1. Add it to your SSH agent `ssh-add secrets/ssh-terraform`
1. Optional: If you want to store the K3OS ISO/install script somewhere (like B2 or S3) you can specify the URL prefix in `secrets/hosting`.
	1. If you do not specify this, it will pull from GitHub which may be slow, or broken, or compromised.
	1. The provided link must be publicly accessible.
1. Modify `terraform.tfvars`
1. `./build.sh`
1. Screw up? `destroy=1 ./build.sh`
1. Instructions for next steps are shown after build, CREATE THE DNS ENTRIES!
1. Install the `client.p12` browser certificate before attempting to access the services.
1. ./configure-remote.sh -  sets up local `kubectl` with protections
1. ./configure-local.sh  -  sets up remaining services
