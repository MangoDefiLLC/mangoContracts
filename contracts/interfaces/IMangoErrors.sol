interface IMangoErrors{
    error TransferFailed();
    error BothCantBeZero():
    error NotOwner();
    error EthUnwrapFailed();
    error ValueIsZero();
    error  CallDistributeFailed();
}