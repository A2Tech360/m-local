// Apply only at the trusted public ingress. Never trust a caller-supplied actor ID.
export function createOnboardingLimit(clock=Date.now) {
  const clients=new Map();
  return (client,path)=>{
    if(!['/function/request_email_code','/function/verify_email_code'].includes(path))return 0;
    const now=clock(),key=path+':'+client;
    for(const [id,times] of clients)if(times.at(-1)<=now-3600000)clients.delete(id);
    const times=(clients.get(key)||[]).filter(t=>t>now-3600000);
    const sending=path.endsWith('request_email_code');
    const perMinute=sending?3:20,perHour=sending?10:100;
    if(times.length>=perHour)return Math.max(1,Math.ceil((times[0]+3600000-now)/1000));
    const minute=times.filter(t=>t>now-60000);
    if(minute.length>=perMinute)return Math.max(1,Math.ceil((minute[0]+60000-now)/1000));
    if(!clients.has(key)&&clients.size>=10000)return 60;
    times.push(now);clients.set(key,times);return 0;
  };
}
