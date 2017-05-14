# README

Given reservations and weekly availabilities, this gives availabilities for a given week

Requirements:

`rails 4.2.6`
`sqlite 3`

# SETUP

Assuming ruby, git and rubygems installed:

```
git clone http://github.com/heri/availabilities
```

Install gems:

```
cd availabilities && bundle
```

Setup db:

```
RAILS_ENV=production rake db:create && RAILS_ENV=production rake db:migrate
```

Test:

```
rake test
```

# BENCHMARKING

Results are cached

```
RAILS_ENV=production rails console
```

In console: 
```
Event.create kind: 'opening', starts_at: DateTime.parse("2014-08-04 09:30"), ends_at: DateTime.parse("2014-08-04 12:30"), weekly_recurring: true
Event.create kind: 'appointment', starts_at: DateTime.parse("2014-08-11 10:30"), ends_at: DateTime.parse("2014-08-11 11:30")
Event.availabilities Time.now `
Benchmark.ms { Event.availabilities DateTime.parse("2014-08-10") }
```

More requests:

```
10_000.times.sum { Benchmark.ms { Event.availabilities DateTime.parse("2014-08-10") } } 
```

# INFO

[heri](http://twitter.com/heri) heri@studiozenkai.com