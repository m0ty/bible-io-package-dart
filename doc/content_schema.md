# Bible IO content schema

This document defines Bible IO content schema version 1. The schema is designed
for Bible applications that need a deterministic, lossless source of content
and stable locations for UI state.

## Complete example

```json
{
  "schemaVersion": 1,
  "language": "English",
  "metadata": {
    "id": "eng-example-2026",
    "translationName": "Example Translation",
    "abbreviation": "EXT",
    "description": "An example edition",
    "languageCode": "en",
    "direction": "ltr",
    "canon": "protestant",
    "versionDate": "2026-07-12",
    "copyright": "Copyright holder and terms",
    "license": "Content license identifier or URL"
  },
  "bookOrder": ["gn", "ex", "jo"],
  "books": {
    "gn": {
      "name": "Genesis",
      "section": "Pentateuch",
      "chapters": {
        "1": {
          "heading": "The creation",
          "verses": {
            "1": {
              "text": "In the beginning God created the heavens and the earth.",
              "paragraphStart": true,
              "crossReferences": ["John 1:1-3"]
            },
            "2": "The earth was formless and empty..."
          }
        }
      }
    },
    "ex": {
      "name": "Exodus",
      "chapters": {
        "1": {
          "1": "These are the names..."
        }
      }
    },
    "jo": {
      "name": "John",
      "chapters": {
        "1": {
          "1": "In the beginning was the Word..."
        }
      }
    }
  }
}
```

All text files must be valid JSON. UTF-8 is recommended and is used by the
byte and file loading APIs.

## Root object

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `schemaVersion` | integer | No | Content contract version. Missing means version 1 for legacy compatibility. The only currently supported value is `1`. |
| `language` | string | No | Language name understood by `bible_io_references`; metadata/source language is used as a fallback. |
| `metadata` | object | No | Edition identity, display, provenance, and content-license metadata. |
| `bookOrder` | array of strings | No | Edition/canon order. If present, it must contain every loaded book exactly once. |
| `books` | object | Yes in strict mode | Book identifier to book-content map. |

Unknown JSON-compatible root fields are deeply frozen and retained in
`Bible.annotations`. They are written back at the root when serialized.

### Schema version behavior

- Omitting `schemaVersion` keeps existing version 1 data valid.
- Writers should emit `schemaVersion: 1`.
- A non-integer or unsupported version is rejected. The loader does not guess
  how to interpret a future contract.

## Metadata and identity

`metadata.id` should be stable, non-blank, and unique for one translation
edition or revision. It is the edition component of `BibleVerseKey`; changing
text or versification in a way that could invalidate persisted UI state should
normally use a new ID.

Recognized metadata fields include:

- `id` and `description`
- `languageName` and `languageCode`
- `translationName` and `abbreviation`
- `year`, `direction`, and `versionDate`
- `sourceName`, `copyright`, and `license`
- `canon`
- nested `source` information represented by `BibleSource`

`direction` accepts `auto`, `ltr`, or `rtl`. `versionDate` is ISO 8601.
Unknown JSON-compatible metadata fields are retained in
`BibleMetadata.additional`.
Unknown fields inside the nested `source` object remain nested in
`BibleSource.additional`.

Metadata can also appear in legacy root-level fields. Nested `metadata` values
take precedence, followed by legacy root values, an explicitly supplied
`BibleSource`, embedded source data, and inferred language fallbacks.

The metadata `license` field describes the loaded content. It does not change
the AGPL license of Bible IO itself, and the package's AGPL license does not
grant rights to a translation.

## Book identifiers and order

Keys in `books` may use names and identifiers supported by
`bible_io_references`, including package abbreviations, full English names,
OSIS identifiers, and USFM identifiers. Two different keys that resolve to the
same book are rejected.

`bookOrder` is strongly recommended, especially for non-default canons. When
it is present:

- every value must resolve to a loaded book;
- every loaded book must appear exactly once; and
- duplicates are invalid.

