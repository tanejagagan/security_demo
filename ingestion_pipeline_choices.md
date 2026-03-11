# Ingestion Pipeline Choices

## Option 1 — S3 Polling

```
+----------------+        +-------------------+        +------------------+
|  Event Source  | -----> |   Batch Writer    | -----> |  S3 Landing Zone |
+----------------+  batch +-------------------+ Parquet+------------------+
                          (Producer)                           |
                                                               | poll for
                                                               | new files
                                                               v
                                                    +------------------+
                                                    |     Poller       |
                                                    +------------------+
                                                         |        |
                                              read       |        | mark
                                             Parquet     |        | processed
                                                         v        v
                                             +-----------+  +------------+
                                             |   Batch   |  | Checkpoint |
                                             |   Reader  |  |   Store    |
                                             +-----------+  +------------+
                                                   |
                                                   | insert rows
                                                   v
                                          +------------------+
                                          |      Table       |
                                          +------------------+
                                          (Consumer)
```

## Option 2 — S3 Event Notification

```
+----------------+        +-------------------+        +------------------+
|  Event Source  | -----> |   Batch Writer    | -----> |  S3 Landing Zone |
+----------------+  batch +-------------------+ Parquet+------------------+
                          (Producer)                           |
                                                               | S3 Event
                                                               | Notification
                                                               v
                                                    +------------------+
                                                    |       SQS        |
                                                    |      Queue       |
                                                    +------------------+
                                                               |
                                                               | consume
                                                               | message
                                                               v
                                                    +------------------+
                                                    |    Consumer      |
                                                    +------------------+
                                                         |        |
                                              read       |        | mark
                                             Parquet     |        | processed
                                                         v        v
                                             +-----------+  +------------+
                                             |   Batch   |  | Checkpoint |
                                             |   Reader  |  |   Store    |
                                             +-----------+  +------------+
                                                   |
                                                   | insert rows
                                                   v
                                          +------------------+
                                          |      Table       |
                                          +------------------+
```

---

## Option 3 — DazzleDuck HTTP Server (Direct Push)

```
+----------------+        +-------------------+        +--------------------------+
|  Event Source  | -----> |   Batch Writer    | -----> | DazzleDuck Server Cluster|
+----------------+  batch +-------------------+  HTTP  +--------------------------+
                          (Producer)             POST         |          |
                                               (Arrow)        | write    | 200 OK
                                                              v          |
                                                    +------------------+ |
                                                    |      Table       | |
                                                    +------------------+ |
                                                    (DuckLake on S3)     |
                                                                         v
                                                              +------------------+
                                                              |    Producer      |
                                                              |  (ack / retry)   |
                                                              +------------------+
```

**Notes:**
- Producer sends Arrow batches directly to DazzleDuck via HTTP POST
- DazzleDuck Server Cluster receives the batch, appends rows to the DuckLake table
- No S3 landing zone or separate consumer process required
- Back-pressure handled via HTTP response codes (200 OK / 503 retry)
- Simplest operational model — fewest moving parts
- HA is handled using a DazzleDuck HTTP Server cluster — multiple nodes behind a load balancer, each writing to the shared DuckLake S3 catalog
