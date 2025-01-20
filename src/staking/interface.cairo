
use mature_vault::types::types::{Commission, Index, Amount};
use starknet::{ContractAddress, ClassHash};
use mature_vault::types::time::{Timestamp, TimeDelta};

/// Public interface for the staking contract.
#[starknet::interface]
pub trait IStaking<TContractState> {
    fn get_staker_info(
        self: @TContractState, staker_address: ContractAddress
    ) -> Option<StakerInfo>;
}


#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<Timestamp>,
    pub amount_own: Amount,
    pub index: Index,
    pub unclaimed_rewards_own: Amount,
    pub pool_info: Option<StakerPoolInfo>,
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerPoolInfo {
    pub pool_contract: ContractAddress,
    pub amount: Amount,
    pub unclaimed_rewards: Amount,
    pub commission: Commission,
}

