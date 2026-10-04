# Isolated photo-map integration project

SOURCE PREPARATION ONLY: not parsed, compiled, run, published, or adopted.

`PhotoMapIntegration.xcodeproj`, shared scheme `PhotoMapIntegration`, contains only:
- DEBUG iOS 17+ host `IsoMePhotoMapHost`, bundle `tech.isolated.synthetic.IsoMePhotoMapHost`.
- UI target `PhotoMapIntegrationUITests`, bundle `tech.isolated.synthetic.PhotoMapIntegrationUITests`.

The host compiles the real `../../IsoMe` sources/resources through an Xcode 16+ synchronized group, excluding the production `IsoMeApp.swift`, `Info.plist`, and entitlements. Its only explicit entrypoint is `PhotoMapIntegrationHostApp.swift`. The UI target compiles only `PhotoMapIntegrationUITests.swift`. Neither file is registered in the original application/unit-test target. Original targets, PBX, schemes, signing, floors, and package lock remain unchanged.

Package references pin the exact existing ExportKit/ExportAutomationKit and Notelet revisions. The copied lock is byte-preserved; its originHash portability and synchronized-group compile/resource parity have not been qualified. No local dependency resolution or SDK execution occurred.

The unique bundle guard precedes defaults/manager construction. Fixtures retain an in-memory store, disable tracking before construction, and inject photo access/IDs/request/read/observation/thumbnail dependencies. Background location declaration exists solely because the unchanged manager configures that property; it does not prove tracking, permission, or OS-service absence. MapKit may fetch tiles. No production URL scheme, App Group entitlement, extension embedding, or production App startup is registered.

All five native test bodies require hosted compilation and individually named outcomes. Native paging/AX, actor/type/SDK compatibility, scene delivery, real default adapters, security, Photos/GPS/VoiceOver, and physical-device proof remain open. Scheme/source completeness is not acceptance. No local product parser, validator, generator, build, or runtime probe is permitted; next qualification must use separately authorized standard free public GitHub Actions.
