What if we can have one single point of entry in front of Queries instead of separate Queriers? And by doing so slice and dice our queries depend on the time and distribute them between queriers to balance the load? Moreover, why not cache these responses so that next time someone asks for the same time range we can just serve it from memory. Wouldn't it be faster?

Yes, we can do all these using Thanos Query Frontend. Let's see how we can do it.

### First let's deploy a nginx proxy to simulate latency

We are running this tutorial on a single machine in this setup, as a result it's really hard to observe latencies that you would normally experience in a real-life setups. In order to simulate a real-life latency we are going to put a proxy in front of our Thanos Querier.

For that let's setup a nginx instance:

In Editor tab and make a `nginx.conf` file in editor folder and paste the above code in it.

```
server {
 listen 10902;
 server_name proxy;
 location / {
  echo_exec @default;
 }
 location ^~ /api/v1/query_range {
     echo_sleep 1;
     echo_exec @default;
 }
 location @default {
     proxy_pass http://172.17.0.1:10912;
 }
}
```{{copy}}

```
docker run -d --net=host --rm \
    -v $(pwd)/nginx.conf:/etc/nginx/conf.d/default.conf \
    --name nginx \
    yannrobert/docker-nginx && echo "Started Querier Proxy!"
```{{execute}}

### Verify

Let's check if it's running!

```
docker ps
```{{execute}}

## Deploy Thanos Query Frontend

First, let's create necessary cache configuration for Frontend:

In Editor tab and make a `frontend.yml` file in editor folder and paste the above code in it.

```
type: IN-MEMORY
config:
  max_size: "0"
  max_size_items: 2048
  validity: "6h"
```{{copy}}

And deploy Query Frontend:

```
docker run -d --net=host --rm \
    -v $(pwd)/frontend.yml:/etc/thanos/frontend.yml \
    --name query-frontend \
    quay.io/thanos/thanos:v0.28.0 \
    query-frontend \
    --http-address 0.0.0.0:20902 \
    --query-frontend.compress-responses \
    --query-frontend.downstream-url=http://172.17.0.1:10902 \
    --query-frontend.log-queries-longer-than=5s \
    --query-range.split-interval=1m \
    --query-range.response-cache-max-freshness=1m \
    --query-range.max-retries-per-request=5 \
    --query-range.response-cache-config-file=/etc/thanos/frontend.yml \
    --cache-compression-type="snappy" && echo "Started Thanos Query Frontend!"
```{{execute}}

### Setup Verification

Once started you should be able to reach the Querier, Query Frontend and Prometheus.

* [Prometheus]({{TRAFFIC_HOST1_9090}}/)
* [Querier]({{TRAFFIC_HOST1_10902}}/)
* [Query Frontend]({{TRAFFIC_HOST1_20902}}/)

Now, go and execute a query on [Querier]({{TRAFFIC_HOST1_10902}}/) and observe the latency.
And then go and execute the same query on [Query Frontend]({{TRAFFIC_HOST1_20902}}/).
For the first execution you will observe that the query execution takes longer than the query on Querier.
That's because we have an nginx proxy between Query Frontend and Querier.

Now if you execute the same query again on Query Frontend for the same time frame using time selector in graph section in the UI (time is always shifting).
See that it's much faster?
It's taking much less time because we are just serving the response from the cached results.

Good! You've done it!
