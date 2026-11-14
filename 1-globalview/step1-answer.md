## Answer

**How many series (metrics) we collect overall on all Prometheus instances we have?**

Here, `prometheus_tsdb_head_series` is the current number of series in a Prometheus server's TSDB head. Each Prometheus server scrapes this metric from its configured targets, so the query results show one value per target.

* Query [Prometheus-0 EU1]({{TRAFFIC_HOST1_9090}}/graph?g0.range_input=1h&g0.expr=sum(prometheus_tsdb_head_series)&g0.tab=1&g1.range_input=5m&g1.expr=prometheus_tsdb_head_series&g1.tab=0). EU1 scrapes one Prometheus target, so this gives the EU1 count.
* Query either [Prometheus-0 US1]({{TRAFFIC_HOST1_9091}}/graph?g0.range_input=1h&g0.expr=sum(prometheus_tsdb_head_series)&g0.tab=1&g1.range_input=5m&g1.expr=prometheus_tsdb_head_series&g1.tab=0) or [Prometheus-1 US1]({{TRAFFIC_HOST1_9092}}/graph?g0.range_input=1h&g0.expr=sum(prometheus_tsdb_head_series)&g0.tab=1&g1.range_input=5m&g1.expr=prometheus_tsdb_head_series&g1.tab=0). Each US server scrapes both US replicas, so `sum(prometheus_tsdb_head_series)` adds the head-series counts reported by those two targets.

Add the EU1 result to the US1 result to get the total across all three Prometheus TSDBs. Use only one US dashboard: both US servers scrape the same two targets, so either dashboard can provide the pair of US readings. Since scrapes happen at different times, the live values may differ slightly. Do not add the results from both US dashboards, or you will count the US replicas twice.

Because the US Prometheus servers are replicas scraping the same targets, this physical total counts the US data twice, once per replica. For a logical count with the US HA pair treated as one source, count only one US replica instead. Thanos Querier can provide that deduplicated view in the next step.

As you can see this is not very convenient for both human as well as automation on top of metrics (e.g Alerting).

The feature we are missing here is called **Global View** and it might be necessary once you scale out Prometheus to multiple instances.

Great! We have now running 3 Prometheus instances.

In the next steps we will learn how we can install Thanos on top of our initial Prometheus setup to solve problems shown in the challenge.
