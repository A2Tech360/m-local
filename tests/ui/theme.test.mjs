import test from 'node:test';
import assert from 'node:assert/strict';
import {createThemeStore,themeStorageKey} from '../../client/theme.mjs';

function browser({dark=false,stored,blocked=false,legacy=false}={}){
  const mediaListeners=new Set(),storageListeners=new Set(),values=new Map();
  if(stored!==undefined)values.set(themeStorageKey,stored);
  const query={matches:dark};
  if(legacy){query.addListener=callback=>mediaListeners.add(callback);query.removeListener=callback=>mediaListeners.delete(callback);}
  else{query.addEventListener=(_,callback)=>mediaListeners.add(callback);query.removeEventListener=(_,callback)=>mediaListeners.delete(callback);}
  return {
    localStorage:{getItem(key){if(blocked)throw new Error('Storage blocked');return values.get(key)??null;},setItem(key,value){if(blocked)throw new Error('Storage blocked');values.set(key,value);}},
    matchMedia:()=>query,
    addEventListener:(_,callback)=>storageListeners.add(callback),
    removeEventListener:(_,callback)=>storageListeners.delete(callback),
    changeSystem(value){query.matches=value;mediaListeners.forEach(callback=>callback({matches:value}));},
    changeStorage(key,newValue){storageListeners.forEach(callback=>callback({key,newValue}));},
    mediaListeners,storageListeners,
  };
}

test('theme uses the device until explicitly selected, then follows device again in System',()=>{
  const environment=browser({dark:true}),store=createThemeStore(environment);
  const unsubscribe=store.subscribe(()=>{});
  assert.deepEqual(store.getSnapshot(),{preference:'system',resolved:'dark'});
  store.setPreference('light');environment.changeSystem(false);environment.changeSystem(true);
  assert.deepEqual(store.getSnapshot(),{preference:'light',resolved:'light'});
  assert.equal(environment.localStorage.getItem(themeStorageKey),'light');
  store.setPreference('system');
  assert.deepEqual(store.getSnapshot(),{preference:'system',resolved:'dark'});
  environment.changeSystem(false);
  assert.deepEqual(store.getSnapshot(),{preference:'system',resolved:'light'});
  unsubscribe();
});

test('saved preferences restore, malformed values fall back safely, blocked storage remains usable',()=>{
  for(const stored of ['dark','light','broken']){
    const store=createThemeStore(browser({dark:true,stored}));
    assert.equal(store.getSnapshot().preference,stored==='broken'?'system':stored);
  }
  const store=createThemeStore(browser({blocked:true}));
  const unsubscribe=store.subscribe(()=>{});
  assert.doesNotThrow(()=>store.setPreference('dark'));
  assert.deepEqual(store.getSnapshot(),{preference:'dark',resolved:'dark'});
  unsubscribe();
});

test('theme shares and cleans up modern and legacy device/storage subscriptions',()=>{
  for(const legacy of [false,true]){
    const environment=browser({legacy}),store=createThemeStore(environment);
    const first=store.subscribe(()=>{}),second=store.subscribe(()=>{});
    assert.equal(environment.mediaListeners.size,1);
    assert.equal(environment.storageListeners.size,1);
    first();assert.equal(environment.mediaListeners.size,1);
    second();assert.equal(environment.mediaListeners.size,0);assert.equal(environment.storageListeners.size,0);
    const again=store.subscribe(()=>{});
    assert.equal(environment.mediaListeners.size,1);again();
    assert.equal(environment.mediaListeners.size,0);
  }
});

test('cross-tab theme updates sync without reacting to account storage changes',()=>{
  const environment=browser(),store=createThemeStore(environment);
  const unsubscribe=store.subscribe(()=>{});
  environment.changeStorage(themeStorageKey,'dark');
  assert.deepEqual(store.getSnapshot(),{preference:'dark',resolved:'dark'});
  environment.changeStorage('jac_token',null);
  assert.equal(store.getSnapshot().resolved,'dark');
  environment.changeStorage(themeStorageKey,null);
  assert.deepEqual(store.getSnapshot(),{preference:'system',resolved:'light'});
  unsubscribe();
});
