use starknet::ContractAddress;

#[starknet::contract]
pub mod mature_vault{
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    //=====`openzeppelin`=====
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    //==x===`openzeppelin`==x===
    use mature_vault::errors::{Error, assert_with_err};
    use mature_vault::types::types::{ Amount};
    use mature_vault::constants::{ ETH_VALUE,FIFTEEN_MINUTE};
    use mature_vault::token::{erc20::{ERC20ABIDispatcher as IERC20Dispatcher, ERC20ABIDispatcherTrait}, erc20_component::ERC20Component};
    use mature_vault::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
    use mature_vault::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use mature_vault::vault::interface::{IVault,WithdrawRequest};
    use mature_vault::pool::interface::{InternalPoolMemberInfo, PoolMemberInfo};
    use mature_vault::staking::interface::{StakerInfo};
    use mature_vault::token::interface::{ITokenDispatcher, ITokenDispatcherTrait};
    use mature_vault::withdrawlManager::interface::{IWithdrawlVaultDispatcher, IWithdrawlVaultDispatcherTrait};
    use starknet::{ContractAddress,ClassHash,get_block_timestamp, get_caller_address, get_contract_address, event::EventEmitter};
    
    //=====`openzeppelin`=====
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    //==x===`openzeppelin`==x===

    #[storage]
    struct Storage {
        //=====`openzeppelin`=====
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        //==x===`openzeppelin`==x===
        tvl: u256,
        pool: IPoolDispatcher,
        withdrawl_manager: ContractAddress,
        ma_strk_token: ITokenDispatcher,
        request_index: u256,
        withdraw_delay: u64,
        withdrawal_manager: ContractAddress,
        asset: IERC20Dispatcher,
        withdraw_requests: Map<u256, WithdrawRequest>,
        // Map pool member to their pool member info.
        pool_member_info: Map<ContractAddress, Option<InternalPoolMemberInfo>>,
        total_amount_to_deposit: u128,
        total_amount_to_withdraw: u128,
        total_amount_to_burn: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        //=====`openzeppelin`=====
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        //==x===`openzeppelin`==x===
        DepositedStrk:DepositedStrk,
        IntitatedWithdrawl:IntitatedWithdrawl,
        WithdrawRequestCompleted:WithdrawRequestCompleted,
        AdminEnteredPool: AdminEnteredPool,
        AdminClaimedRewards:AdminClaimedRewards,
        AdmintCompletedExit:AdmintCompletedExit,
        AdmintInitializedExit:AdmintInitializedExit  
    }

    #[derive(Drop, starknet::Event)]
    struct DepositedStrk {
        #[key]
        receiver : ContractAddress,
        assets:u256,
        is_deposited:bool,
    }

    #[derive(Drop, starknet::Event)]
    struct IntitatedWithdrawl {
        #[key]
        user : ContractAddress,
        #[key]
        request_index : u256,
        ma_strk_amount:u256,
        expected_amount:u256,
        maturity_period: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawRequestCompleted {
        #[flat]
        request : WithdrawRequest
    }

