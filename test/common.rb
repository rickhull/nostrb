require 'nostrb/event'

module Nostr
  module Test
    SK, PK = SchnorrSig.keypair
    EVENT = Event.new('testing', pk: PK)
    SIGNED = EVENT.sign(SK)
    HASH = {
      "content" => "hello world",
      "pubkey" => "18a2f562682d3ccaee89297eeee89a7961bc417bad98e9a3a93f010b0ea5313d",
      "kind" => 1,
      "tags" => [],
      "created_at" => 1725496781,
      "id" => "7f6f1c7ee406a450b581c62754fa66ffaaff0504b40ced02a6d0fc3806f1d44b",
      "sig" => "8bb25f403e90cbe83629098264327b56240a703820b26f440a348ae81a64ec490c18e61d2942fe300f26b93a1534a94406aec12f5a32272357263bea88fccfda"
    }
  end
end
