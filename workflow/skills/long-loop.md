# Long-Loop Budget Discipline

Open this for an improvement loop without a natural fixed end (coverage
hillclimbs, iterative optimization, repeated benchmark attempts); ordinary
plan-implement runs do not need it.

For any improvement loop without a natural fixed end (coverage hillclimbs,
iterative optimization, repeated benchmark attempts), declare an explicit
campaign budget before starting: a maximum iteration count or wall-clock span
scaled to the session's expected limit. Separately declare the maximum silence
between progress observations and a command timeout sized from a measured
baseline or documented project expectation. Freeze one metric command. Deliver the
progression achieved inside the budget — at least three measured values in
the final answer, the current state, and the single next lever — then stop
before an external cap and report. Freeze the project's documented
test/coverage command, not an experimental coverage runner over a live HTTP
server. After two red serve-or-coverage attempts, park that path, write the
measured rows, and stop. About 60 seconds without an observable update is a
prompt to report progress or inspect the process; it is not a universal command
timeout. Abort only at the predeclared command or campaign bound.
A delivered partial progression with an honest stop beats being cut off
mid-iteration: being killed is not evidence of diligence, and an unfinished
iteration proves nothing.