    #[derive(Drop, starknet::Event)]
    struct AdminEnteredPool{
        this : ContractAddress,
        strk_amount: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminClaimedRewards{
        rewards: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct AdmintInitializedExit{
        amount: u128,
        time:u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AdmintCompletedExit{
        executor: ContractAddress,
        execute_at:u64,
    }

    mod Errors {
        const INVALID_CALLER: felt252 = 'Invalid caller';
        const ZERO_AMOUNT: felt252 = 'Amount nul';
        const HIGH_ma_strk: felt252=  'ma_strk is too high';
        const INVALID_TIME: felt252 = 'Invalid time';
        const APPROVAL_FAILED: felt252 = 'Approvel failed';
        const TRANSFER_FAILED: felt252 = 'Tranfer failed';  
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, pool:ContractAddress, asset: ContractAddress, owner:ContractAddress,vault_withdrawal_manager:ContractAddress) {
        self.pool.write(IPoolDispatcher {contract_address: pool});
        self.ownable.initializer(owner);
        self.withdrawal_manager.write(vault_withdrawal_manager);
        self.asset.write(IERC20Dispatcher{contract_address: asset});
        self.withdraw_delay.write(FIFTEEN_MINUTE.into());
    }

    #[abi(embed_v0)]
    impl Vault of IVault<ContractState> {

        fn deposit_strk(ref self: ContractState,assets: u256,receiver:ContractAddress){
            let erc20 = self.asset.read();
            let caller = get_caller_address();
            let this =  get_contract_address();
            
            assert(assets > 0,Errors::ZERO_AMOUNT);
            
            let ma_strk_amount = self.get_ma_strk_to_mint(assets);

            // assert(ma_strk_amount >= assets,Errors::HIGH_ma_strk);

            self.ma_strk_token.read().mint(receiver, ma_strk_amount);
            self.tvl.write(self.tvl.read() +  assets);

            let strk_amount_to_deposit = assets.try_into().unwrap();
            // increase the STRK amount to be delegated by the admin  
            self.total_amount_to_deposit.write(self.total_amount_to_deposit.read() + strk_amount_to_deposit);

            assert(erc20.transfer_from(caller, this, assets), Errors::APPROVAL_FAILED);

            let is_deposited=true;
            self.emit(DepositedStrk{receiver, assets ,is_deposited});
        }

        fn initiate_withdrawal(ref self: ContractState, ma_strk_amount:u256){
            assert(ma_strk_amount > 0 , Errors::ZERO_AMOUNT);

            let expected_amount = self.get_strk_to_unstake(ma_strk_amount);
            let mut index = self.request_index.read();
            
            let caller = get_caller_address();
            let time = get_block_timestamp();
            let ma_strk = self.ma_strk_token.read();

            //sends ma_strk tokens to the withdrawl Manager
            assert(IERC20Dispatcher { contract_address: ma_strk.contract_address }.transfer_from(caller, self.withdrawal_manager.read(), ma_strk_amount) , Errors::TRANSFER_FAILED);
            
            let maturity_time = time + self.withdraw_delay.read();
            let request = WithdrawRequest{user: caller, ma_strk_amount: ma_strk_amount, expected_amount: expected_amount, start_time: time.into(),maturity_period:maturity_time, is_completed: false};
            let strk_amount = expected_amount.try_into().unwrap();
            let amount_to_burn = ma_strk_amount.try_into().unwrap();
            
            self.withdraw_requests.write(index,request);
            
            self.emit(IntitatedWithdrawl{user: caller, request_index: index, ma_strk_amount: ma_strk_amount, expected_amount: expected_amount,maturity_period:maturity_time});
            self.request_index.write(index + 1);

            // incremente the STRK amount to withdraw from the the pool
            self.total_amount_to_withdraw.write(self.total_amount_to_withdraw.read() + strk_amount);    
            // incremente the veStark amount to brun 
            self.total_amount_to_burn.write(self.total_amount_to_burn.read() + amount_to_burn);
        }
        
        fn complete_withdrawal(ref self: ContractState, withdrawl_index: u256){
            let caller = get_caller_address();
            let mut request: WithdrawRequest = self.get_request(withdrawl_index);
            let maturity_time = request.maturity_period;
            let time = get_block_timestamp();
            
            assert(maturity_time <= time, Errors:: INVALID_TIME);
            let amount = request.expected_amount;
            self.tvl.write(self.tvl.read() -  amount);
            IWithdrawlVaultDispatcher{contract_address: self.withdrawal_manager.read()}.complete_withdrawal_for(caller,amount);
            request.is_completed = true;
            self.emit(WithdrawRequestCompleted{request});
        }

        
        fn admin_enter_delegation_pool(ref self: ContractState,staking_pool:ContractAddress, staker_address:ContractAddress){
            self.ownable.assert_only_owner();
            
            let strk_amount = self.total_amount_to_deposit.read();
            let amount = strk_amount.into();
            let this = get_contract_address();
            let pool_disp = self.pool.read();
            let erc20 = self.asset.read();
            let pool_balance = self.get_pool_balance(staking_pool, staker_address);
            
            assert(strk_amount > 0, Errors::ZERO_AMOUNT);
            
            let is_sent = erc20.approve(pool_disp.contract_address, amount);
            assert(is_sent, Errors::APPROVAL_FAILED);
            
            if(pool_balance > 0 ){
                pool_disp.add_to_delegation_pool(this, strk_amount);
            }else{
                pool_disp.enter_delegation_pool(this, strk_amount);
            }
            // Reset deposit amount to 0
            self.total_amount_to_deposit.write(0);
            self.emit(AdminEnteredPool{this, strk_amount});
        }
        
        
        fn admin_claim_rewards(ref self: ContractState){
            self.ownable.assert_only_owner();
            
            let erc20 = self.asset.read();
            let pool_disp = self.pool.read();
            let this = get_contract_address();
            let pool_member_info = self.pool.read().pool_member_info(this);
            let rewards = pool_member_info.unclaimed_rewards;
            
            assert(rewards >0, Errors::ZERO_AMOUNT);
            
            let reward = pool_disp.claim_rewards(this);
            self.tvl.write(self.tvl.read() + reward.into());
            //sends rewards to the withdrawl Manager
            assert(erc20.transfer(self.withdrawal_manager.read(), reward.into()), Errors::TRANSFER_FAILED);
            self.emit(AdminClaimedRewards{rewards});
        }
        
        // Admin initiate the withdrawl process
        fn admin_initiate_exit(ref self: ContractState){
            self.ownable.assert_only_owner();

            let amount = self.total_amount_to_withdraw.read();
            let amount_to_burn = self.total_amount_to_burn.read().into();
            
            assert(amount >0, Errors::ZERO_AMOUNT);
            self.ownable.assert_only_owner();
            
            let time = get_block_timestamp();
            let pool_disp = self.pool.read();

            IWithdrawlVaultDispatcher{contract_address: self.withdrawal_manager.read()}.admin_initiate_withdrawal(amount_to_burn);
            
            // withdaw from the delegationpool
            pool_disp.exit_delegation_pool_intent(amount);
            self.emit(AdmintInitializedExit{amount,time});

            // Reset the amount to 0
            self.total_amount_to_withdraw.write(0);
            self.total_amount_to_burn.write(0);

        }
        
        // Admin completes the withdrawal process
        fn admin_complete_exit(ref self: ContractState,pool_member: ContractAddress){
            self.ownable.assert_only_owner();
            
            let erc20 = self.asset.read();
            
            let pool_disp = self.pool.read();
            let this = get_contract_address();
            let time = get_block_timestamp();
            
            let received_amount = pool_disp.exit_delegation_pool_action(this);
            assert(erc20.transfer(self.withdrawal_manager.read(), received_amount.into()),Errors::TRANSFER_FAILED);
            self.emit(AdmintCompletedExit{executor:this,execute_at:time});
            
        }
        
        /// @notice Sets the token for this contract
        fn set_ma_strk_token(ref self: ContractState, ma_strk_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.ma_strk_token.write(ITokenDispatcher { contract_address: ma_strk_token });
        }
        
        // Getters
        fn get_request(self: @ContractState,withdrawl_index: u256)->WithdrawRequest{
            return self.withdraw_requests.entry(withdrawl_index).read();
        }

        // Returns the the delegation pool's balance
        fn get_pool_balance(self: @ContractState,staking_pool:ContractAddress, staker_address:ContractAddress )->u256{
            let staking_pool_disp = IStakingDispatcher{contract_address:staking_pool};
            let pool = staking_pool_disp.get_staker_info(staker_address);
            
            let pool_balance= pool.unwrap().pool_info.unwrap().amount;
            return pool_balance.into();
        }

        // returns all unclaimed rewards
        fn get_unclaimed_rewards(self: @ContractState,staking_pool:ContractAddress, staker_address:ContractAddress )->u256{
            let staking_pool_disp = IStakingDispatcher{contract_address:staking_pool};
            let pool = staking_pool_disp.get_staker_info(staker_address);
            
            let pool_unclaimed_rewards= pool.unwrap().pool_info.unwrap().unclaimed_rewards;
            return pool_unclaimed_rewards.into();
        }
        
        // return the total value locked
        fn get_tvl(self: @ContractState)->u256{
            return self.tvl.read();
        }
        
        // return the total supply of veSTRK token
        fn get_total_supply(self: @ContractState) -> u256{
            let ma_strk_token = self.ma_strk_token.read();
            return IERC20Dispatcher { contract_address: ma_strk_token.contract_address }.totalSupply();
        }
        
        // returns the veSTRK token worth of STRK token
        fn get_ma_strk_to_mint(self: @ContractState, amount: u256)->u256{
            let total_deposits = self.tvl.read();
            
            if (total_deposits == 0) {
                return amount;
            }

            let total_supply = self.get_total_supply();
            return (amount * total_supply)/ total_deposits;
        }

        // returns the STRK token worth of veSTRK token
        fn get_strk_to_unstake(self: @ContractState, ma_strk_amount: u256)->u256{
            return (ma_strk_amount * ETH_VALUE)/ self.get_ma_strk_to_mint(ETH_VALUE);
        }

        // returns the amount of STRK token to be deposited to the delegation pool
        fn get_total_amount_to_deposit(self: @ContractState) -> u128{
            return self.total_amount_to_deposit.read();
        }

        // Returns the amount of STRK token to be withdrawn from the delegation pool
        fn get_amount_to_withdraw(self: @ContractState) -> u128{
            return self.total_amount_to_withdraw.read();
        }

        fn set_delegation_pool(ref self: ContractState, pool_address: ContractAddress){
            self.pool.write(IPoolDispatcher {contract_address: pool_address});
        }

        fn get_ve_total_amount_to_burn(self: @ContractState) -> u128{
            self.total_amount_to_burn.read()
        }
      
    }

    //
    // Upgradeable
    //
    
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}