# Problem Statement & Setup

## Problem Statement

Let's imagine that you run a company called `Wayne Enterprises`. This company runs two clusters: `Batcave` & `Batcomputer`. Each of these sites runs an instance of Prometheus that collects metrics data from applications and services running there.

However, these sites are special. For security reasons, they do not expose public endpoints to the Prometheus instances running there, and so cannot be accessed directly from other parts of your infrastructure.

As the person responsible for implementing monitoring these sites, you have two requirements to meet:

1. Implement a global view of this data. `Wayne Enterprises` needs to know what is happening in all parts of the company - including secret ones!
1. Global view must be queryable in near real-time. We can't afford any delay in monitoring these locations!

Firstly, let us setup two Prometheus instances...

## Setup

### Batcave

Let's use a very simple configuration file, that tells prometheus to scrape its own metrics page every 5 seconds.

Switch on to the Editor tab and make a `prometheus-batcave.yaml` file in editor folder and paste the above code in it.

```
global:
  scrape_interval: 5s
  external_labels:
    cluster: batcave
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9090']
```{{copy}}

Run the prometheus instance:

```
docker run -d --net=host --rm \
    -v /root/editor/prometheus-batcave.yaml:/etc/prometheus/prometheus.yaml \
    -v /root/prometheus-batcave-data:/prometheus \
    -u root \
    --name prometheus-batcave \
    quay.io/prometheus/prometheus:v2.38.0 \
    --config.file=/etc/prometheus/prometheus.yaml \
    --storage.tsdb.path=/prometheus \
    --web.listen-address=:9090 \
    --web.external-url={{TRAFFIC_HOST1_9090}} \
    --web.enable-lifecycle
```{{execute}}

Verify that `prometheus-batcave` is running by navigating to the [Batcave Prometheus UI]({{TRAFFIC_HOST1_9090}}/).

<details>
 <summary>Why do we enable the web lifecycle flag?</summary>

  By specifying `--web.enable-lifecycle`, we tell Prometheus to expose the `/-/reload` HTTP endpoint.

  This lets us tell Prometheus to dynamically reload its configuration, which will be useful later in this tutorial.
</details>


### Batcomputer

Almost exactly the same configuration as above, except we run the Prometheus instance on port `9091`.

Switch on to the Editor tab and make a `prometheus-batcomputer.yaml` file in editor folder and paste the above code in it.

```
global:
  scrape_interval: 5s
  external_labels:
    cluster: batcomputer
    replica: 0

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9091']
```{{copy}}

```
docker run -d --net=host --rm \
    -v /root/editor/prometheus-batcomputer.yaml:/etc/prometheus/prometheus.yaml \
    -v /root/prometheus-batcomputer:/prometheus \
    -u root \
    --name prometheus-batcomputer \
    quay.io/prometheus/prometheus:v2.38.0 \
    --config.file=/etc/prometheus/prometheus.yaml \
    --storage.tsdb.path=/prometheus \
    --web.listen-address=:9091 \
    --web.external-url=https://2886795291-9091-elsy05 \
    --web.enable-lifecycle
```{{execute}}

Verify that `prometheus-batcomputer` is running by navigating to the [Batcomputer Prometheus UI]({{TRAFFIC_HOST1_9091}}/).

With these Prometheus instances configured and running, we can now start to architect our global view of all of `Wayne Enterprises`.
