import test from 'node:test';
import assert from 'node:assert/strict';
import {createOnboardingLimit} from '../../scripts/onboarding-ingress.mjs';

test('one client cannot rotate recipient emails to consume the entire sending budget',()=>{
 let now=100000;const allow=createOnboardingLimit(()=>now);
 for(let i=0;i<3;i++)assert.equal(allow('client-a','/function/request_email_code'),0);
 assert.ok(allow('client-a','/function/request_email_code')>0);
 assert.equal(allow('client-b','/function/request_email_code'),0);
 now+=61000;assert.equal(allow('client-a','/function/request_email_code'),0);
 assert.equal(allow('client-a','/function/list_offers'),0);
});
