//
//  NativeSearchBar.swift
//  FamilyArchive
//
//  Thin UIKit bridge so the floating toolbar can host the system search field
//  (UISearchBar) instead of a hand-built TextField. The intrinsic size of the
//  system control drives the layout: no height, glyph size or button size is
//  overridden here.
//

import SwiftUI
import UIKit

struct NativeSearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "搜索"
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.delegate = context.coordinator
        bar.searchBarStyle = .minimal
        bar.placeholder = placeholder
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        bar.spellCheckingType = .no
        bar.returnKeyType = .search
        bar.showsCancelButton = false
        bar.backgroundImage = UIImage()
        bar.searchTextField.backgroundColor = .clear
        bar.searchTextField.borderStyle = .none
        bar.searchTextField.clearButtonMode = .whileEditing
        return bar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UISearchBar,
        context: Context
    ) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        return CGSize(
            width: proposal.width ?? intrinsic.width,
            height: intrinsic.height
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: NativeSearchBar

        init(parent: NativeSearchBar) {
            self.parent = parent
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            parent.onSubmit()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.text = ""
            parent.text = ""
        }
    }
}
