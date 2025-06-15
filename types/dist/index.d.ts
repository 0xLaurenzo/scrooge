export interface IPFSPaymentRequest {
    version: '1.0';
    createdAt: number;
    creator: string;
    recipient: string;
    chainId: number;
    token: {
        address: string;
        symbol: string;
        decimals: number;
        name: string;
    };
    amount?: string;
    description?: string;
    expiresAt?: number;
    metadata?: Record<string, any>;
}
export interface CachedPaymentRequest {
    id: string;
    ipfsCID: string;
    createdBy: string;
    recipientAddress: string;
    chainId: number;
    tokenSymbol: string;
    amount?: string;
    createdAt: Date;
    expiresAt?: Date;
    status: 'pending' | 'paid' | 'expired';
    paidBy?: string;
    transactionHash?: string;
    paidAt?: Date;
    blockNumber?: bigint;
    cachedData: IPFSPaymentRequest;
}
export interface TokenInfo {
    address: string;
    symbol: string;
    decimals: number;
    name: string;
    logoURI?: string;
}
export interface ContractAddresses {
    [chainId: number]: string;
}
export type PaymentStatus = 'pending' | 'paid' | 'expired';
