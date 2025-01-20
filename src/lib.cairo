pub mod vault{
    mod  mature_vault;
    mod interface;
}
pub mod errors;
mod pool{
    mod interface;
}
mod staking{
    mod interface;
}

mod token{
    mod interface;
    mod token;
    mod erc20;
    mod erc20_component;
}

mod withdrawlManager{
    mod withdrawl_manager;
    mod interface;

}
pub mod types{
    mod types;
    mod time;
}
mod constants;