When `bookOrder` is absent, the loader uses the canonical
`BibleBookEnum` order rather than JSON object insertion order. Chapter and
verse order always follows their positive numeric keys. Sparse chapter and
verse numbering is supported.

Serialized version 1 content emits the loaded book order explicitly.

## Book values

A book is an object with a display `name` and a `chapters` map:

```json
{
  "name": "Genesis",
  "chapters": {
    "1": {
      "1": "In the beginning..."
    }
  }
}
```

`name` may be omitted to use the reference package's default full name.
Unknown JSON-compatible fields are retained in `Book.annotations`. The keys
`name` and `chapters` are structural and cannot be used as annotations.

## Chapter values

An unannotated chapter uses the legacy verse map:

```json
{
  "1": "First verse",
  "2": "Second verse"
}
```

An annotated chapter wraps that map in `verses` and may include arbitrary
JSON-compatible fields:

```json
{
  "heading": "A chapter heading",
  "layout": {"columns": 1},
  "verses": {
    "1": "First verse"
  }
}
```

Those fields are retained in `Chapter.annotations`. `verses` is reserved for
the structural map.

## Verse values

A plain verse remains a string, preserving compatibility with earlier Bible IO
data:

```json
"16": "For God so loved the world..."
```

Use an object when the verse carries presentation or study content:

```json
"16": {
  "text": "For God so loved the world...",
  "paragraphStart": true,
  "poetry": {"indent": 1},
  "footnotes": [
    {"marker": "a", "text": "Translator note"}
  ],
  "crossReferences": ["Romans 5:8"]
}
```

`text` is structural and required in the object form. Every other
JSON-compatible field is retained in `Verse.annotations`. Bible IO does not
assign semantics to annotation names: the application or content profile owns
their interpretation.

Plain values serialize as strings. Annotated values serialize as objects, so a
load/serialize/load cycle preserves annotations without forcing all existing
data into the verbose form.

## Validation modes

Strict validation is the default for every JSON construction API. It requires:

- a non-empty `books` object;
- at least one chapter per book;
- at least one verse per chapter; and
- non-blank verse text.

It also rejects malformed JSON types, invalid or duplicate book identities,
non-positive or duplicate numeric chapter/verse keys, inconsistent parent
relationships, unsupported schema versions, and non-JSON annotation values.

Errors use `BibleDataFormatError`, including a stable code, JSON path, offending
value when useful, and an underlying cause/stack trace when one exists.

For intentionally skeletal content:

```dart
final bible = Bible.fromDecodedJson(
  decoded,
  options: const BibleLoadOptions(
    validation: BibleDataValidationOptions.permissive,
  ),
);
```

The permissive policy relaxes only the four presence/content requirements
above. Structural and type safety remain enforced. Individual requirements can
also be selected with `BibleDataValidationOptions`.

## Immutable model contract

All model collections and annotation trees are deeply immutable. Constructors
defensively copy caller-owned lists and maps. Use model `copyWith()` methods to
derive a changed graph; do not retain mutable maps as application state.

`BibleLocation` is stable only within an edition. Persist verse UI state with:

```json
{
  "editionId": "eng-example-2026",
  "location": {
    "book": "jo",
    "chapter": 3,
    "verse": 16
  }
}
```

This is the JSON representation produced by `BibleVerseKey.toJson()` and
accepted by `BibleVerseKey.fromJson()`.

## Version 1 migration checklist

Existing content made only of string verses remains readable. Before treating
an edition as a durable UI state source:

1. Add `schemaVersion: 1`.
2. Add a stable `metadata.id`.
3. Add an explicit `bookOrder`, particularly for partial or non-default canons.
4. Move presentation/study information into book, chapter, or verse annotation
   fields instead of parallel mutable state.
5. Record the translation's independent `copyright` and `license` metadata.
6. Load with strict validation in CI and test a JSON round trip.
