import test from 'node:test';
import assert from 'node:assert/strict';
import {createOnboardingLimit} from '../../scripts/onboarding-ingress.mjs';

const send='/function/request_email_code';
const verify='/function/verify_email_code';

test('a shared network admits a bounded signup burst and recovers at the exact minute boundary',()=>{
 let now=100000;const start=now,allow=createOnboardingLimit(()=>now);
 for(let i=0;i<12;i++)assert.equal(allow('network-a',send),0,`signup ${i+1}`);
 assert.equal(allow('network-a',send),60);
 assert.equal(allow('network-b',send),0,'a second network has its own allowance');
 assert.equal(allow('network-a','/function/list_offers'),0,'browsing stays available');
 now=start+59501;
 assert.equal(allow('network-a',send),1,'round a partial remaining second up');
 now=start+59999;
 assert.equal(allow('network-a',send),1);
 now=start+60000;
 for(let i=0;i<12;i++)assert.equal(allow('network-a',send),0,'denied attempts must not extend the window');
 assert.equal(allow('network-a',send),60);
});

test('one network cannot consume the entire hourly mail budget by rotating recipients',()=>{
 let now=0;const allow=createOnboardingLimit(()=>now);
 for(const [at,count] of [[0,12],[60000,12],[120000,6]]){
  now=at;
  for(let i=0;i<count;i++)assert.equal(allow('network-a',send),0);
 }
 assert.equal(allow('network-a',send),3480,'the hourly limit applies before another minute can open');
 now=3599999;assert.equal(allow('network-a',send),1);
 now=3600000;
 for(let i=0;i<12;i++)assert.equal(allow('network-a',send),0,'only the first batch has expired');
 assert.equal(allow('network-a',send),60,'later batches still count toward the rolling hour');
 now=3660000;assert.equal(allow('network-a',send),0);
});

test('retry waits for both windows when the hourly allowance expires before a recent burst',()=>{
 let now=0;const allow=createOnboardingLimit(()=>now);
 for(const [at,count] of [[0,12],[60000,6],[3590000,12]]){
  now=at;
  for(let i=0;i<count;i++)assert.equal(allow('network-a',send),0);
 }
 now=3595000;assert.equal(allow('network-a',send),55);
 now=3600000;assert.equal(allow('network-a',send),50);
 now=3649999;assert.equal(allow('network-a',send),1);
 now=3650000;assert.equal(allow('network-a',send),0);
});

test('verification keeps its existing minute and hour bounds independently of sends',()=>{
 let now=0;const allow=createOnboardingLimit(()=>now);
 for(let i=0;i<12;i++)assert.equal(allow('network-a',send),0);
 for(let i=0;i<20;i++)assert.equal(allow('network-a',verify),0);
 assert.equal(allow('network-a',verify),60);
 now=59999;assert.equal(allow('network-a',verify),1);
 for(const at of [60000,120000,180000,240000]){
  now=at;
  for(let i=0;i<20;i++)assert.equal(allow('network-a',verify),0);
 }
 assert.equal(allow('network-a',verify),3360);
 assert.equal(allow('network-b',verify),0);
 now=3599999;assert.equal(allow('network-a',verify),1);
 now=3600000;assert.equal(allow('network-a',verify),0);
});
