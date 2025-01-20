use starknet::ContractAddress;
use mature_vault::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
};
use mature_vault::staking::interface::{StakerInfo};


 #[starknet::interface]
trait IVault<TContractState> {
    fn get_tvl(self: @TContractState) -> u256;
    fn get_ve_total_amount_to_burn(self: @TContractState) -> u128;
    fn get_total_supply(self: @TContractState) -> u256;
    fn get_total_amount_to_deposit(self: @TContractState) -> u128;
    fn get_amount_to_withdraw(self: @TContractState) -> u128;
    fn get_unclaimed_rewards(self: @TContractState,staking_pool:ContractAddress, staker_address:ContractAddress )->u256;
    fn get_ma_strk_to_mint(self: @TContractState, amount: u256)->u256;
    fn get_strk_to_unstake(self: @TContractState, ma_strk_amount: u256)->u256;
    fn get_request(self: @TContractState,withdrawl_index: u256)->WithdrawRequest;
    fn get_pool_balance(self: @TContractState,staking_pool:ContractAddress, staker_address:ContractAddress )->u256;
    fn set_ma_strk_token(ref self: TContractState, ma_strk_token: ContractAddress);
    fn deposit_strk(ref self: TContractState, assets: u256, receiver:ContractAddress);
    fn initiate_withdrawal(ref self: TContractState, ma_strk_amount:u256);
    fn complete_withdrawal(ref self: TContractState, withdrawl_index: u256);
    fn admin_enter_delegation_pool(ref self: TContractState, staking_pool:ContractAddress, staker_address:ContractAddress);
    fn admin_claim_rewards(ref self: TContractState);
    fn admin_initiate_exit(ref self: TContractState);
    fn admin_complete_exit(ref self: TContractState,pool_member: ContractAddress);
    fn set_delegation_pool(ref self: TContractState, pool_address: ContractAddress);

}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct WithdrawRequest{
    user : ContractAddress,
    ma_strk_amount:u256,
    expected_amount:u256,
    start_time: u64,
    maturity_period: u64,
    is_completed:bool,
}