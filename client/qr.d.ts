import type {ReactElement} from 'react';
export function ClaimQr(props: {payload: string; expiresTs: number}): ReactElement;
export function ClaimScanner(props: {resolveClaim: (payload: string) => Promise<any>; redeemClaim: (payload: string) => Promise<any>; onRedeemed: () => Promise<void>}): ReactElement;
