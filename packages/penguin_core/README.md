# penguin_core

`AppConfig`, `Result`/`Failure`, `PenguinLogger`/`LogSanitizer`, `Clock`, and
the cross-cutting interfaces implemented elsewhere: `TokenProvider`,
`MetricsSink`, `TraceSink`. No penguin path dependencies — every other
package depends on this one, never the reverse. See spec §4.2.
