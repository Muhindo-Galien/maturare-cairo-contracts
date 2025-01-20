#[starknet::contract]
pub mod withdrawal_manager{
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    //=====`openzeppelin`=====
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    //==x===`openzeppelin`==x===
    use mature_vault::token::interface::{ITokenDispatcher, ITokenDispatcherTrait};
    use mature_vault::withdrawlManager::interface::{IWithdrawlVault};
    use mature_vault::token::{erc20::{ERC20ABIDispatcher as IERC20Dispatcher, ERC20ABIDispatcherTrait}, erc20_component::ERC20Component};
    use mature_vault::vault::interface::{IVaultDispatcher, IVaultDispatcherTrait};
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
        asset: IERC20Dispatcher,
        mature_vault: ContractAddress,
        ma_strk_token: ITokenDispatcher,
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
        TransferedToken:TransferedToken,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferedToken {
        #[key]
        receiver : ContractAddress,
        assets:u256,
    }
   
    mod Errors {
        const ONLY_OWNER: felt252 = 'Only owner';
        const ONLY_VAULT_MANAGER: felt252 = 'Only vault manager';
        const INSUFFICIENT_BALANCE: felt252 = 'insufficient balance';
        const TRANSFER_FAILED: felt252 = 'Tranfer failed';  
    }
    #[constructor]
    fn constructor(ref self: ContractState, srtk_token:ContractAddress, owner: ContractAddress) {
        self.ownable.initializer(owner);

        self.asset.write(IERC20Dispatcher { contract_address: srtk_token });
    }

    #[abi(embed_v0)]
    impl WithdrawlVault of IWithdrawlVault<ContractState> {

        fn complete_withdrawal_for(ref self: ContractState,user:ContractAddress, strk_amount: u256){
            let erc20 = self.asset.read();
            let this = get_contract_address();

            self._assert_only_mature_vault();
            let balance =  erc20.balance_of(this);

            assert(balance >= strk_amount,Errors::INSUFFICIENT_BALANCE);
            assert(erc20.transfer( user, strk_amount), Errors::TRANSFER_FAILED);

            self.emit(TransferedToken{receiver:user,assets:strk_amount});
        }

        fn admin_initiate_withdrawal(ref self: ContractState, ma_strk_amount: u256){
            self._assert_only_mature_vault();
            let this = get_contract_address();

            assert(ma_strk_amount > 0 ,Errors::INSUFFICIENT_BALANCE);

            // burning the ma_strk tokens
            self.ma_strk_token.read().burn(this, ma_strk_amount);
            self.emit(TransferedToken{receiver:this,assets:ma_strk_amount});
        }

        /// @notice Sets the token for this contract
        fn set_ma_strk_token(ref self: ContractState, ma_strk_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.ma_strk_token.write(ITokenDispatcher { contract_address: ma_strk_token });
        }

        fn set_mature_vault(ref self: ContractState, vault_manager:ContractAddress){
            self.ownable.assert_only_owner();
            self.mature_vault.write(vault_manager);
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

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_only_mature_vault(ref self: ContractState) {
            let caller = get_caller_address();
            let vault_manager = self.mature_vault.read();
            assert(caller == vault_manager, Errors::ONLY_VAULT_MANAGER);
        }
            
    }
}