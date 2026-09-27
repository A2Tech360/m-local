const record=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const strings=value=>Array.isArray(value)&&value.every(item=>typeof item==='string');
const finite=value=>typeof value==='number'&&Number.isFinite(value);

function fields(value,{text=[],numbers=[],flags=[],lists=[],required=[]}) {
 if(!record(value)||text.some(key=>typeof value[key]!=='string')||numbers.some(key=>!finite(value[key]))||flags.some(key=>typeof value[key]!=='boolean')||lists.some(key=>!strings(value[key]))||required.some(key=>typeof value[key]!=='string'||!value[key].trim())) {
  throw new Error('Invalid offer feed response.');
 }
}

/** Validate raw or hydrated feed DTOs without discarding server metadata. */
export function validateHomeFeed(value) {
 fields(value,{text:['price_range','note'],numbers:['total_deals'],flags:['signed_in','personalized','completed']});
 if(!Array.isArray(value.items)||!Array.isArray(value.favorites))throw new Error('Invalid offer feed response.');
 for(const item of value.items) {
  fields(item,{text:['place','price_range','slot'],numbers:['price_cents','regular_cents'],flags:['is_favorite'],lists:['place_labels','categories','reasons']});
  fields(item.offer,{
   required:['id','title','restaurant'],
   text:['id','title','description','restaurant','state','time_label','my_claim_id','my_status','my_title','my_qr_payload'],
   numbers:['price','regular_price','remaining','quantity','my_price_cents'],flags:['is_demo'],lists:['dietary','reasons']
  });
 }
 for(const favorite of value.favorites) {
  fields(favorite,{
   required:['slug','name'],
   text:['slug','name','cuisine','neighborhood','best_offer_id','best_offer_title'],
   numbers:['live_offers','best_price_cents'],flags:['is_demo'],lists:['labels']
  });
 }
 return value;
}
