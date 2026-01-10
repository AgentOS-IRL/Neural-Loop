//
//  IconSelectionSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 09/01/2026.
//

import Foundation

//
//  IconSelectionSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 09/01/2026.
//

import SwiftUI

enum SelectIcons {
    typealias Section = (title: String, icons: [String])

    /// Big, practical “exhaustive” set (curated + broad coverage).
    /// Note: some symbols require newer SF Symbols / iOS versions.
    static let sections: [Section] = [

        // MARK: - Work & Career
        ("Work & Career", [
            "briefcase", "briefcase.fill",
            "suitcase", "suitcase.fill",
            "building.2", "building.2.fill",
            "building", "building.fill",
            "building.columns", "building.columns.fill",
            "lanyardcard", "lanyardcard.fill",
            "person.text.rectangle", "person.text.rectangle.fill",
            "person.crop.rectangle", "person.crop.rectangle.fill",
            "person.crop.square", "person.crop.square.fill",
            "signature",
            "rectangle.and.pencil.and.ellipsis",
            "pencil.and.ruler",
            "hammer", "wrench.and.screwdriver",
            "gearshape", "gearshape.fill",
            "calendar", "calendar.badge.clock", "calendar.badge.plus",
            "clock", "clock.fill", "timer",
            "checkmark.seal", "checkmark.seal.fill",
            "doc.text", "doc.text.fill",
            "doc.badge.plus", "doc.badge.gearshape",
            "doc.append", "doc.on.doc",
            "folder", "folder.fill", "folder.badge.plus", "folder.badge.gearshape",
            "tray", "tray.fill", "tray.full", "tray.full.fill",
            "paperplane", "paperplane.fill",
            "envelope", "envelope.fill",
            "link",
            "chart.line.uptrend.xyaxis",
            "chart.line.downtrend.xyaxis",
            "chart.bar", "chart.pie", "chart.bar.xaxis",
            "laptopcomputer", "desktopcomputer", "printer",
            "wifi", "network"
        ]),

        // MARK: - Money & Finance
        ("Money & Finance", [
            "dollarsign.circle", "dollarsign.circle.fill",
            "dollarsign.square", "dollarsign.square.fill",
            "centsign.circle", "centsign.circle.fill",
            "eurosign.circle", "eurosign.circle.fill",
            "sterlingsign.circle", "sterlingsign.circle.fill",
            "yensign.circle", "yensign.circle.fill",
            "creditcard", "creditcard.fill",
            "creditcard.circle", "creditcard.circle.fill",
            "creditcard.trianglebadge.exclamationmark",
            "banknote", "banknote.fill",
            "bitcoinsign", "bitcoinsign.circle.fill",
            "wallet.pass", "wallet.pass.fill",
            "building.columns", "building.columns.fill",
            "chart.line.uptrend.xyaxis",
            "chart.line.downtrend.xyaxis",
            "chart.bar", "chart.pie", "chart.bar.xaxis",
            "percent",
            "tag", "tag.fill", "tag.circle", "tag.circle.fill",
            "cart", "cart.fill", "cart.badge.plus", "cart.badge.minus",
            "bag", "bag.fill", "bag.badge.plus", "bag.badge.minus",
            "gift", "gift.fill",
            "shippingbox", "shippingbox.fill",
            "receipt", "receipt.fill",
            "doc.plaintext", "doc.text.magnifyingglass",
            "plus", "minus", "multiply", "divide", "equal"
        ]),

        // MARK: - Personal Development
        ("Personal Development", [
            "person.fill.checkmark",
            "person.badge.plus",
            "person.badge.shield.checkmark",
            "person.crop.circle", "person.crop.circle.fill",
            "person.crop.circle.badge.plus",
            "person.crop.circle.badge.checkmark",
            "person.crop.circle.badge.clock",
            "person.crop.circle.badge.exclamationmark",
            "brain", "brain.head.profile",
            "lightbulb", "lightbulb.fill",
            "sparkles", "wand.and.stars",
            "target", "scope",
            "chart.line.uptrend.xyaxis", "chart.bar", "chart.pie",
            "checkmark.seal", "checkmark.seal.fill",
            "star", "star.fill", "star.circle", "star.circle.fill",
            "trophy", "trophy.fill",
            "medal",
            "crown", "crown.fill",
            "flag", "flag.fill",
            "bookmark", "bookmark.fill",
            "stopwatch", "timer",
            "bolt", "bolt.fill",
            "flame", "flame.fill",
            "hand.thumbsup", "hand.thumbsup.fill",
            "quote.bubble", "quote.bubble.fill"
        ]),

        // MARK: - Run & Relaxation
        ("Run & Relaxation", [
            "figure.run",
            "figure.walk",
            "figure.mind.and.body",
            "figure.cooldown",
            "leaf", "leaf.fill",
            "wind",
            "drop", "drop.fill",
            "sun.max", "sun.max.fill",
            "moon", "moon.fill",
            "moon.stars", "moon.stars.fill",
            "moon.zzz",
            "zzz",
            "bed.double", "bed.double.fill",
            "music.note", "music.note.list",
            "headphones",
            "waveform",
            "speaker.wave.2", "speaker.wave.2.fill",
            "cup.and.saucer", "cup.and.saucer.fill",
            "theatermasks", "theatermasks.fill",
            "film", "film.fill",
            "tv", "tv.fill",
            "gamecontroller", "gamecontroller.fill",
            "camera", "camera.fill",
            "book", "book.fill",
            "sparkles"
        ]),

        // MARK: - Education & Learning
        ("Education & Learning", [
            "book", "book.fill",
            "book.closed", "book.closed.fill",
            "books.vertical", "books.vertical.fill",
            "graduationcap", "graduationcap.fill",
            "studentdesk",
            "pencil", "pencil.circle", "pencil.circle.fill",
            "pencil.and.outline",
            "highlighter",
            "bookmark", "bookmark.fill",
            "bookmark.circle", "bookmark.circle.fill",
            "brain", "brain.head.profile",
            "doc.text", "doc.text.fill",
            "doc.plaintext",
            "note.text", "note.text.badge.plus",
            "character.book.closed", "character.book.closed.fill",
            "globe", "globe.europe.africa", "globe.americas", "globe.asia.australia",
            "magnifyingglass",
            "mic", "mic.fill",
            "keyboard",
            "puzzlepiece.extension", "puzzlepiece.extension.fill",
            "lightbulb"
        ]),

        // MARK: - Family & Friends
        ("Family & Friends", [
            "person.2", "person.2.fill",
            "person.3", "person.3.fill",
            "person.crop.circle", "person.crop.circle.fill",
            "person.crop.circle.badge.plus",
            "person.crop.circle.badge.checkmark",
            "person.badge.plus",
            "figure.and.child.holdinghands",
            "figure.2.and.child.holdinghands",
            "hands.clap", "hands.clap.fill",
            "hand.raised", "hand.raised.fill",
            "hand.thumbsup", "hand.thumbsup.fill",
            "message", "message.fill",
            "phone", "phone.fill",
            "gift", "gift.fill",
            "balloon", "balloon.fill",
            "party.popper",
            "house", "house.fill",
            "house.circle", "house.circle.fill",
            "heart.text.square", "heart.text.square.fill",
            "bell", "bell.fill"
        ]),

        // MARK: - Love & Relationships
        ("Love & Relationships", [
            "heart", "heart.fill",
            "heart.circle", "heart.circle.fill",
            "heart.square", "heart.square.fill",
            "heart.slash", "heart.slash.fill",
            "heart.text.square", "heart.text.square.fill",
            "message", "message.fill",
            "bubble.left", "bubble.left.fill",
            "bubble.right", "bubble.right.fill",
            "bubble.left.and.bubble.right",
            "bubble.left.and.bubble.right.fill",
            "phone", "phone.fill",
            "video", "video.fill",
            "envelope.open", "envelope.open.fill",
            "person.2", "person.2.fill",
            "person.2.circle", "person.2.circle.fill",
            "lock.heart", "lock.heart.fill",
            "gift", "gift.fill",
            "sparkles"
        ]),

        // MARK: - Spirituality
        ("Spirituality", [
            "sparkles",
            "sun.max", "sun.max.fill",
            "moon.stars", "moon.stars.fill",
            "moon", "moon.fill",
            "cloud.sun", "cloud.sun.fill",
            "cloud.moon", "cloud.moon.fill",
            "eye", "eye.fill",
            "eye.circle", "eye.circle.fill",
            "circle.grid.cross",
            "hands.sparkles",
            "leaf", "leaf.fill",
            "flame", "flame.fill",
            "drop", "drop.fill",
            "wind",
            "star", "star.fill",
            "infinity", "infinity.circle", "infinity.circle.fill",
            "circle.dotted",
            "hexagon", "hexagon.fill",
            "triangle", "triangle.fill",
            "square", "square.fill",
            "circle", "circle.fill"
        ]),

        // MARK: - Sport
        ("Sport", [
            "figure.run",
            "figure.walk",
            "figure.hiking",
            "figure.strengthtraining.traditional",
            "figure.strengthtraining.functional",
            "figure.core.training",
            "figure.cooldown",
            "dumbbell", "dumbbell.fill",
            "bicycle",
            "soccerball",
            "basketball",
            "tennisball",
            "sportscourt", "sportscourt.fill",
            "stopwatch", "stopwatch.fill",
            "timer",
            "heart", "heart.fill",
            "flame", "flame.fill",
            "bolt", "bolt.fill",
            "trophy", "trophy.fill",
            "medal",
            "location", "location.fill",
            "map", "figure.walk.circle"
        ]),

        // MARK: - Health
        ("Health", [
            "heart", "heart.fill",
            "heart.circle", "heart.circle.fill",
            "cross.case", "cross.case.fill",
            "stethoscope",
            "pill", "pill.fill",
            "bandage", "bandage.fill",
            "syringe",
            "facemask",
            "lungs", "lungs.fill",
            "waveform.path.ecg",
            "waveform.path.ecg.rectangle",
            "waveform.path.ecg.rectangle.fill",
            "thermometer",
            "thermometer.sun",
            "thermometer.snowflake",
            "drop", "drop.fill",
            "bed.double", "bed.double.fill",
            "figure.walk", "figure.run",
            "fork.knife",
            "leaf", "leaf.fill",
            "shield", "shield.fill",
            "checkmark.shield", "checkmark.shield.fill"
        ]),

        // MARK: - Extra “Exhaustive” Life Areas (optional but useful)

        ("Travel & Transport", [
            "airplane",
            "airplane.circle", "airplane.circle.fill",
            "tram", "tram.fill",
            "ferry", "ferry.fill",
            "car", "car.fill",
            "bus", "bus.fill",
            "train.side.front.car",
            "bicycle",
            "suitcase", "suitcase.fill",
            "map", "globe",
            "mappin", "mappin.circle", "mappin.circle.fill",
            "mappin.and.ellipse",
            "location", "location.fill",
            "location.north", "location.north.fill",
            "compass.drawing",
            "signpost.right", "signpost.right.fill",
            "binoculars", "binoculars.fill"
        ]),

        ("Home & Life Admin", [
            "house", "house.fill",
            "key", "key.fill",
            "lock", "lock.fill",
            "door.left.hand.open", "door.left.hand.closed",
            "lightbulb", "lightbulb.fill",
            "powerplug", "powerplug.fill",
            "washer", "dryer",
            "dishwasher",
            "bed.double", "bed.double.fill",
            "sofa", "sofa.fill",
            "lamp.desk", "lamp.desk.fill",
            "fanblades", "fanblades.fill",
            "trash", "trash.fill",
            "calendar", "checklist",
            "doc.text", "folder",
            "wrench.and.screwdriver",
            "paintbrush", "paintbrush.fill"
        ]),

        ("Food & Drink", [
            "fork.knife",
            "fork.knife.circle", "fork.knife.circle.fill",
            "cup.and.saucer", "cup.and.saucer.fill",
            "takeoutbag.and.cup.and.straw",
            "takeoutbag.and.cup.and.straw.fill",
            "flame", "flame.fill",
            "leaf", "leaf.fill",
            "cart", "bag",
            "birthday.cake", "birthday.cake.fill",
            "carrot", "carrot.fill",
            "fish", "fish.fill",
            "mug", "mug.fill"
        ]),

        ("Creativity & Hobbies", [
            "paintbrush", "paintbrush.fill",
            "pencil", "pencil.tip", "highlighter",
            "scribble",
            "music.note", "guitars",
            "theatermasks", "film",
            "camera", "camera.fill",
            "video", "video.fill",
            "mic", "mic.fill",
            "scissors",
            "hammer", "wrench.and.screwdriver",
            "sparkles", "wand.and.stars"
        ]),

        ("Tech & Digital Life", [
            "iphone", "ipad",
            "applewatch",
            "airpods", "airpodspro",
            "headphones",
            "laptopcomputer", "desktopcomputer",
            "keyboard", "printer",
            "wifi",
            "antenna.radiowaves.left.and.right",
            "network",
            "cloud", "cloud.fill",
            "externaldrive", "externaldrive.fill",
            "lock.shield", "lock.shield.fill",
            "key", "key.fill",
            "gearshape", "gearshape.fill"
        ])
    ]

    // MARK: - Optional helpers

    /// Removes duplicates within each section while keeping order.
    static var dedupedSections: [Section] {
        sections.map { section in
            var seen = Set<String>()
            let icons = section.icons.filter { seen.insert($0).inserted }
            return (section.title, icons)
        }
    }
}


struct IconSelectionSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSelect: (String) -> Void

    @State private var selectedIcon: String

    init(
        initialIcon: String,
        onSelect: @escaping (String) -> Void
    ) {
        self.onSelect = onSelect
        _selectedIcon = State(initialValue: initialIcon)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(SelectIcons.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.icons, id: \.self) { icon in
                                    iconButton(icon)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSelect(selectedIcon)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func iconButton(_ icon: String) -> some View {
        Button {
            selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(selectedIcon == icon ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
