use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IToken<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn set_withdrawl_manager(ref self: TContractState, withdrawl_manager: ContractAddress);

}