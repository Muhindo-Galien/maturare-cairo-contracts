
#[starknet::contract]
mod Token {
    use mature_vault::token::interface::{IToken};
    //=====`openzeppelin`=====
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    //==x===`openzeppelin`==x===
    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use mature_vault::token::erc20::{ERC20ABIDispatcher as IERC20Dispatcher, ERC20ABIDispatcherTrait};
    use mature_vault::token:: erc20_component::ERC20Component;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    //=====`openzeppelin`=====
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    //==x===`openzeppelin`==x===

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        //=====`openzeppelin`=====
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        //==x===`openzeppelin`==x===
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        mature_vault: ContractAddress,
        decimals: u8,
        withdrawl_manager:ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        //=====`openzeppelin`=====
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        //==x==`openzeppelin`==x===
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    mod Errors {
        const INVALID_CALLER: felt252 = 'Only mature vault manager';
    }


    /// @notice Constructor for the Token contract
    /// @param mature_vault The address of the token manager contract
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals for the token
    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, mature_vault: ContractAddress, name: felt252, symbol: felt252, decimals: u8
    ) {
        self.erc20.initializer(name, symbol,decimals);
        self.mature_vault.write(mature_vault);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl Token of IToken<ContractState> {
        /// @notice Mints tokens to a specified recipient
        /// @dev Only callable by the token manager
        /// @param recipient The address of the recipient to receive minted tokens
        /// @param amount The amount of tokens to mint
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self._assert_only_mature_vault();
            self.erc20._mint(recipient, amount);
        }

        /// @notice Burns tokens from a specified account
        /// @dev Only callable by the token manager
        /// @param account The address of the account from which tokens will be burned
        /// @param amount The amount of tokens to burn
        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self._assert_only_withdrawl_manager();
            self.erc20._burn(account, amount);
        }

        //Setters
        fn set_withdrawl_manager(ref self: ContractState, withdrawl_manager: ContractAddress){
            self.ownable.assert_only_owner();
            self.withdrawl_manager.write(withdrawl_manager);
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
            assert(vault_manager ==  caller, Errors::INVALID_CALLER);
        }
        fn _assert_only_withdrawl_manager(ref self: ContractState) {
            let caller = get_caller_address();
            let withdrawl_manager = self.withdrawl_manager.read();
            assert(withdrawl_manager ==  caller, Errors::INVALID_CALLER);
        }
    }

}