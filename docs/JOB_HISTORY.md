# GX430T Job History

The Print Host records bounded operational metadata for submitted jobs.

Stored fields include:

- job identifier
- print kind
- copies
- payload hash
- success state
- result
- duration
- timestamp
- remote address

The host does not expose job history without bearer-token authentication.

Client commands:

```bash
gx430tctl client-jobs 25
gx430tctl client-job-summary
````

Authenticated endpoints:

```text
GET /v1/jobs?limit=25
GET /v1/jobs/summary?limit=500
```

The API returns at most 500 records per request.
