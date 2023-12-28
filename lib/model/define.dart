
import 'package:pointycastle/pointycastle.dart';
import '../core/nuts/nut_00.dart';

typedef MintKeys = Map<String, String>;

typedef MintResponse = ({String pr, String hashValue});

typedef PaymentPayload = ({
    /// Payment request/Lighting invoice that should get paid by the mint.
    String pr,

    /// Proofs, matching Lightning invoices amount + fees.
    List<Proof> proofs,
});

typedef BlindMessageResult = ({ECPoint B_, BigInt r});

typedef PayLnInvoiceResponse = ({bool isPaid, String? preimage, List<Proof> change, MintKeys? newKeys});


typedef AmountPreference = ({num amount, num count,});

typedef ReceiveResponse = ({
  /// Successfully received Cashu Token
  Token token,

  /// TokenEntries that had errors. No error will be thrown, but clients can choose to handle tokens with errors accordingly.
  Token? tokensWithErrors,

  /// If the mint has rotated keys, this field will be populated with the new keys.
  MintKeys? newKeys,
});

typedef ReceiveTokenEntryResponse = ({
  /// Received proofs
  List<Proof> proofs,

  /// Proofs that could not be received. Doesn't throw an error, but if this field is populated it should be handled by the implementation accordingly
  List<Proof> proofsWithError,

  /// If the mint has rotated keys, this field will be populated with the new keys.
  MintKeys? newKeys,
});

typedef SendResponse = ({
  /// Proofs that exceeded the needed amount
  List<Proof> returnChange,

  /// Proofs to be sent, matching the chosen amount
  List<Proof> send,

  /// If the mint has rotated keys, this field will be populated with the new keys.
  MintKeys? newKeys,
});

typedef SplitReceiveResponse = ({
  int amountKeep,
  int amountSend,
});

typedef TokenInfo = ({
  List<String> mints,
  String value,
  Token decoded,
});