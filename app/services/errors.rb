module Errors
  class Error < StandardError; end
  class PayFirstViolationError < Error; end
  class InvalidStateTransitionError < Error; end
  class InsufficientBalanceError < Error; end
  class TenderExceedsBalanceError < Error; end
  class ShiftAlreadyClosedError < Error; end
  class ShiftNotOpenError < Error; end
  class WalletClientError < Error; end
end
