# weave-scope

## TL:DR Install

First time setup in a cluster? Run `./bootstrap.sh` with a ClusterAdmin role and local context pointing to your target cluster.

Set some variables:

```bash
export WEAVE_IMAGE_NAME="weaveworks/scope"
export WEAVE_IMAGE_VERSION="1.13.1"
export GCP_PROJECT_ID="your-project-id"
```

Build and tag to the project's GCR? `./build.sh`

Deploy the (re-)built images? `./deploy.sh`

Access Scope? `kubectl port-forward svc/weave-scope-app 4040:4040` then http://localhost:4040/.

## Background

I grabbed the combined manifest from here and pulled apart, refactoring to reduce permissions - see below:

```sh
curl -sLo weave.scope.yaml "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

[Source](https://github.com/weaveworks/). There is a paywall for advanced features like RBAC.

Applies into `weave` namespace. There is no CI currently as not decided whether to keep this running or not - but the pieces are there if needs be. it is super-privileged to get the `DaemonSet` working.

Once applied, `kubectl port-forward svc/weave-scope-app -n weave 4040:4040`, until auth is set up via an `Ingress`.

## Notes on Changes

Most changes revolved around trying to reduce privileges and playing nicely with `PodSecurityPolicy`.

- Weave Scope supports changing to a read-only mode with the command line switch `'--probe.no-controls=true'`. This is set for all three workloads to disable a user's ability to attempt to modify deployments/pods through the UI
- The `weave-scope-cluster-agent` makes calls to the Kubernetes API server to see things across many namespaces. We therefore tolerate a `ClusterRole` but reduce its privileges - removing its ability to update deployments and delete pods. Basically it should only have get/list/watch. This is a double layer of protection, as the changes above should mean it doesn't need these anyway
- We are expected to apply a very broad `PodSecurityPolicy`, largely born out of the pod running as root. We therefore rebuild the container from the upstream, but add a non-root user and group and have it run as this instead
  - This works fine for the `weave-scope-app` and `weave-scope-cluster-agent`, but not for the `weave-scope-agent` DaemonSet, which is mounting host paths and sniffing the host network
- With the above change, the app that the user hits (`weave-scope-app`) does not need any special permissions like this. We can therefore remove the named `serviceAccount` and let it pick up the default restrictive PSP
- The `DaemonSet` is a bit more of a challenge:
  - It does not work when you run as non-root
  - I was able to implement a read-only root FS
  - I was able to shrink down its syscaps to just `NET_BIND_SERVICE` however ...
  - ... whilst it starts with `privileged: false` and `allowPrivilegeEscalation: false`, the agent doesn't actually work, spamming `conntrack` errors into the log. I do not know if these settings supercede the syscaps above
  - I tried disabling `hostPID: true` and `hostNetwork: true`. It starts and appears to work, but you lose the connectivity between nodes on the graph. This is kinda the feature that's neatest, so I turned back on
  - I experimented a little with disabling its access to `hostPaths`:
    - I disabled its volume mount to `/sys/kernel/debug`. It whinged in the log, but this didn't seem to break any of the functionality I was interested in. I re-enabled it given the other privileges still necessary however
    - Unsurprisingly no such luck with the docker socket, which makes sense for how its discovering processes on each host
- I also moved things off port 80. Because that sort of thing just annoys me
