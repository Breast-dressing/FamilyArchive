# FamilyArchive (iOS 27 / SwiftUI)

A small SwiftUI app that follows the requested spec: a native five-item tab bar with a
detached `＋` tab, a Music page with a native `Music` / `Archive` control, an Archive
with exactly four sections, family URL parsing ported from the reference
`services.py`, SwiftData persistence keyed by `memberID`, and a strict multi-file HAR
import pipeline.

## Running

1. Open `FamilyArchive.xcodeproj` in **Xcode 27** (iOS 27 SDK).
2. Select an iOS 27 simulator (or a device with a development team set).
3. Build and run.

The project uses the Xcode 16+ format (`objectVersion = 77`, file-system synchronized
group), so all files under `FamilyArchive/` are compiled/added automatically. The
deployment target is iOS 27.0 because `TabRole.prominent` — the native iOS 27 API that
places a tab in a separate, trailing position of the tab bar — is used for `＋`.

If the checked-in project file is ever lost, create a new iOS App project (SwiftUI,
iOS 27) and add the `FamilyArchive` source folder to it; there are no third-party
dependencies.

## Screens and interactions

### Main tab bar

`RootView` declares exactly five tabs in this order:

```
Feed · Video · Music · More · ＋
```

`＋` is a real `Tab` with `role: .prominent` (the detached tab item), never a custom
overlay. Its selection is intercepted by `tabSelection`:

* the binding setter refuses `.plus`, so the selected tab is **never** changed,
* no page is shown for it (its content is `EmptyView()`),
* the setter presents the option list for the page that is currently on screen.

A defensive `onChange` is also present in case the platform ever applies the
`.plus` selection without going through the binding.

| Current page | `＋` behaviour |
| --- | --- |
| Music → Archive | option list: **Badges**, **Family**, **Cards**, **Business** |
| Music → Music, Feed, Video, More | native sheet with a "no actions for this page" placeholder |
| Family detail | native multi-file documentation picker for HAR import |

None of these paths navigate or switch tabs.

### Music page

`MusicRootView` puts a native segmented `Picker` (`Music` / `Archive`) into
`ToolbarItem(placement: .principal)` — the toolbar title area.

Trailing toolbar items are declared in this order:

```swift
ToolbarItemGroup(placement: .topBarTrailing) {
    if router.musicSection == .archive { Button("More") {} }  // left of Account
    Button("Account") {}                                     // always visible, rightmost
}
```

Only the visibility/position of `More` and `Account` is specified, so their actions are
deliberately empty in this build (no unrequested features).

### Archive

`ArchiveView` renders exactly four `List` sections, top to bottom:

1. Badges
2. Family — one row per stored family (name, URL, member count), tapping pushes the
   family detail page
3. Cards
4. Business

Only the Family section holds real data; the other three are placeholders, as the
spec allows.

## Family URL parsing (ported from `services.py`)

The parsing logic was taken from the supplied reference file, not invented:

| Reference | Swift |
| --- | --- |
| `_extract_family_id` | `FamilyURLParser.extractFamilyID(from:)` |
| short-link handling in `fetch_family_from_url` / `_resolve_short_url` | `FamilyService.resolveShortLink(_:)` + `FamilyURLParser.needsShortLinkResolution(_:)` |
| `_fetch_html`, `_extract_ssr_data`, `_parse_family_info_from_ssr` | `FamilyService.fetchHTML(_:)`, `FamilyPageParser` |
| `sign`, `_qq_api_post` | `QQMusicAPI.sign(_:)`, `QQMusicAPI.post(webcgikey:payload:)` |
| `_fetch_members_from_api`, `_parse_member_item` | `QQMusicAPI.fetchMembers(familyID:)`, `QQMusicAPI.parseMember(_:)` |
| `_fetch_family_info_from_api` | `QQMusicAPI.fetchFamilyInfo(familyID:)` |
| `_canonical_member_id` (item id, else `name_<title>`) | same rule in `QQMusicAPI.parseMember(_:)` |

The CORS proxy fallbacks in the Python client are a transport workaround; the native
app calls the same HTTPS endpoints directly.

`＋ → Family` flow:

1. dismisses the option sheet,
2. reads `UIPasteboard.general.string`,
3. detects the first URL with `NSDataDetector`,
4. immediately stores the family from the URL — using `family_id` / `familyId` / `fid`
   or the `family_<id>` / `family/<id>` path rule when present, otherwise the URL host
   as a placeholder name — so it appears in the Family section right away,
5. runs the rest of `fetch_family_from_url` (short link → SSR → member/family APIs) and
   updates the stored family and members in place.

