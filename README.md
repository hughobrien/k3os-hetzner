Supports [multi-master](https://rancher.com/docs/k3s/latest/en/installation/ha-embedded/)
```
nbg1-liberal-worm [~]$ kubectl get nodes -o wide
NAME                 STATUS   ROLES    AGE   VERSION        INTERNAL-IP   EXTERNAL-IP      OS-IMAGE      KERNEL-VERSION     CONTAINER-RUNTIME
nbg1-outgoing-teal   Ready    master   88s   v1.17.2+k3s1   10.0.0.4      94.130.xxx.xxx    k3OS v0.9.1   5.0.0-37-generic   containerd://1.3.3-k3s1
nbg1-tops-fawn       Ready    master   84s   v1.17.2+k3s1   10.0.0.3      88.198.xxx.xxx    k3OS v0.9.1   5.0.0-37-generic   containerd://1.3.3-k3s1
nbg1-liberal-worm    Ready    master   97s   v1.17.2+k3s1   10.0.0.2      116.203.xxx.xxx   k3OS v0.9.1   5.0.0-37-generic   containerd://1.3.3-k3s1
```
