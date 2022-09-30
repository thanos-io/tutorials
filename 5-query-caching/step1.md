
## Simple observability stack with Prometheus and Thanos

> NOTE: Click `Copy To Editor` for each config to propagate the configs to each file.

Let's imagine we have to deliver centralized metrics platform to multiple teams. For each team we will have a dedicated Prometheus. These could be in the same environment or in different environments (data centers, regions, clusters etc).

And then we will try to provide low cost, fast global overview. Let's see how we achieve that with Thanos.

## Let's lay the ground work

Let's quickly deploy Prometheuses with sidecars and Querier.

Execute following commands to setup Prometheus:

### Prepare "persistent volumes" for Prometheuses

```
mkdir -p prometheus_data
```{{execute}}

### Deploy Prometheus

Let's deploy a couple of Prometheus instances and let them scrape themselves, so we can produce some metrics.

### Prepare configuration

Click on the box and it will get copied

First, Prometheus server that scrapes itself:

Switch on to the Editor tab and make a `prometheus0.yml` file in editor folder and paste the above code in it.

```
global:
  scrape_interval: 5s
  external_labels:
    cluster: eu0
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9090']
```{{copy}}

In Editor tab and make a `prometheus1.yml` file in editor folder and paste the above code in it.

```
global:
  scrape_interval: 5s
  external_labels:
    cluster: eu1
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9091']
```{{copy}}

In Editor tab and make a `prometheus2.yml` file in editor folder and paste the above code in it.

```
global:
  scrape_interval: 5s
  external_labels:
    cluster: eu2
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9092']
```{{copy}} 

### Deploy Prometheus

```
for i in $(seq 0 2); do
docker run -d --net=host --rm \
    -v $(pwd)/prometheus"${i}".yml:/etc/prometheus/prometheus.yml \
    -v $(pwd)/prometheus_data:/prometheus"${i}" \
    -u root \
    --name prometheus"${i}" \
    quay.io/prometheus/prometheus:v2.38.0 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.listen-address=:909"${i}" \
    --web.external-url={{TRAFFIC_HOST1_909"${i}"}} \
    --web.enable-lifecycle \
    --web.enable-admin-api && echo "Prometheus ${i} started!"
done
```{{execute}}

#### Verify

Let's check if all of Prometheuses are running!

```
docker ps
```{{execute}}

### Inject Thanos Sidecars

```
for i in $(seq 0 2); do
docker run -d --net=host --rm \
    -v $(pwd)/prometheus"${i}".yml:/etc/prometheus/prometheus.yml \
    --name prometheus-sidecar"${i}" \
    -u root \
    quay.io/thanos/thanos:v0.28.0 \
    sidecar \
    --http-address=0.0.0.0:1909"${i}" \
    --grpc-address=0.0.0.0:1919"${i}" \
    --reloader.config-file=/etc/prometheus/prometheus.yml \
    --prometheus.url=http://172.17.0.1:909"${i}" && echo "Started Thanos Sidecar for Prometheus ${i}!"
done
```{{execute}}

#### Verify

Let's check if all of Thanos Sidecars are running!

```
docker ps
```{{execute}}

## Prepare Thanos Global View

And now, let's deploy Thanos Querier to have a global overview on our services.

### Deploy Querier

```
docker run -d --net=host --rm \
    --name querier \
    quay.io/thanos/thanos:v0.28.0 \
    query \
    --http-address 0.0.0.0:10912 \
    --grpc-address 0.0.0.0:10901 \
    --query.replica-label replica \
    --store 172.17.0.1:19190 \
    --store 172.17.0.1:19191 \
    --store 172.17.0.1:19192 && echo "Started Thanos Querier!"
```{{execute}}

### Setup Verification

Once started you should be able to reach the Querier and Prometheus.

* [Prometheus]({{TRAFFIC_HOST1_9090}}/)
* [Querier]({{TRAFFIC_HOST1_10912}}/)
