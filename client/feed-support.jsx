import {useEffect,useRef} from 'react';

/** Refresh only the visible feed, coalescing browser events while a request runs. */
export function useFeedRefresh({enabled,onRefresh,busy}) {
 const latest=useRef({enabled,onRefresh,busy}),inFlight=useRef(false);
 latest.current={enabled,onRefresh,busy};
 useEffect(()=>{
  if(!enabled)return;
  let disposed=false;
  async function refresh(){
   const current=latest.current;
   if(disposed||!current.enabled||current.busy||inFlight.current||document.visibilityState==='hidden')return;
   inFlight.current=true;
   try{await current.onRefresh();}
   catch{/* The feed owns its visible error and retry state. Browser events must not reject. */}
   finally{inFlight.current=false;}
  }
  function visible(){if(document.visibilityState==='visible')refresh();}
  const timer=window.setInterval(refresh,30000);
  window.addEventListener('focus',refresh);
  window.addEventListener('online',refresh);
  document.addEventListener('visibilitychange',visible);
  return ()=>{
   disposed=true;
   window.clearInterval(timer);
   window.removeEventListener('focus',refresh);
   window.removeEventListener('online',refresh);
   document.removeEventListener('visibilitychange',visible);
  };
 },[enabled]);
}
