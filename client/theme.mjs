// Browser-only presentation preference. Never reads or changes account/session keys.
export const themeStorageKey='mlocal_theme';
const preferenceOf=value=>['light','dark'].includes(value)?value:'system';

export function createThemeStore(browser){
  const subscribers=new Set();
  let snapshot,mediaQuery;
  const readPreference=()=>{
    try{return preferenceOf(browser?.localStorage.getItem(themeStorageKey));}
    catch{return 'system';}
  };
  const query=()=>browser?.matchMedia?.('(prefers-color-scheme: dark)');
  function update(preference){
    const resolved=preference==='system'?((mediaQuery||query())?.matches?'dark':'light'):preference;
    if(snapshot?.preference===preference&&snapshot?.resolved===resolved)return;
    snapshot={preference,resolved};
    subscribers.forEach(notify=>notify());
  }
  function getSnapshot(){if(!snapshot)update(readPreference());return snapshot;}
  function onSystemChange(){if(getSnapshot().preference==='system')update('system');}
  function onStorage(event){
    if(event.key===themeStorageKey||event.key===null)update(preferenceOf(event.newValue));
  }
  function subscribe(notify){
    subscribers.add(notify);
    if(subscribers.size===1&&browser){
      mediaQuery=query();
      if(mediaQuery?.addEventListener)mediaQuery.addEventListener('change',onSystemChange);
      else mediaQuery?.addListener?.(onSystemChange);
      browser.addEventListener('storage',onStorage);
      update(readPreference());
    }
    return ()=>{
      subscribers.delete(notify);
      if(subscribers.size===0&&browser){
        if(mediaQuery?.removeEventListener)mediaQuery.removeEventListener('change',onSystemChange);
        else mediaQuery?.removeListener?.(onSystemChange);
        browser.removeEventListener('storage',onStorage);
        mediaQuery=undefined;
      }
    };
  }
  function setPreference(value){
    const preference=preferenceOf(value);
    update(preference);
    try{browser?.localStorage.setItem(themeStorageKey,preference);}
    catch{/* The selection still works in this tab when storage is blocked. */}
  }
  return {getSnapshot,subscribe,setPreference};
}
