# GX430T Global Deployment Boundary

GX430T can be distributed globally as software.

The physical Zebra GX430t remains local to the organization that owns it.

The physical printer, CUPS queue, IPP endpoint, pairing service, and GX430T Print Host must remain private to the approved workplace network.

## Allowed global surfaces

- public source repository;
- signed release downloads;
- public documentation;
- checksums and release manifests;
- installation guides;
- training presentation;
- controlled issue reporting.

## Private operational surfaces

- printer USB connection;
- CUPS administration;
- local IPP endpoint;
- Mac Print Host endpoint;
- pairing codes;
- workplace network address;
- print history;
- diagnostic bundles containing internal network information.

## Mandatory network rule

No printer, CUPS endpoint, IPP endpoint, pairing service, or Print Host service
may be intentionally exposed to the unrestricted public internet.

Remote use must pass through an organization-approved private network, VPN, or
managed access layer.

## Global product claim

GX430T is globally distributable Mac and iPhone software for controlled Zebra
GX430t operation.

It is not a globally reachable physical printer service.
