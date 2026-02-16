# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FingerGolf is an iOS SceneKit 3D isometric mini golf game featuring:
- Portrait mode, pure SwiftUI/SceneKit architecture (no UIKit storyboard)
- Slingshot pull-back aiming mechanic
- Level builder/editor with undo/redo
- CloudKit integration for community courses
- 126 Kenney Minigolf Kit 3D models (1.0x1.0 unit grid pieces)

## Build Commands

**CRITICAL**: All `xcodebuild` commands MUST use the `DEVELOPER_DIR` prefix:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild [arguments]
```

### Build for Simulator
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FingerGolf.xcodeproj \
  -scheme FingerGolf \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  build
```

### Run Tests (if added)
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FingerGolf.xcodeproj \
  -scheme FingerGolf \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### Available Simulators
- Preferred: **iPhone 17 Pro** (iOS 26.2)
- Also available: iPhone 16 Pro, iPhone 16, iPhone 16 Plus, iPhone 16e

## Architecture

### Core System Flow

```
ContentView (SwiftUI root)
└── GameCoordinator (central hub - ObservableObject)
    ├── SceneManager (3D scene, camera, lighting)
    ├── CourseManager (loads/builds courses)
    │   └── CourseBuilder (creates SCNNodes from CourseDefinition)
    ├── PhysicsManager (unified physics, collision detection)
    ├── BallController (aiming, shooting, trajectory dots)
    ├── TurnManager (shot counting, max shots tracking)
    ├── ScoringManager (par tracking, scorecard)
    ├── HoleDetector (win condition checking)
    ├── ProgressManager (level completion, progress persistence)
    ├── EditorController (level builder with undo/redo)
    ├── CloudKitManager (community course publishing/downloading)
    └── AudioManager (sound effects)
```

### Key Architectural Principles

1. **GameCoordinator is the Hub**: All game systems are orchestrated through `GameCoordinator`. It owns all child managers and handles state transitions.

2. **No ClubController**: Aiming logic lives directly in `BallController`. The slingshot pull-back mechanic is integrated with ball physics.

3. **Unified Physics**: `PhysicsManager.setupUnifiedCoursePhysics()` creates a single physics body from all course pieces, eliminating seams and gaps between tiles.

4. **State Machine**: `GameState` enum drives UI overlays and gameplay flow:
   - `mainMenu` → `courseSelect` → `playing` → `holeComplete` → `courseComplete`
   - `playing` ↔ `paused`
   - `editing` for level builder
   - `findCourse` for community courses

5. **60fps Game Loop**: Timer-based loop in `GameCoordinator` handles camera follow and ball state checking during gameplay.

## Course/Level System

### CourseDefinition Structure

Courses are defined in Swift code or loaded from JSON:

```swift
CourseDefinition(
    name: "Course Name",
    par: 3,                    // Target strokes
    shotCount: 6,              // Max allowed shots (defaults to par + 3)
    pieces: [
        PiecePlacement(model: "straight", x: 0, z: 0, rotation: 0),
        PiecePlacement(model: "corner", x: 0, z: 1, rotation: 90)
    ],
    ballStart: GridPosition(x: 0, z: 0),
    holePosition: GridPosition(x: 0, z: 3),
    holeModel: "hole-round"    // Optional, defaults to "hole-round"
)
```

- **Grid System**: Integer coordinates, 1.0 unit = 1 tile
- **Rotation**: 0, 90, 180, 270 degrees only
- **Models**: 126 available from Kenney Minigolf Kit (see `AssetCatalog.swift`)
- **Course Loading**: `CourseManager` tries JSON bundle first, falls back to `builtInCourses`

### Adding New Levels

1. Define `CourseDefinition` in `CourseManager.builtInCourses` array
2. Or create/edit `Courses.json` in bundle
3. Test via Level Builder: Editor → Test Course → validate physics

## Physics System

### Critical Physics Details

**ALWAYS use `node.presentation.position` for physics-driven nodes**, not `node.position`:
```swift
// ❌ WRONG - position lags behind physics simulation
let pos = ballNode.position

// ✅ CORRECT - presentation.position is the actual rendered position
let pos = ballNode.presentation.position
```

### Ball Physics
- **Mass**: 0.0459kg (standard golf ball)
- **Radius**: 0.035 units
- **Initial State**: Kinematic (perfectly still at spawn)
- **After Shot**: Switches to dynamic with gravity
- **Spawn Height**: Y=0.09 (safe above mesh surface ~0.02-0.03)
- **Fall Detection**: Y < -1.0 triggers fade-to-black restart
- **Static Detection**: Speed < 0.02, angularSpeed < 0.06

### Course Physics
- **Mesh Collision**: Each piece uses `concavePolyhedron` from actual mesh geometry
- **Unified Body**: Single physics shape for entire course (no seams/gaps)
- **Collision Margin**: 0.001 for tight collision detection
- **Friction**: 0.3 (moderate rolling)
- **Restitution**: 0.4 (bounce)

### Contact Detection
- **Hole Trigger**: Flag contact = instant win
- **Hole Zone**: `HoleDetector.shouldCaptureBall()` checks proximity + velocity
- **Capture Animation**: Ball scales down and fades into hole over 1.0s

## Camera System

### Gameplay Camera
- **Type**: Perspective 3rd person orbit
- **Distance**: 2.5-10 units (default 5)
- **Pitch**: 15-75° (default 30°)
- **Yaw**: Free 360° rotation via touch
- **Follow**: 60fps interpolated follow with factor 0.15
- **Controls**:
  - Touch near ball → aim/shoot
  - Touch elsewhere → orbit camera
  - Pinch gesture → zoom in/out

