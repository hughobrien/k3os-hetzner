Supports [multi-master](https://rancher.com/docs/k3s/latest/en/installation/ha-embedded/)
```
nbg1-liberal-worm [~]$ kubectl get nodes -o wide
NAME                 STATUS   ROLES    AGE   VERSION        INTERNAL-IP   EXTERNAL-IP      OS-IMAGE      KERNEL-VERSION     CONTAINER-RUNTIME
nbg1-outgoing-teal   Ready    master   88s   v1.17.2+k3s1   10.0.0.4      94.130.xxx.xxx    k3OS v0.9.1   5.0.0-37-generic   containerd://1.3.3-k3s1
nbg1-tops-fawn       Ready    master   84s   v1.17.2+k3s1   10.0.0.3      88.198.xxx.xxx    k3OS v0.9.1   5.0.0-37-generic   containerd://1.3.3-k3s1
nbg1-liberal-worm    Ready    master   97s   v1.17.2+k3s1   10.0.0.2      116.203.xxx.xxx   k3OS v0.9.1   5.0.0-37-generic   containerd://1.3.3-k3s1
```

# Cluster Setup
1. Get [Terraform](https://www.terraform.io/downloads.html)
1. Get [ShellCheck](https://www.shellcheck.net/)
1. Get [shfmt](https://github.com/mvdan/sh)
1. Open a [Hetzner account](https://www.hetzner.com/).
1. Generate a Hetzner token: `https://console.hetzner.cloud/projects/<your project ID>/access/tokens`
	1. Save it as `secrets/hetzner-token`
1. Generate an SSH key. Use a damn password. `ssh-keygen -t ed25519 -f secrets/ssh-terraform`
	1. Add it to your SSH agent `ssh-add secrets/ssh-terraform`
1. Optional: If you want to store the K3OS ISO/install script somewhere (like B2 or S3) you can specify the URL prefix in `secrets/hosting`.
	1. If you do not specify this, it will pull from GitHub which may be slow, or broken, or compromised.
	1. The provided link must be publicly accessible.
1. Optional: Modify `terraform.tfvars` to put one node in each Hetzner location. Must be an odd number of total nodes.
1. `./check.sh`
1. `./build.sh`
1. Screw up? `destroy=1 ./build.sh`

# Registry Setup
*You can avoid all of this by using one of the many commercial container registry services*
That said, [Backblaze](https://www.backblaze.com/b2/cloud-storage.html) is comically cheap, and with a little setup can store our images.

1. Get [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
1. Get a Backblaze account.
	1. Enable B2
	1. Create a bucket
	1. Generate an application key
	1. Make a K8s secret with the above info:
		`kubectl create secret generic --dry-run --output yaml b2 --from-literal=key_id='<your key_id>' --from-literal=application_key='<your app key>' > secrets/b2.yaml`
		Be sure to single quote escape the key to prevent your shell getting notions.

# Provisioning # TODO need for longhorn?
1. `./provision-post.sh <the IP of ONE of your nodes>`
	1. Adds your B2 secret
	1. Adds a [minio](https://hub.docker.com/r/minio/minio) deployment, configured to front [b2 as s3](https://github.com/minio/minio/blob/master/docs/gateway/b2.md)
	#1. Adds [Longhorn](https://github.com/longhorn/longhorn/releases)