Families are identified by their URL (the reference code's `family_key = url`), so
re-adding the same link updates instead of duplicating. Members are upserted by
`memberID` (`@Attribute(.unique)`), matching requirement 7.

If the network is unavailable, the family entry is still stored from the URL with a
fallback name and an empty member list; the detail page explains that member data is
missing.

## HAR import

`＋` on a family detail page opens `.fileImporter(allowsMultipleSelection: true)`.
The pipeline lives in `HARImportService` and is applied exactly as specified:

1. **Filter** — only requests whose URL contains
   `https://u6.y.qq.com/cgi-bin/musics.fcg?_webcgikey=GetFamilyHonorRecord&_=`.
2. **Extract array text** — the text between the first `[` and the last `]`.
3. **Deduplicate** — every filtered response is compared with the previous **four
   filtered responses** (a sliding window that also includes discarded responses, not a
   fixed baseline). The files are processed as one ordered sequence: file selection
   order first, then HAR entry order inside each file. A response whose array text
   matches any of the four is discarded.
4. **Extract records** — every `{...}` segment in each retained response.
5. **Parse fields**
   * `taskName` — before `@`, trimmed
   * `memberName` — after `@`, trimmed, trailing punctuation removed
   * `time` — raw `Date` value
   * `honorValue` — raw `Value` value (e.g. `+60荣誉值`)
6. **Resolve and write** — the member name must resolve to exactly one existing member
   of the *current family*. Records are stored with exactly:
   `memberID`, `taskName`, `honorValue`, `time`, `familyURL`.
   Unknown or ambiguous names are skipped, collected, and reported in an alert; no
   member is ever created automatically.

Additional details:

* HAR responses with `"encoding": "base64"` are decoded first (port of
  `_decode_response_text`).
* File reading and parsing run in `Task.detached`, so the main thread is never blocked.
* Selected files are read through security-scoped URLs; access is started on the main
  thread, released after parsing.
* The reference code's optional daily-count filter (`>= 400` records per date) is **not**
  applied, because the specified pipeline does not include it.

### Name matching

HAR member names have trailing punctuation removed by step 5, while the stored QQ Music
display name may still contain it (e.g. `姜黎非.`). The resolver therefore:

1. matches case-insensitively on the trimmed name,
2. falls back to a comparison that ignores trailing punctuation on both sides,
3. skips the record with a warning if zero **or** more than one member matches.

## Persistence

Native SwiftData, configured in `FamilyArchiveApp`:

* `Family` — `url` (unique, the family identity), `name`, `familyID`, `avatarURL`,
  `createdAt`
* `FamilyMember` — `memberID` (**unique**), `name`, `avatarURL`, `familyURL`
* `HonorRecord` — exactly the five required fields: `memberID`, `taskName`,
  `honorValue`, `time`, `familyURL`

There are no relationships on `HonorRecord`; records are linked by `memberID` and
`familyURL`, which keeps the stored record shape exactly as required.

## Project layout

```
FamilyArchive.xcodeproj/project.pbxproj
FamilyArchive/
  FamilyArchiveApp.swift          SwiftData container + app scene
  AppRouter.swift                 shared tab / Music section / navigation state
  Models/                         Family, FamilyMember, HonorRecord
  Services/
    FamilyURLParser.swift         URL detection + family id extraction
    FamilyPageParser.swift        HTML SSR extraction
    QQMusicAPI.swift              signature + family/member endpoints
    FamilyService.swift           fetch_family_from_url port
    HARImportService.swift        filter → extract → dedup → parse
    MemberNameResolver.swift      unambiguous member resolution
  Utilities/JSONSupport.swift
  Views/
    RootView.swift                tab bar, detached ＋, sheet, importer, alerts
    PlusActionsSheet.swift        the page-specific option list
    MusicRootView.swift           native segmented control + toolbar items
    ArchiveView.swift             the four required sections
    FamilyDetailView.swift        members + records
    PlaceholderViews.swift        Feed / Video / More / Music placeholders
  Assets.xcassets/                App icon + accent color
```

## Verification performed

* All Swift files parse cleanly with a tree-sitter Swift grammar (0 error nodes).
* `project.pbxproj` is parsed by an OpenStep-plist parser; all 15 object ids are
  defined, all references resolve, and the target/build phases/configurations are
  consistent.
* Asset catalog JSON and the 1024×1024 app icon were validated.
* The HAR pipeline was exercised against synthetic multi-file fixtures (duplicate
  responses, duplicate 5 responses back, base64 responses, full-width trailing
  punctuation, global cross-file window) and matched the expected output.

> The container used to author this project has no Xcode/SwiftUI toolchain, so the
> project has not been compiled against the iOS 27 SDK here. The code targets
> Xcode 27 / iOS 27 and uses only public SwiftUI, SwiftData, CryptoKit, and Foundation
> APIs.

## Deliberately not implemented

* Feed, Video, and More are placeholder pages (their content is free-form per the spec).
* Badges / Cards / Business archive sections and their `＋` options have no data
  behaviour; only the Family option is specified.
* The `More` and `Account` toolbar buttons have no action; only their visibility and
  ordering are specified.
