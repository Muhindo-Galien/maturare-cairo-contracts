use core::panics::panic_with_byte_array;

#[derive(Drop)]
pub enum Error {
    // Pool contract errors
    POOL_MEMBER_EXISTS,
}

#[generate_trait]
pub impl ErrorImpl of ErrorTrait {
    #[inline(always)]
    fn panic(self: Error) -> core::never {
        panic_with_byte_array(@self.message())
    }

    #[inline(always)]
    fn message(self: Error) -> ByteArray {
        match self {
            Error::POOL_MEMBER_EXISTS => "Pool member exists, use add_to_delegation_pool instead",
        }
    }
}

#[inline(always)]
pub fn assert_with_err(condition: bool, error: Error) {
    if !condition {
        error.panic();
    }
}
