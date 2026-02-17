import SwiftUI

struct LevelEditorView: View {

    @ObservedObject var editorController: EditorController
    var onSave: () -> Void
    var onTest: () -> Void
    var onPublish: () -> Void
    var onBack: () -> Void

    // Piece categories (matching Kenney Minigolf Kit website sections)
    static let pieceCategories: [(name: String, pieces: [String])] = [
        ("Tracks", ["straight", "end", "start", "open", "side"]),
        ("Corners", ["corner", "round-corner-a", "round-corner-b", "round-corner-c",
                      "skew-corner", "square-corner-a", "inner-corner"]),
        ("Ramps", ["ramp", "ramp-low", "ramp-medium", "ramp-high",
                    "ramp-large", "ramp-large-side", "ramp-sharp", "ramp-side", "ramp-square"]),
        ("Walls", ["wall-left", "wall-right", "walls-to-open", "split",
                    "split-start", "split-t", "split-walls-to-open"]),
        ("Hills", ["hill-round", "hill-square", "hill-corner",
                    "bump", "bump-walls", "bump-down", "bump-down-walls", "crest"]),
        ("Obstacles", ["castle", "windmill", "block", "block-borders",
                        "obstacle-block", "obstacle-diamond", "obstacle-triangle"]),
        ("Tunnels", ["tunnel-narrow", "tunnel-wide", "tunnel-double",
                      "narrow-block", "narrow-round", "narrow-square"]),
        ("Special", ["structure-windmill", "structure-gate", "structure-gate-wide",
                      "structure-gate-building", "structure-gates",
                      "round-large-corner", "round-large-corner-open",
                      "skew-large-corner", "skew-large-corner-open"]),
    ]

    @State private var sidebarOpen = false
    @State private var expandedCategory: Int? = 0
    @State private var showSaveAlert = false
    @State private var showPublishAlert = false
    @State private var courseName = ""

    private let sidebarWidth: CGFloat = 260

    var body: some View {
        ZStack(alignment: .leading) {
            // Main editor overlay (transparent, buttons only)
            VStack {
                editorTopBar
                Spacer()
                editorBottomControls
            }

            // Dim overlay when sidebar open
            if sidebarOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { sidebarOpen = false }
                    }
            }

