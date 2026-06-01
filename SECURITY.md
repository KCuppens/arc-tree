# Security Policy

## Supported versions

Only the latest published version of arc-tree receives fixes.

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅ Yes    |

## Reporting a problem

If you find a potential security issue in arc-tree, **please do not open a public GitHub issue.** Instead:

1. Email **kobecuppens@gmail.com** with the subject line `[arc-tree] Security report`
2. Include:
   - A description of the issue and its potential impact
   - Steps to reproduce (or a minimal proof of concept if one is safe to share)
   - The arc-tree version you tested against
3. You will receive an acknowledgement within 48 hours

We aim to release a fix within 14 days for confirmed issues and will credit you in the release notes unless you prefer to remain anonymous.

## Scope

arc-tree is a CMS UI package — it runs on the server side of an Arc project and is not exposed directly to end users. The main risk surface is the two API routes (`GET /admin/tree/:model` and `POST /admin/tree/:model/:id/move`), which require an authenticated admin or editor session.

Please do not test against production systems you do not own.
