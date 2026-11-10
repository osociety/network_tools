/// Byte format of the packed MAC vendor index shipped in
/// `vendor_index.data.dart`.
///
/// The index replaces the old `const Map<String, (String, String, String,
/// String)>` table: same longest-prefix semantics, but the data is stored as
/// raw bytes, so a consumer pays ~0.8 MB of image and a one-off ~10 ms decode
/// instead of ~4 MB of image and ~19 MB of heap for 49,533 materialised map
/// entries.
///
/// Everything is little-endian. Offsets are byte offsets from the start of the
/// decoded payload.
///
/// ```text
/// header      40 bytes  : magic, formatVersion, n6, n7, n9,
///                         maLOffset, maMOffset, subOffset, nameDictOffset,
///                         dateDictOffset
/// MA-L        n6 * 12   : key(4) nameOffset(4) privateCode(1) blockCode(1) dateIndex(2)
/// MA-M        n7 * 12   : as above; the key holds 7 hex digits (28 bits)
/// MA-S/IAB    n9 * 16   : keyTop(4) keyLast(1) nameOffset(4) privateCode(1)
///                         blockCode(1) dateIndex(2) padding(3)
/// date table  2 + c*2   : count(2) then c byte offsets into the date strings
/// name blob   variable  : NUL-terminated UTF-8 vendor names
/// date blob   variable  : NUL-terminated UTF-8 dates (YYYY/MM/DD)
/// ```
///
/// Each key section is sorted ascending by numeric value, which is the same
/// order as the hex prefixes the table is keyed on, so a lookup is a binary
/// search per prefix length. `MA-M` and `MA-S`/`IAB` blocks are kept in
/// separate sections rather than one merged array because that preserves the
/// exact longest-prefix semantics of probing 9, then 7, then 6 hex digits.
library;

/// Magic bytes `VIDX`.
const int kVendorIndexMagic = 0x56494458;

/// Byte format version, bumped by `tool/build_vendor_index.dart` alongside
/// [PackedVendorIndex].
const int kVendorIndexFormatVersion = 1;

/// Header size in bytes.
const int kVendorIndexHeaderSize = 40;

/// Record size for the 6 and 7 hex digit blocks.
const int kVendorIndexRecordSize = 12;

/// Record size for the 9 hex digit blocks.
const int kVendorIndexLongRecordSize = 16;

/// Hex prefix lengths of the IEEE assignment blocks the index can match:
/// MA-L (3 octets), MA-M (3.5 octets) and MA-S/IAB (4.5 octets).
const Set<int> kVendorPrefixLengths = {6, 7, 9};

/// `Private` column values, stored as a one byte code.
const List<String> kVendorPrivateCodes = ['', 'false', 'true'];

/// `Block Type` column values, stored as a one byte code.
const List<String> kVendorBlockTypeCodes = [
  '',
  'CID',
  'IAB',
  'MA-L',
  'MA-M',
  'MA-S',
];
