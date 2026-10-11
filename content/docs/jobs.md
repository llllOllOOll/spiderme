---
title: Scheduled jobs
section: guide
order: 160
---

# Scheduled jobs

Some work is nobody's request: releasing what expired, sending what was queued, cleaning up. A feature declares it as a job, and the server runs it on a timer.

The code on this page is from [Bookings](https://bookings.spiderme.org), the example app in `examples/bookings` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)). A new booking holds its room for ten minutes; if nobody confirms it, the time has to become free again, whether or not anyone is looking.

## A job

A feature lists its jobs in its `mod.zig`:

```zig from=examples/bookings/src/features/bookings/mod.zig decl=jobs
```

`spider.every` takes how often, in milliseconds, and the function to run. `server.mountFeatures` in `src/main.zig` finds the list and starts the timers when the server starts listening. The first run comes one interval after that.

Bookings has two. This is the first:

```zig from=examples/bookings/src/features/bookings/jobs.zig decl=every_ms,expireHolds
```

Three things are different from a handler:

- **No request.** There is no `c`, so no `c.arena`: the job makes its own arena and frees it when it is done.
- **Nobody to answer.** The function returns nothing. It catches its own errors and writes them to the log.
- **Its own thread.** The job runs beside the requests, at the same time as them. What it shares with them must be safe to share: the database pool is, a global variable it writes to is not.

What it does have is the hub: the same one handlers reach with `c.sseHub()`. The job above uses it to tell the pages showing a day that the day changed.

The query the job runs is in the repository, like any other:

```zig from=examples/bookings/src/features/bookings/repository.zig decl=expireStale
```

## Do not depend on the timer alone

A job runs every so often, not at the moment something happens. Between a hold running out and the job's next visit, up to half a minute passes. The app must be right in that gap too:

- The page of a booking treats a hold that ran out as expired, whatever the row still says.
- Making a booking releases a dead hold of the same room in the same transaction, so nobody is refused because of one. [PostgreSQL](/docs/postgres) shows it.

The job is what tidies up when nobody does either.

## Once, when the app starts

A feature can also say what it needs before the first request. `pub fn boot` in its `mod.zig` runs once, when the server starts listening:

```zig from=examples/bookings/src/features/bookings/mod.zig decl=boot
```

```zig from=examples/bookings/src/features/bookings/notify.zig decl=mailer,webhook_url,boot
```

`boot` receives a `spider.Boot` with an allocator that lives as long as the process and the server's `io`. When it returns an error the server does not start, and the error says why: a missing setting is found when the app is deployed, not by the first visitor who needs it.

## Testing a job

The timer is not what needs a test: the work is. Call the function the job calls, after putting the data in the state it should find:

```zig from=examples/bookings/src/data_test.zig decl="a hold that ran out gives the time back"
```