### Editor Camera
- **Type**: Orthographic top-down
- **Position**: (0, 18, 6)
- **Pitch**: 60° looking down
- **Rotation**: Snaps to N/E/S/W angles via rotate button
- **Orthographic Scale**: 6.0 units

## Aiming & Shooting

### Slingshot Mechanic
- **Drag Direction**: Pull away from ball
- **Shot Direction**: Opposite of drag (slingshot style)
- **Force Calculation**:
  - `maxForce = 5.0`
  - `forceModifier = 2.0`
  - Applied force = `direction * force * forceModifier`
- **Trajectory Preview**: 10 white dots showing shot path
  - Dots at Y=0.06
  - `readsFromDepthBuffer = false` to render on top

### Shot Flow
1. Aim begins → show trajectory dots and aim line
2. Aim moves → update dots based on pull distance
3. Aim ends → apply impulse to ball, switch to dynamic physics
4. Grace period: 10 frames before checking ball velocity
5. Ball stops → check win condition or shot count

## Level Builder

### EditorController
- **Grid**: 20x20 white grid lines (alpha 0.15)
- **Tools**: Ball placement, Hole placement, Eraser
- **Piece Selection**: Scrollable palette with 126 models
- **Ghost Placement**: Transparent preview at cursor position
- **Rotation**: Tap placed piece or use rotate button (90° increments)
- **Undo/Redo**: Full action stack for place/delete/rotate/move
- **Save**: Creates `UserCourse` stored locally via `UserCourseStorage`
- **Test**: Temporarily appends course to `CourseManager` and starts gameplay
- **Publish**: Uploads to CloudKit for community sharing

### Editor Controls
- **Tap Empty Tile**: Place selected piece (or ball/hole if tool active)
- **Tap Placed Piece**: Select and show rotation buttons
- **Tap Selected Piece**: Rotate 90°
- **Eraser Mode**: Tap piece to delete
- **Camera Rotate**: Button cycles N → E → S → W views

## Swift 6 Concurrency

### Actor Isolation
- **Default**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **All types are MainActor by default** unless marked otherwise
- **Delegate Methods**: Use `nonisolated` on `SCNPhysicsContactDelegate` methods:

```swift
nonisolated func physicsWorld(_ world: SCNPhysicsWorld,
                              didBegin contact: SCNPhysicsContact) {
    // Handle contact on physics thread, dispatch to MainActor as needed
}
```

## Project Structure

### File Organization
```
FingerGolf/
├── Core/           GameCoordinator, GameState, GameSettings,
│                   ProgressManager, AudioManager, CloudKitManager
├── Scene/          SceneManager, AssetCatalog, CourseDefinition,
│                   CourseBuilder, CourseManager, PhysicsManager,
│                   PhysicsCategories, UserCourse, UserCourseStorage
├── Gameplay/       BallController, HoleDetector, TurnManager,
│                   ScoringManager, EditorController
├── UI/             ContentView, GameSceneView, GameHUDView,
│                   MainMenuView, LevelSelectView, LevelEditorView,
│                   PauseMenuView, ScoreCardView, FindCourseView,
│                   LeaderboardView, SettingsView, FontStyles,
│                   TrajectoryOverlay
└── Effects/        OceanBackground, RestartFadeEffect,
                    TrajectoryPreview, BarrierRippleEffect
```

### 3D Assets
- **Location**: `Minigolf Kit/Models/` (126 OBJ files)
- **Texture**: `Minigolf Kit/colormap.png` (shared by all pieces)
- **Loading**: `AssetCatalog` caches loaded models via `SCNSceneSource`
- **Naming**: Models use Kenney naming convention (e.g., "straight", "corner", "ramp-large")

## File System Sync

This project uses **PBXFileSystemSynchronizedRootGroup** (Xcode 26.2):
- Files on disk automatically sync to Xcode project
- **No need to manually edit** `.pbxproj` when adding new Swift files
- Simply create files in the correct directory and Xcode will detect them

## Common Pitfalls & Lessons Learned

### Physics Position Bug
```swift
// ❌ BAD - position lags behind physics
let ballPos = ballNode.position

// ✅ GOOD - presentation.position is the real position
let ballPos = ballNode.presentation.position
```

### Node Action Persistence
**CRITICAL**: Always call `removeAllActions()` before reusing ball node:
```swift
ballNode.removeAllActions()  // Prevents capture animations from persisting
ballNode.position = newPosition
```

### Bash Glob with Spaces
```bash
# ❌ BAD - fails with spaces in paths
for f in path/*.obj; do ... done

# ✅ GOOD - quote the path
for f in "path/"*.obj; do ... done
```

### Trajectory Dot Rendering
To render trajectory dots on top of course geometry:
```swift
dotMaterial.readsFromDepthBuffer = false  // Renders on top
dotNode.position = SCNVector3(x, 0.06, z)  // Slightly above surface
```

## Development Workflow

### Testing a Code Change
1. Make changes to Swift files
2. Build for simulator (see Build Commands above)
3. Launch app in simulator or via Xcode
4. Test affected gameplay mechanics

### Adding a New Course
1. Open `CourseManager.swift`
2. Add `CourseDefinition` to `builtInCourses` array
3. Or use Level Builder UI to create visually
4. Test via Editor → Test Course button

### Debugging Physics Issues
1. Check `presentation.position` not `position`
2. Verify unified physics setup in `PhysicsManager`
3. Check collision categories in `PhysicsCategories`
4. Confirm ball spawn height (Y=0.09) and fall detection (Y < -1.0)

### Modifying Aiming Mechanic
- All aiming logic in `BallController`
- Key methods: `aimBegan()`, `aimMoved()`, `aimEnded()`
- Trajectory preview in `TrajectoryPreview.swift`
- Power bar in `GameHUDView` shows `normalizedPower`
