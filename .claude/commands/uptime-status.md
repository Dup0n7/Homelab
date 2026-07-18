---
description: Show current status of every Uptime Kuma-monitored service in the homelab
---

Call the `mcp__homelab-uptime-kuma__get_service_status` tool and present the result as a table: one row per monitored service, with its name and current status (up/down/pending/maintenance/etc.) plus any other fields the tool returns (uptime %, last check time, response time). Sort so any service that is not "up" appears first, and call those out clearly above the table if there are any.
