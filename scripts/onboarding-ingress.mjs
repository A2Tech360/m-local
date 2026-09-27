// Apply only at the trusted public ingress. Never trust a caller-supplied actor ID.
export function createOnboardingLimit(clock=Date.now) {
  const clients=new Map();
  return (client,path)=>{
    if(!['/function/request_email_code','/function/verify_email_code'].includes(path))return 0;
    const now=clock(),key=path+':'+client;
    for(const [id,times] of clients)if(times.at(-1)<=now-3600000)clients.delete(id);
    const times=(clients.get(key)||[]).filter(t=>t>now-3600000);
    const sending=path.endsWith('request_email_code');
    // Four testers may share one public IP. Allow their signup burst and all
    // four accounts' five-send hourly budgets, plus room for failed requests.
    // Keep one network below the backend's 60-send hourly cap. Per-email limits
    // and the verification-attempt budgets remain independent and unchanged.
    const perMinute=sending?12:20,perHour=sending?30:100;
    const minute=times.filter(t=>t>now-60000);
    const retryMs=Math.max(
      times.length>=perHour?times[0]+3600000-now:0,
      minute.length>=perMinute?minute[0]+60000-now:0,
    );
    if(retryMs>0)return Math.max(1,Math.ceil(retryMs/1000));
    if(!clients.has(key)&&clients.size>=10000)return 60;
    times.push(now);clients.set(key,times);return 0;
  };
}
