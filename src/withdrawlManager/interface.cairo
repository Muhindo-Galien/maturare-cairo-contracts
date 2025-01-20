use starknet::ContractAddress;
#[starknet::interface]
trait IWithdrawlVault<TContractState> {
    fn admin_initiate_withdrawal(ref self: TContractState, ma_strk_amount: u256);
    fn complete_withdrawal_for(ref self: TContractState,user:ContractAddress, strk_amount: u256);
    fn set_mature_vault(ref self: TContractState, vault_manager:ContractAddress);
    fn set_ma_strk_token(ref self: TContractState, ma_strk_token: ContractAddress);

}