            // Sidebar
            sidebarView
                .offset(x: sidebarOpen ? 0 : -sidebarWidth - 20)
                .animation(.spring(response: 0.3), value: sidebarOpen)
        }
        .alert("Save Course", isPresented: $showSaveAlert) {
            TextField("Course name", text: $courseName)
            Button("Save") {
                editorController.courseName = courseName
                onSave()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Publish Course", isPresented: $showPublishAlert) {
            TextField("Course name", text: $courseName)
            Button("Publish") {
                editorController.courseName = courseName
                onPublish()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Share this course for others to play?")
        }
    }

    // MARK: - Top Bar

    private var editorTopBar: some View {
        HStack(spacing: 12) {
            // Hamburger menu
            Button {
                withAnimation(.spring(response: 0.3)) {
                    sidebarOpen.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .bodyStyle(size: 22)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // NESW compass button
            Button {
                editorController.cycleCamera()
            } label: {
                Text(editorController.cameraDirectionLabel)
                    .headingStyle(size: 22)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Active tool indicator
            if let tool = editorController.activeTool {
                HStack(spacing: 4) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 10))
                    Text(tool.rawValue.uppercased())
                }
                .lightStyle(size: 11)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(tool.color).opacity(0.25))
                .clipShape(Capsule())
            }

            // Piece count indicator
            if !editorController.pieces.isEmpty {
                Text("\(editorController.pieces.count) pcs")
                    .lightStyle(size: 11)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Controls

    private var editorBottomControls: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Previous object button
            if editorController.lastUsedPieceModel != nil {
                Button {
                    editorController.selectPreviousPiece()
                } label: {
                    Image(systemName: "arrow.backward.square")
                        .bodyStyle(size: 18)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Undo
            Button {
                editorController.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .bodyStyle(size: 18)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!editorController.canUndo)
            .opacity(editorController.canUndo ? 1.0 : 0.4)

            // Redo
            Button {
                editorController.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward.circle")
                    .bodyStyle(size: 18)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!editorController.canRedo)
            .opacity(editorController.canRedo ? 1.0 : 0.4)

            Spacer()

            // Rotation controls (right) - visible when a piece is selected
            if editorController.selectedPieceModel != nil || editorController.selectedPieceIndex != nil {
                HStack(spacing: 8) {
                    Button {
                        editorController.rotateLeft()
                    } label: {
                        Image(systemName: "rotate.left")
                            .bodyStyle(size: 22)
                            .frame(width: 52, height: 52)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        editorController.rotateRight()
                    } label: {
                        Image(systemName: "rotate.right")
                            .bodyStyle(size: 22)
                            .frame(width: 52, height: 52)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button (below dynamic island)
            HStack {
                Text("BUILDER")
                    .headingStyle(size: 20)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { sidebarOpen = false }
                } label: {
                    Image(systemName: "xmark")
                        .bodyStyle(size: 14)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().background(.white.opacity(0.2))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Tool toggle button
                    toolToggleButton
                        .padding(.horizontal, 16)

                    // Par stepper
                    HStack {
                        Text("PAR: \(editorController.par)")
                            .bodyStyle(size: 14)
                        Spacer()
                        Stepper("", value: $editorController.par, in: 1...10)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)

                    // Deselect button
                    if editorController.selectedPieceModel != nil {
                        Button {
                            editorController.deselectPiece()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                Text("DESELECT PIECE")
                            }
                            .lightStyle(size: 11)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 16)
                    }

                    Divider().background(.white.opacity(0.15))

                    // Piece categories (expandable sections)
                    ForEach(0..<Self.pieceCategories.count, id: \.self) { i in
                        categorySection(i)
                    }

                    Divider().background(.white.opacity(0.15))

                    // Action buttons at bottom below pieces
                    VStack(spacing: 8) {
                        sidebarActionButton(icon: "play.fill", title: "TEST", color: .green) {
                            onTest()
                        }
                        sidebarActionButton(icon: "square.and.arrow.down", title: "SAVE", color: .blue) {
                            courseName = editorController.courseName
                            showSaveAlert = true
                        }
                        sidebarActionButton(icon: "square.and.arrow.up", title: "PUBLISH", color: .orange) {
                            courseName = editorController.courseName
                            showPublishAlert = true
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider().background(.white.opacity(0.15))

                    // Back to menu
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("BACK TO MENU")
                        }
                        .bodyStyle(size: 14)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
        }
        .frame(width: sidebarWidth)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Tool Toggle Button

    private var toolToggleButton: some View {
        Button {
            editorController.cycleTool()
        } label: {
            if let tool = editorController.activeTool {
                HStack(spacing: 8) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(tool.rawValue.uppercased())
                }
                .bodyStyle(size: 14)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(tool.color).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(tool.color).opacity(0.5), lineWidth: 1.5)
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 16, weight: .semibold))
                    Text("TOOLS")
                }
                .bodyStyle(size: 14)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedCategory = expandedCategory == index ? nil : index
                }
            } label: {
                HStack {
                    Text(Self.pieceCategories[index].name.uppercased())
                        .bodyStyle(size: 12)
                    Spacer()
                    Image(systemName: expandedCategory == index ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)

            if expandedCategory == index {
                let pieces = Self.pieceCategories[index].pieces
                let columns = [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                ]

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(pieces, id: \.self) { name in
                        pieceCell(name)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Piece Cell (3D thumbnail)

    private func pieceCell(_ name: String) -> some View {
        let isSelected = editorController.selectedPieceModel == name
        return Button {
            editorController.selectPieceToPlace(name)
            withAnimation(.spring(response: 0.3)) { sidebarOpen = false }
        } label: {
            VStack(spacing: 2) {
                Image(uiImage: editorController.thumbnail(for: name))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)

                Text(name)
                    .font(.custom("Futura-Medium", size: 7))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(3)
            .background(isSelected ? Color.green.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.green : Color.clear,
                            lineWidth: isSelected ? 2 : 0)
            )
        }
    }

    // MARK: - Action Button

    private func sidebarActionButton(icon: String, title: String,
                                     color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
            }
            .bodyStyle(size: 13)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
