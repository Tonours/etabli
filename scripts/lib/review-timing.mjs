// All intervals below use the same observer process's monotonic clock.
export function reviewTiming(inventory, {preparationMs = null, totalMs = null} = {}) {
  const start = inventory.find(row=>row.stage==="before_agent_start")?.observed_at_ms;
  const requests = inventory.filter(row=>row.stage==="before_provider_request");
  const calls = requests.map(row => {
    const finish = inventory.find(end=>end.stage==="assistant_message_end" && end.call_index===row.call_index);
    const duration = finish?.observed_at_ms - row.observed_at_ms;
    return {call_index:row.call_index,request_to_message_end_ms:Number.isFinite(duration) && duration>=0 ? duration : null,
      prompt_bytes:row.blocks.reduce((sum,block)=>sum+block.bytes,0)};
  });
  return {clock:"observer_monotonic",preparation_ms:preparationMs,total_ms:totalMs,
    agent_start_to_first_request_ms:Number.isFinite(start)&&requests.length ? requests[0].observed_at_ms-start : null,
    calls,coverage:calls.length && calls.every(row=>row.request_to_message_end_ms!==null) ? "request_intervals_observed" : "unknown",
    provider_queue_ms:null,model_compute_ms:null,provider_retries_ms:null,
    limitation:"request intervals include queue, transport and model time; these components are not independently observed"};
}
