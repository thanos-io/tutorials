# Step 1 - Start initial Prometheus servers

Thanos is meant to scale and extend vanilla Prometheus. This means that you can gradually, without disruption, deploy Thanos on top of your existing Prometheus setup.

Let's start our tutorial by spinning up three Prometheus servers. Why three?
The real advantage of Thanos is when you need to scale out Prometheus from a single replica. Some reason for scale-out might be:

* Adding functional sharding because of metrics high cardinality
* Need for high availability of Prometheus e.g: Rolling upgrades
* Aggregating queries from multiple clusters

For this course, let's imagine the following situation:

![initial-case](https://docs.google.com/drawings/d/e/2PACX-1vQ5n5dAJSJPRXWA9INOViJJy9Ci6TUwlCrDv7_TtV9vE41rFOpg26V3jQv9gf1NQjVWSFyauG5XgzOW/pub?w=1061&h=604)

1. We have 1 Prometheus server in some `eu1` cluster.
2. We have 2 replica Prometheus servers in some `us1` cluster that scrapes the same targets.

Let's start this initial Prometheus setup for now.

## Prometheus Configuration Files

Now, we will prepare configuration files for all Prometheus instances.

Click on the box and it will get copied

Switch on to the Editor tab and make a `prometheus0_eu1.yml` file and paste the above code in it.

First, for the EU Prometheus server that scrapes itself:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: eu1
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9090']
```{{copy}}      


For the second cluster we set two replicas:

Make a `prometheus0_us1.yml` file and paste the above code in it.

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: us1
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9091','172.17.0.1:9092']
```{{copy}}


Make a `prometheus1_us1.yml` file and paste the above code in it.

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: us1
    replica: 1

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9091','172.17.0.1:9092']
```{{copy}}

**NOTE** : Every Prometheus instance must have a globally unique set of identifying labels. These labels are important as they represent certain "stream" of data (e.g in the form of TSDB blocks). Within those exact external labels, the compactions and downsampling are performed, Querier filters its store APIs, further sharding option, deduplication, and potential multi-tenancy capabilities are available. Those are not easy to edit retroactively, so it's important to provide a compatible set of external labels as in order to for Thanos to aggregate data across all the available instances.

## Starting Prometheus Instances

Let's now start three containers representing our three different Prometheus instances.

Please note the extra flags we're passing to Prometheus:

* `--web.enable-admin-api` allows Thanos Sidecar to get metadata from Prometheus like `external labels`.
* `--web.enable-lifecycle` allows Thanos Sidecar to reload Prometheus configuration and rule files if used.

Execute following commands:

### Prepare "persistent volumes"

```
mkdir -p prometheus0_eu1_data prometheus0_us1_data prometheus1_us1_data
```{{execute}}

### Deploying "EU1"

```
docker run -d --net=host --rm \
    -v $(pwd)/prometheus0_eu1.yml:/etc/prometheus/prometheus.yml \
    -v $(pwd)/prometheus0_eu1_data:/prometheus \
    -u root \
    --name prometheus-0-eu1 \
    quay.io/prometheus/prometheus:v3.13.5 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.listen-address=:9090 \
    --web.external-url={{TRAFFIC_HOST1_9090}} \
    --web.enable-lifecycle \
    --web.enable-admin-api && echo "Prometheus EU1 started!"
```{{execute}}

NOTE: We are using the latest Prometheus image so we can take profit from the latest remote read protocol.

### Deploying "US1"

```
docker run -d --net=host --rm \
    -v $(pwd)/prometheus0_us1.yml:/etc/prometheus/prometheus.yml \
    -v $(pwd)/prometheus0_us1_data:/prometheus \
    -u root \
    --name prometheus-0-us1 \
    quay.io/prometheus/prometheus:v3.13.5 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.listen-address=:9091 \
    --web.external-url={{TRAFFIC_HOST1_9091}} \
    --web.enable-lifecycle \
    --web.enable-admin-api && echo "Prometheus 0 US1 started!"
```{{execute}}

and

```
docker run -d --net=host --rm \
    -v $(pwd)/prometheus1_us1.yml:/etc/prometheus/prometheus.yml \
    -v $(pwd)/prometheus1_us1_data:/prometheus \
    -u root \
    --name prometheus-1-us1 \
    quay.io/prometheus/prometheus:v3.13.5 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.listen-address=:9092 \
    --web.external-url={{TRAFFIC_HOST1_9092}} \
    --web.enable-lifecycle \
    --web.enable-admin-api && echo "Prometheus 1 US1 started!"
```{{execute}}

## Setup Verification

Once started you should be able to reach all of those Prometheus instances:

* [Prometheus-0 EU1]({{TRAFFIC_HOST1_9090}}/)
* [Prometheus-1 US1]({{TRAFFIC_HOST1_9091}}/)
* [Prometheus-2 US1]({{TRAFFIC_HOST1_9092}}/)

## Additional info

Why would one need multiple Prometheus instances?

* High Availability (multiple replicas)
* Scaling ingestion: Functional Sharding
* Multi cluster/environment architecture

## Problem statement: Global view challenge

Let's try to play with this setup a bit. You are free to query any metrics, however, let's try to fetch some certain information from
our multi-cluster setup: **How many series (metrics) we collect overall on all Prometheus instances we have?**

Tip: Look for `prometheus_tsdb_head_series` metric.


<details>
<summary>Answer</summary>
Here, <code>prometheus_tsdb_head_series</code> is the current number of series in a Prometheus server's TSDB head. Each Prometheus server scrapes this metric from its configured targets, so the query results show one value per target.

Add the EU1 result to the US1 result to get the total across all three Prometheus TSDBs. Use only one US dashboard: both US servers scrape the same two targets, so either dashboard can provide the pair of US readings. Since scrapes happen at different times, the live values may differ slightly. Do not add the results from both US dashboards, or you will count the US replicas twice.

Because the US Prometheus servers are replicas scraping the same targets, this physical total counts the US data twice, once per replica. For a logical count with the US HA pair treated as one source, count only one US replica instead. Thanos Querier can provide that deduplicated view in the next step.

As you can see this is not very convenient for both human as well as automation on top of metrics (e.g Alerting).

The feature we are missing here is called **Global View** and it might be necessary once you scale out Prometheus to multiple instances.
</details>

## Next

Great! We now have 3 Prometheus instances.

In the next steps, we will learn how we can install Thanos on top of our initial Prometheus setup to solve problems shown in the challenge.
