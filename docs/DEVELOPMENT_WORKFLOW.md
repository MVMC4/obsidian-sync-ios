# Development workflow

## Commit policy

Commits should be small, buildable where the current environment permits, and
describe one coherent change. Preferred subjects use a conventional prefix:

```text
docs: explain device installation
build: generate the mobile framework
feat: persist selected vault access
fix: release security scope after cancellation
test: cover stale bookmark recovery
```

Before each commit:

1. review the complete diff;
2. run applicable formatting and tests;
3. update build or test logs when a meaningful command was executed;
4. ensure no key, certificate, provisioning profile, private path, or personal
   vault content is staged; and
5. commit only files belonging to the coherent change.

## Branch policy

Development begins directly on `main` while the repository has a single
maintainer and no distributable app. Feature branches and required pull-request
checks should be introduced before accepting outside contributions.

## UI policy

The interface will be designed from explicit visual references supplied by the
maintainer. Inspiration may guide spacing, hierarchy, motion, and atmosphere,
but names, icons, illustrations, and exact proprietary assets must be original.

