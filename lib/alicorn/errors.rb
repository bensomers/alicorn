module Alicorn
  class AlicornError < StandardError; end
  class NoUnicornsError < AlicornError; end
  class NoMasterError < AlicornError; end
  class AmbiguousMasterError < AlicornError; end
end
