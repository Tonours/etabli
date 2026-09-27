# Review effectiveness metrics

This public table reports aggregate, synthetic measurements only. Detailed
operational evidence is retained in the approved private knowledge base.

| run | reviewed units | escaped defects | false positives | evidence status |
| --- | ---: | ---: | ---: | --- |
| fixture-review-alpha | 0 | 0 | 0 | unmeasured |

Escaped rate per tier: Σ `escaped_later` / number of rows of the private
ship-metrics registry, per `tier`; `unknown` rows are reported apart, never
merged. Runs without ship are outside this population.

Interpretation: an empty or unmeasured row is not a clean result. Add a row
only when the run has reproducible provenance and a retained evidence receipt.
