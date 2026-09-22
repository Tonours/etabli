const sumKnown = values => values.every(value=>Number.isFinite(value)&&value>=0)
  ? values.reduce((sum,value)=>sum+value,0) : null;

export function reviewTelemetry({passes, jev = [], preparationMs}) {
  const receipts = passes.flatMap(pass=>pass.receipts);
  const usage = Object.fromEntries(["input_tokens","output_tokens","cached_input_tokens","cache_write_input_tokens","reasoning_output_tokens","cost_usd"]
    .map(key=>[key,sumKnown(receipts.map(receipt=>receipt[key]))]));
  const jevTokens = sumKnown(jev.map(receipt=>receipt.usage_coverage==="response_measured"
    ? sumKnown([receipt.usage?.input_tokens,receipt.usage?.output_tokens]) : null));
  return {schema_version:1,preparation_ms:preparationMs,
    timing_coverage:passes.length && passes.every(pass=>pass.timing?.coverage==="request_intervals_observed" && pass.timing.calls.length===pass.llm_calls)
      ? "request_intervals_observed" : "unknown",
    roles:passes.map(pass=>({role:pass.role,pass_id:pass.pass_id,llm_calls:pass.llm_calls,tool_calls:pass.tool_calls,
      total_tokens:sumKnown(pass.receipts.map(row=>row.total_tokens)),timing:pass.timing??null})),
    usage,jev_tokens:jevTokens,jev_calls:jev.length,
    jev_wait_ms:sumKnown(jev.map(receipt=>receipt.latency_ms)),
    jev_backoff_ms:sumKnown(jev.map(receipt=>sumKnown((receipt.attempts??[]).filter(row=>row.stage==="backoff").map(row=>row.delay_ms)))),
    jev_cost_usd:null,combined_cost_usd:null,
    provider_queue_ms:null,model_compute_ms:null,
    timing_limitation:"request intervals include provider queue, network and model execution"};
}

export function aggregateTelemetry(rows) {
  const observed=rows.map(row=>row.telemetry);
  const roles=observed.flatMap(row=>row?.roles??[]);
  const llm=sumKnown(rows.map(row=>row.total_llm_tokens));
  const jev=sumKnown(observed.map(row=>row?.jev_tokens));
  return {llm_tokens:llm,jev_tokens:jev,combined_tokens:llm!==null&&jev!==null?llm+jev:null,
    usage:Object.fromEntries(["input_tokens","output_tokens","cached_input_tokens","cache_write_input_tokens","reasoning_output_tokens","cost_usd"]
      .map(key=>[key,sumKnown(observed.map(row=>row?.usage?.[key]))])),
    preparation_ms:sumKnown(observed.map(row=>row?.preparation_ms)),
    jev_wait_ms:sumKnown(observed.map(row=>row?.jev_wait_ms)),
    jev_backoff_ms:sumKnown(observed.map(row=>row?.jev_backoff_ms)),
    jev_cost_usd:null,combined_cost_usd:null,
    by_role:Object.fromEntries([...new Set(roles.map(row=>row.role))].map(role=>{
      const selected=roles.filter(row=>row.role===role);
      return [role,{passes:selected.length,llm_calls:sumKnown(selected.map(row=>row.llm_calls)),
        tool_calls:sumKnown(selected.map(row=>row.tool_calls)),tokens:sumKnown(selected.map(row=>row.total_tokens))}];
    }))};
}

// Resample patches, not repeated runs, to preserve the unit of independence.
export function pairedTokenInterval(rows, denominatorArm) {
  const patches=[...new Set(rows.map(row=>row.case_id))];
  const pairs=patches.map(id=>[denominatorArm,"C"].map(arm=>rows.filter(row=>row.case_id===id&&row.arm===arm)
    .reduce((sum,row)=>sum+row.total_llm_tokens,0)));
  if(pairs.length<2||pairs.some(pair=>pair.some(value=>!Number.isFinite(value)||value<=0)))return null;
  let seed=240922;
  const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const ratios=Array.from({length:2000},()=>{
    let base=0,candidate=0;
    for(let i=0;i<pairs.length;i++){const pair=pairs[Math.floor(random()*pairs.length)];base+=pair[0];candidate+=pair[1];}
    return candidate/base;
  }).sort((a,b)=>a-b);
  return {method:"paired_patch_percentile_bootstrap",patches:pairs.length,repetitions_per_patch:3,
    resamples:2000,confidence:0.95,lower:ratios[49],upper:ratios[1949]};
}
