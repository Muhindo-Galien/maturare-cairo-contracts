#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct Timestamp {
    pub seconds: u64
}

// If we change the type, make sure the errors still show the right type.
pub type Commission = u16;
pub type Amount = u128;
pub type Index = u128;
pub type Inflation = u16;
