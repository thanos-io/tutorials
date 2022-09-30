#!/usr/bin/env bash

docker pull quay.io/prometheus/prometheus:v2.38.0
docker pull quay.io/thanos/thanos:v0.28.0
docker pull quay.io/thanos/prom-label-proxy:v0.3.0-rc.0-ext1
docker pull caddy:2.2.1

mkdir /root/editor
